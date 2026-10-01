-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- M2  Manual scenario: onboard a NEW geo with configuration only (no code change)
-- Story : a new geo "IND" goes live and should use the same features as ULK.
-- Steps : add a column to feature_config + a row to geo_config (+ risk_bucket_config) -> refresh
--         -> verify 8 geos -> remove everything again -> verify 7 geos.
-- Runtime: ~1-2 minutes. Does NOT retrain models. Leaves the dataset exactly as it was.
-- Run as ONE script; the final result grid shows the test outcome.
-- =====================================================================
DECLARE geos_before, geos_after, ind_features, ulk_features, geos_restored, flags_restored INT64;
DECLARE same_as_ulk BOOL;

SET geos_before = (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`);

-- 1. Onboard IND (in production this is 3 rows of config, done by the business owner)
ALTER TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` ADD COLUMN IND INT64;
UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` SET IND = ULK WHERE TRUE;
INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` (GEO) VALUES ('IND');
INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`
  (geo, method, red_top_pct, amber_next_pct, red_threshold, amber_threshold, updated_at)
VALUES ('IND', 'PERCENTILE', 10, 20, 0.70, 0.40, CURRENT_TIMESTAMP());
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

SET geos_after   = (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`);
SET ind_features = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'IND');
SET ulk_features = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');
SET same_as_ulk  = (SELECT LOGICAL_AND(i.feature_list = u.feature_list)
                    FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` i, `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` u
                    WHERE i.geo = 'IND' AND u.geo = 'ULK');
-- (At this point CALL sp_ews_monthly_run(...) would train and score ews_model_ind automatically.)

-- 2. Revert
DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` WHERE geo = 'IND';
DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` WHERE GEO = 'IND';
ALTER TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` DROP COLUMN IND;
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

SET geos_restored  = (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`);
SET flags_restored = (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_flags`);

-- 3. Result
WITH t AS (
  SELECT 'M201' AS test_id, 'Geos with a feature list before onboarding' AS scenario,
         '7' AS expected, CAST(geos_before AS STRING) AS observed
  UNION ALL SELECT 'M202', 'Geos with a feature list after onboarding IND', '8', CAST(geos_after AS STRING)
  UNION ALL SELECT 'M203', 'IND feature count (copied from ULK)', '41', CAST(ind_features AS STRING)
  UNION ALL SELECT 'M204', 'IND feature list identical to ULK', 'true', CAST(same_as_ulk AS STRING)
  UNION ALL SELECT 'M205', 'ULK unaffected', '41', CAST(ulk_features AS STRING)
  UNION ALL SELECT 'M206', 'Geos after revert', '7', CAST(geos_restored AS STRING)
  UNION ALL SELECT 'M207', 'feature_flags rows after revert (100 features x 7 geos)', '700', CAST(flags_restored AS STRING)
)
SELECT test_id, scenario, expected, observed,
       IF(expected = observed, 'PASS', 'FAIL') AS status
FROM t ORDER BY test_id;

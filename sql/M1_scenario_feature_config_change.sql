-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- M1  Manual scenario: business changes feature_config (no code change)
-- Story : HR decides EMP_AGE_YEARS must no longer be used for geo ULK.
-- Steps : switch the flag off -> refresh -> verify -> switch it back on -> refresh -> verify.
-- Runtime: ~1 minute. Does NOT retrain models. Leaves the dataset exactly as it was.
-- Run as ONE script; the final result grid shows the test outcome.
-- =====================================================================
DECLARE ulk_before, ulk_after, ulk_restored, phy_after INT64;
DECLARE age_in_ulk_after, age_in_ulk_restored BOOL;

SET ulk_before = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');

-- 1. Business change: switch EMP_AGE_YEARS off for ULK only
UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` SET ULK = 0 WHERE MODEL_FEATURES = 'EMP_AGE_YEARS';
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

SET ulk_after = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');
SET phy_after = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'PHY');
SET age_in_ulk_after = (SELECT 'EMP_AGE_YEARS' IN UNNEST(SPLIT(feature_list, ', '))
                        FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');

-- 2. Revert
UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` SET ULK = 1 WHERE MODEL_FEATURES = 'EMP_AGE_YEARS';
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

SET ulk_restored = (SELECT n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');
SET age_in_ulk_restored = (SELECT 'EMP_AGE_YEARS' IN UNNEST(SPLIT(feature_list, ', '))
                           FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = 'ULK');

-- 3. Result
WITH t AS (
  SELECT 'M101' AS test_id, 'ULK feature count before the change' AS scenario,
         '41' AS expected, CAST(ulk_before AS STRING) AS observed
  UNION ALL SELECT 'M102', 'ULK feature count after switching EMP_AGE_YEARS off', '40', CAST(ulk_after AS STRING)
  UNION ALL SELECT 'M103', 'EMP_AGE_YEARS in the ULK list after the change', 'false', CAST(age_in_ulk_after AS STRING)
  UNION ALL SELECT 'M104', 'Other geos unaffected (PHY feature count)', '75', CAST(phy_after AS STRING)
  UNION ALL SELECT 'M105', 'ULK feature count after revert', '41', CAST(ulk_restored AS STRING)
  UNION ALL SELECT 'M106', 'EMP_AGE_YEARS back in the ULK list after revert', 'true', CAST(age_in_ulk_restored AS STRING)
)
SELECT test_id, scenario, expected, observed,
       IF(expected = observed, 'PASS', 'FAIL') AS status
FROM t ORDER BY test_id;

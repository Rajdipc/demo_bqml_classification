-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- M4  Manual scenario: configuration error is caught before any model is trained
-- Story : a geo "AAA" is added to geo_config, but nobody flags any feature for it.
-- Expect: sp_ews_monthly_run stops with a clear message instead of training a broken model.
-- Safety: the call uses a FUTURE month (209901), so no existing EWS output is deleted, and
--         "AAA" sorts first, so the procedure fails before training anything. Runtime ~1 minute.
-- Leaves the dataset exactly as it was. Run as ONE script.
-- If the script stops part-way, run section 3 (Revert) on its own.
-- =====================================================================
DECLARE err_msg STRING;
DECLARE geos_restored INT64;

-- 1. Misconfiguration: geo added, feature column added but all flags = 0
ALTER TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` ADD COLUMN AAA INT64;
UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` SET AAA = 0 WHERE TRUE;
INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` (GEO) VALUES ('AAA');

-- 2. Run the monthly job and capture the error
BEGIN
  CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_ews_monthly_run`(209901);
EXCEPTION WHEN ERROR THEN
  SET err_msg = @@error.message;
END;

-- 3. Revert
DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` WHERE GEO = 'AAA';
ALTER TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` DROP COLUMN AAA;
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();
SET geos_restored = (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`);

-- 4. Result
WITH t AS (
  SELECT 'M401' AS test_id, 'Monthly run stopped with a configuration error' AS scenario,
         'contains: No features resolved for geo AAA' AS expected,
         IFNULL(err_msg, '(no error raised)') AS observed,
         IFNULL(STRPOS(err_msg, 'No features resolved for geo AAA') > 0, FALSE) AS ok
  UNION ALL
  SELECT 'M402', 'Nothing written to the EWS tables for the test month 209901', '0',
         CAST((SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` WHERE YEAR_MONTH = 209901)
            + (SELECT COUNT(*) FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` WHERE YEAR_MONTH = 209901) AS STRING), NULL
  UNION ALL
  SELECT 'M403', 'Geos after revert', '7', CAST(geos_restored AS STRING), NULL
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t ORDER BY test_id;

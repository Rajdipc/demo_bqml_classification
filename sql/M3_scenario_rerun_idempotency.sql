-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- M3  Manual scenario: re-run the same month (idempotency)
-- Story : the monthly job is re-triggered for 202609 (e.g. after a data correction).
-- Expect: outputs are REPLACED, never duplicated.
-- WARNING: this retrains the 7 production models -> ~20-35 minutes and BQML training cost.
--          Optional for the demo.
-- Run as ONE script; the final result grid shows the test outcome.
-- =====================================================================
DECLARE start_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_ews_monthly_run`(202609);

WITH
er AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` WHERE YEAR_MONTH = 202609),
vr AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` WHERE YEAR_MONTH = 202609),
gd AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_geo_drivers`   WHERE YEAR_MONTH = 202609),
t AS (
  SELECT 'M301' AS test_id, 'Employee risk rows for 202609 after re-run' AS scenario,
         '1043' AS expected, CAST(COUNT(*) AS STRING) AS observed FROM er
  UNION ALL
  SELECT 'M302', 'Duplicate (geo, EMP_ID) in employee risk', '0',
         CAST(COUNT(*) - COUNT(DISTINCT CONCAT(geo, '|', EMP_ID)) AS STRING) FROM er
  UNION ALL
  SELECT 'M303', 'Duplicate (geo, EMP_ID, feature) in variable risk', '0',
         CAST(COUNT(*) - COUNT(DISTINCT CONCAT(geo, '|', EMP_ID, '|', feature)) AS STRING) FROM vr
  UNION ALL
  SELECT 'M304', 'Duplicate (geo, feature) in geo drivers', '0',
         CAST(COUNT(*) - COUNT(DISTINCT CONCAT(geo, '|', feature)) AS STRING) FROM gd
  UNION ALL
  SELECT 'M305', 'Rows from the previous run still present (scored_at before this script)', '0',
         CAST((SELECT COUNTIF(scored_at < start_ts) FROM er)
            + (SELECT COUNTIF(scored_at < start_ts) FROM vr)
            + (SELECT COUNTIF(scored_at < start_ts) FROM gd) AS STRING)
)
SELECT test_id, scenario, expected, observed,
       IF(expected = observed, 'PASS', 'FAIL') AS status
FROM t ORDER BY test_id;

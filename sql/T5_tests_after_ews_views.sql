-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- T5  Tests after the EWS views (04)  (Checkpoint 5)
-- Run as ONE query. All rows must PASS.
-- =====================================================================
DECLARE m INT64 DEFAULT 202609;

WITH
feed AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_ews_feed` WHERE YEAR_MONTH = m),
er   AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` WHERE YEAR_MONTH = m),
summ AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_ews_summary` WHERE YEAR_MONTH = m),
t AS (
  SELECT 'T501' AS test_id, 'Feed rows = RED + AMBER employees in ews_employee_risk' AS scenario,
         CAST((SELECT COUNTIF(risk_bucket IN ('RED', 'AMBER')) FROM er) AS STRING) AS expected,
         CAST(COUNT(*) AS STRING) AS observed, CAST(NULL AS BOOL) AS ok
  FROM feed

  UNION ALL
  SELECT 'T502', 'Feed rows with a bucket other than RED / AMBER', '0',
         CAST(COUNTIF(risk_bucket NOT IN ('RED', 'AMBER')) AS STRING), NULL
  FROM feed

  UNION ALL
  SELECT 'T503', 'Feed rows with 0 or more than 5 variable risks, or an empty first feature', '0',
         CAST(COUNTIF(ARRAY_LENGTH(top_variable_risks) = 0
                      OR ARRAY_LENGTH(top_variable_risks) > 5
                      OR top_variable_risks[SAFE_OFFSET(0)].feature IS NULL) AS STRING), NULL
  FROM feed

  UNION ALL
  SELECT 'T504', 'First variable risk is driver_rank 1', '0 violations',
         FORMAT('%d violations', COUNTIF(top_variable_risks[SAFE_OFFSET(0)].driver_rank != 1)), NULL
  FROM feed

  UNION ALL
  SELECT 'T505', 'Summary: employees scored in 202609 (7 x 149)', '1043',
         CAST(SUM(employees_scored) AS STRING), NULL
  FROM summ

  UNION ALL
  SELECT 'T506', 'Summary: RED + AMBER equals feed rows',
         CAST((SELECT COUNT(*) FROM feed) AS STRING),
         CAST(SUM(red + amber) AS STRING), NULL
  FROM summ

  UNION ALL
  SELECT 'T507', 'Summary: red + amber + green = employees_scored for every geo', '7',
         CAST(COUNTIF(red + amber + green = employees_scored) AS STRING), NULL
  FROM summ
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN STARTS_WITH(expected, 'INFO') THEN 'INFO'
            WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t
ORDER BY test_id;

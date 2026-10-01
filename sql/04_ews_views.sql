-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 04  EWS SYSTEM - views consumed by the manager dashboard / EWS application
-- Run as ONE script. Creates 2 views and shows the top 20 employees to act on.
-- =====================================================================

-- 04a. EWS feed: one row per RED / AMBER employee with the top 5 recommended variable risks
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.demo_bqml_classification.v_ews_feed` AS
SELECT
  e.geo, e.EMP_ID, e.YEAR_MONTH,
  ROUND(e.risk_score, 4) AS risk_score,
  e.risk_bucket, e.risk_rank_in_geo,
  ARRAY_AGG(
    STRUCT(v.driver_rank, v.feature, v.feature_value, ROUND(v.risk_contribution, 4) AS risk_contribution)
    IGNORE NULLS ORDER BY v.driver_rank LIMIT 5) AS top_variable_risks,
  e.model_name, e.scored_at
FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` e
LEFT JOIN `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` v
  ON  v.geo = e.geo AND v.EMP_ID = e.EMP_ID AND v.YEAR_MONTH = e.YEAR_MONTH
WHERE e.risk_bucket IN ('RED', 'AMBER')
GROUP BY e.geo, e.EMP_ID, e.YEAR_MONTH, e.risk_score, e.risk_bucket, e.risk_rank_in_geo,
         e.model_name, e.scored_at;

-- 04b. Management summary per geo and month
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.demo_bqml_classification.v_ews_summary` AS
SELECT
  geo, YEAR_MONTH,
  COUNT(*)                          AS employees_scored,
  COUNTIF(risk_bucket = 'RED')      AS red,
  COUNTIF(risk_bucket = 'AMBER')    AS amber,
  COUNTIF(risk_bucket = 'GREEN')    AS green,
  ROUND(AVG(risk_score), 4)         AS avg_risk_score
FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk`
GROUP BY geo, YEAR_MONTH;

-- 04c. What a manager sees: top 20 employees to act on this month
SELECT
  geo, EMP_ID, risk_score, risk_bucket, risk_rank_in_geo,
  (SELECT STRING_AGG(FORMAT('%d. %s = %s (+%.3f)', r.driver_rank, r.feature,
                            IFNULL(r.feature_value, 'NULL'), r.risk_contribution), '  |  '
                     ORDER BY r.driver_rank)
   FROM UNNEST(top_variable_risks) r) AS recommended_variable_risks
FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_ews_feed`
WHERE YEAR_MONTH = 202609
ORDER BY risk_score DESC
LIMIT 20;

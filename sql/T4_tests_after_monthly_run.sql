-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- T4  Tests after the monthly EWS run (03b)  (Checkpoint 4)
-- Run as ONE query. PASS/FAIL rows must pass; INFO rows are for review.
-- Sample facts: 202609 has 149 employees; the sample has no GEO column, so every geo model
-- scores the same 149 employees -> 7 x 149 = 1043 rows.
-- =====================================================================
DECLARE m INT64 DEFAULT 202609;

WITH
er AS (SELECT r.*, c.red_threshold, c.amber_threshold
       FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` r
       JOIN `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` c ON c.geo = r.geo
       WHERE r.YEAR_MONTH = m),
vr AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` WHERE YEAR_MONTH = m),
gd AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_geo_drivers`   WHERE YEAR_MONTH = m),
gfl AS (SELECT geo, n_features, f AS feature
        FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`, UNNEST(SPLIT(feature_list, ', ')) f),
fi AS (
  SELECT 'ews_model_ulk' AS model_name, input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_ulk`)
  UNION ALL SELECT 'ews_model_phy', input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_phy`)
),
act AS (  -- actual outcome of 202609 (available in the sample, so we can check the ranking)
  SELECT EMP_ID, ANY_VALUE(target) AS target
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_store` WHERE YEAR_MONTH = m GROUP BY EMP_ID
),
t AS (
  SELECT 'T401' AS test_id, 'Employee risk rows for 202609 (7 geos x 149)' AS scenario,
         '1043' AS expected, CAST(COUNT(*) AS STRING) AS observed, CAST(NULL AS BOOL) AS ok
  FROM er

  UNION ALL
  SELECT 'T402', 'Rows per geo (all geos = 149)', '7 geos x 149',
         FORMAT('%d geos, min %d, max %d', COUNT(*), MIN(n), MAX(n)),
         COUNT(*) = 7 AND MIN(n) = 149 AND MAX(n) = 149
  FROM (SELECT geo, COUNT(*) AS n FROM er GROUP BY geo)

  UNION ALL
  SELECT 'T403', 'Risk scores NULL or outside [0, 1]', '0',
         CAST(COUNTIF(risk_score IS NULL OR risk_score < 0 OR risk_score > 1) AS STRING), NULL
  FROM er

  UNION ALL
  SELECT 'T404', 'Bucket does not match the geo thresholds', '0',
         CAST(COUNTIF(risk_bucket != CASE WHEN risk_score >= red_threshold   THEN 'RED'
                                          WHEN risk_score >= amber_threshold THEN 'AMBER'
                                          ELSE 'GREEN' END) AS STRING), NULL
  FROM er

  UNION ALL
  SELECT 'T405', 'RED share of scored employees (target ~10%)', '3% - 20%',
         FORMAT('%.1f%%', 100 * AVG(IF(risk_bucket = 'RED', 1, 0))),
         AVG(IF(risk_bucket = 'RED', 1, 0)) BETWEEN 0.03 AND 0.20
  FROM er

  UNION ALL
  SELECT 'T406', 'AMBER share of scored employees (target ~20%)', '10% - 35%',
         FORMAT('%.1f%%', 100 * AVG(IF(risk_bucket = 'AMBER', 1, 0))),
         AVG(IF(risk_bucket = 'AMBER', 1, 0)) BETWEEN 0.10 AND 0.35
  FROM er

  UNION ALL
  SELECT 'T407', 'Variable risks with contribution <= 0 (only risk-increasing drivers kept)', '0',
         CAST(COUNTIF(risk_contribution <= 0) AS STRING), NULL
  FROM vr

  UNION ALL
  SELECT 'T408', "Variable risks on a feature NOT in that geo's feature list", '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM vr LEFT JOIN gfl ON gfl.geo = vr.geo AND gfl.feature = vr.feature
  WHERE gfl.feature IS NULL

  UNION ALL
  SELECT 'T409', 'Variable risks with a NULL feature_value (202609 has no blanks)', '0',
         CAST(COUNTIF(feature_value IS NULL) AS STRING), NULL
  FROM vr

  UNION ALL
  SELECT 'T410', 'Driver rank range (top_k_features = 10)', 'min 1, max <= 10',
         FORMAT('min %d, max %d', MIN(driver_rank), MAX(driver_rank)),
         MIN(driver_rank) = 1 AND MAX(driver_rank) <= 10
  FROM vr

  UNION ALL
  SELECT 'T411', 'ULK (Profile A) variable risks on telemetry TOTAL_* features', '0',
         CAST(COUNTIF(geo = 'ULK' AND STARTS_WITH(feature, 'TOTAL_')) AS STRING), NULL
  FROM vr

  UNION ALL
  SELECT 'T412', 'Production model inputs follow feature_config', 'ews_model_phy=75, ews_model_ulk=41',
         STRING_AGG(FORMAT('%s=%d', model_name, n), ', ' ORDER BY model_name), NULL
  FROM (SELECT model_name, COUNT(*) AS n FROM fi GROUP BY model_name)

  UNION ALL
  SELECT 'T413', 'Geos with global drivers written (0 < drivers <= feature count)', '7',
         CAST(COUNTIF(d.n > 0 AND d.n <= l.n_features) AS STRING), NULL
  FROM (SELECT geo, COUNT(*) AS n FROM gd GROUP BY geo) d
  JOIN `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` l USING (geo)

  UNION ALL
  SELECT 'T414', 'Geos with thresholds recalibrated by the run (0 < amber < red < 1, updated_at set)', '7',
         CAST(COUNTIF(amber_threshold > 0 AND amber_threshold < red_threshold AND red_threshold < 1
                      AND updated_at IS NOT NULL) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`

  UNION ALL
  SELECT 'T415', 'RED employees without any top risk driver', '0',
         CAST(COUNTIF(risk_bucket = 'RED' AND top_risk_drivers IS NULL) AS STRING), NULL
  FROM er

  UNION ALL
  SELECT 'T416', 'Actual leaver rate in 202609: RED | AMBER | GREEN (base rate 50/149 = 0.336)',
         'INFO: RED > GREEN indicates useful ranking (weak synthetic signal)',
         FORMAT('%.3f | %.3f | %.3f',
                AVG(IF(er.risk_bucket = 'RED',   act.target, NULL)),
                AVG(IF(er.risk_bucket = 'AMBER', act.target, NULL)),
                AVG(IF(er.risk_bucket = 'GREEN', act.target, NULL))), NULL
  FROM er JOIN act ON act.EMP_ID = er.EMP_ID

  UNION ALL
  SELECT 'T417', 'Temporary stage table removed at the end of the run', '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'ews_scored_stage'
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN STARTS_WITH(expected, 'INFO') THEN 'INFO'
            WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t
ORDER BY test_id;

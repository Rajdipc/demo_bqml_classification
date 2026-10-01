-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- T3  Tests after backtest (02a-02d)  (Checkpoint 3)
-- Run as ONE query. PASS/FAIL rows must pass; INFO rows are for review.
-- Note: the sample data is synthetic with very weak signal (max |correlation| with target ~0.05),
--       so AUC close to 0.5 is EXPECTED. These tests validate the pipeline, not business accuracy.
-- =====================================================================
WITH
ev AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.bt_eval_results`),
tp AS (SELECT p.*, c.red_threshold, c.amber_threshold
       FROM `YOUR_PROJECT_ID.demo_bqml_classification.bt_test_predictions` p JOIN `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` c USING (geo)),
fi AS (
  SELECT 'btree_ulk' AS m, input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_ulk`)
  UNION ALL SELECT 'btree_phy', input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_phy`)
  UNION ALL SELECT 'logreg_ulk', input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_logreg_ulk`)
  UNION ALL SELECT 'logreg_phy', input FROM ML.FEATURE_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_logreg_phy`)
),
t AS (
  SELECT 'T301' AS test_id, 'Models evaluated (7 geos x 2 families)' AS scenario,
         '14' AS expected, CAST(COUNT(*) AS STRING) AS observed, CAST(NULL AS BOOL) AS ok
  FROM ev

  UNION ALL
  SELECT 'T302', 'Models with a valid ROC AUC (0 < AUC < 1)', '14',
         CAST(COUNTIF(roc_auc > 0 AND roc_auc < 1) AS STRING), NULL
  FROM ev

  UNION ALL
  SELECT 'T303', 'Average TEST ROC AUC: Boosted Tree | Logistic Regression',
         'INFO: ~0.45-0.60 expected on this synthetic sample',
         FORMAT('%.3f | %.3f', AVG(IF(model_family = 'btree', roc_auc, NULL)),
                               AVG(IF(model_family = 'logreg', roc_auc, NULL))), NULL
  FROM ev

  UNION ALL
  SELECT 'T304', 'Model input features driven by feature_config',
         'btree_phy=75, btree_ulk=41, logreg_phy=75, logreg_ulk=41',
         STRING_AGG(FORMAT('%s=%d', m, n), ', ' ORDER BY m), NULL
  FROM (SELECT m, COUNT(*) AS n FROM fi GROUP BY m)

  UNION ALL
  SELECT 'T305', 'Guardrail: excluded columns used as model inputs', '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM fi JOIN `YOUR_PROJECT_ID.demo_bqml_classification.feature_exclusions` x ON x.feature = fi.input

  UNION ALL
  SELECT 'T306', 'Telemetry (TOTAL_*) inputs: ULK (Profile A) | PHY (Profile B)', '0 | 34',
         FORMAT('%d | %d', COUNTIF(m = 'btree_ulk' AND STARTS_WITH(input, 'TOTAL_')),
                           COUNTIF(m = 'btree_phy' AND STARTS_WITH(input, 'TOTAL_'))), NULL
  FROM fi

  UNION ALL
  SELECT 'T307', 'TEST predictions written (7 geos x 602 rows)', '4214',
         CAST(COUNT(*) AS STRING), NULL
  FROM tp

  UNION ALL
  SELECT 'T308', 'Risk scores outside [0, 1] or NULL', '0',
         CAST(COUNTIF(risk_score IS NULL OR risk_score < 0 OR risk_score > 1) AS STRING), NULL
  FROM tp

  UNION ALL
  SELECT 'T309', 'Scores are not constant (std dev > 0.001)', '> 0.001',
         FORMAT('%.4f', STDDEV(risk_score)), STDDEV(risk_score) > 0.001
  FROM tp

  UNION ALL
  SELECT 'T310', 'Geos with valid thresholds (0 < amber < red < 1)', '7',
         CAST(COUNTIF(amber_threshold > 0 AND amber_threshold < red_threshold AND red_threshold < 1) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`

  UNION ALL
  SELECT 'T311', 'RED share of TEST employees (target ~10%)', '3% - 20%',
         FORMAT('%.1f%%', 100 * AVG(IF(risk_score >= red_threshold, 1, 0))),
         AVG(IF(risk_score >= red_threshold, 1, 0)) BETWEEN 0.03 AND 0.20
  FROM tp

  UNION ALL
  SELECT 'T312', 'AMBER share of TEST employees (target ~20%)', '10% - 35%',
         FORMAT('%.1f%%', 100 * AVG(IF(risk_score >= amber_threshold AND risk_score < red_threshold, 1, 0))),
         AVG(IF(risk_score >= amber_threshold AND risk_score < red_threshold, 1, 0)) BETWEEN 0.10 AND 0.35
  FROM tp

  UNION ALL
  SELECT 'T313', 'Hit rate: RED | AMBER | GREEN vs base rate 0.322',
         'INFO: RED > GREEN indicates useful ranking',
         FORMAT('%.3f | %.3f | %.3f',
                AVG(IF(risk_score >= red_threshold, target, NULL)),
                AVG(IF(risk_score >= amber_threshold AND risk_score < red_threshold, target, NULL)),
                AVG(IF(risk_score < amber_threshold, target, NULL))), NULL
  FROM tp

  UNION ALL
  SELECT 'T314', 'Boosted Tree training iterations (early stopping, max 100) - PHY', '1 - 100',
         CAST(COUNT(DISTINCT iteration) AS STRING), COUNT(DISTINCT iteration) BETWEEN 1 AND 100
  FROM ML.TRAINING_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_phy`)
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN STARTS_WITH(expected, 'INFO') THEN 'INFO'
            WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t
ORDER BY test_id;

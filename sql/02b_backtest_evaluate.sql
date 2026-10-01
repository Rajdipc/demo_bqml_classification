-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 02b  Backtest - evaluate all 14 models on the unseen TEST months (after 2026-05)
-- Run as ONE script.
-- =====================================================================
DECLARE eval_end INT64 DEFAULT 202605;

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.bt_eval_results` (
  geo STRING, model_family STRING, precision FLOAT64, recall FLOAT64,
  accuracy FLOAT64, f1_score FLOAT64, log_loss FLOAT64, roc_auc FLOAT64
);

FOR g IN (SELECT GEO FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` ORDER BY GEO)
DO
  FOR m IN (SELECT fam FROM UNNEST(['btree', 'logreg']) AS fam)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.bt_eval_results`
      SELECT '%s', '%s', precision, recall, accuracy, f1_score, log_loss, roc_auc
      FROM ML.EVALUATE(
        MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_%s_%s`,
        (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
         WHERE target IS NOT NULL AND YEAR_MONTH > %d AND (GEO = '%s' OR GEO IS NULL)))
    """, g.GEO, m.fam, m.fam, LOWER(g.GEO), eval_end, g.GEO);
  END FOR;
END FOR;

-- Boosted Tree vs Logistic Regression per geo
SELECT geo, model_family,
       ROUND(roc_auc, 3) AS roc_auc, ROUND(recall, 3) AS recall,
       ROUND(precision, 3) AS precision, ROUND(f1_score, 3) AS f1, ROUND(log_loss, 3) AS log_loss
FROM `YOUR_PROJECT_ID.demo_bqml_classification.bt_eval_results`
ORDER BY geo, roc_auc DESC;

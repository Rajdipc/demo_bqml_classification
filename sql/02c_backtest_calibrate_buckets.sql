-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 02c  Backtest - calibrate Red / Amber thresholds per geo (on the EVAL months)
-- method = 'PERCENTILE' (default): RED = top 10% of scores, AMBER = next 20%.
-- Geos set to method = 'FIXED' are left unchanged.
-- Run as ONE script.
-- =====================================================================
DECLARE train_end INT64 DEFAULT 202512;
DECLARE eval_end  INT64 DEFAULT 202605;
DECLARE red_thr   FLOAT64;
DECLARE amber_thr FLOAT64;

FOR g IN (SELECT geo, red_top_pct, amber_next_pct
          FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`
          WHERE method = 'PERCENTILE' ORDER BY geo)
DO
  EXECUTE IMMEDIATE FORMAT("""
    SELECT q[OFFSET(%d)], q[OFFSET(%d)]
    FROM (
      SELECT APPROX_QUANTILES(p, 100) AS q
      FROM (
        SELECT (SELECT prob FROM UNNEST(predicted_target_probs) WHERE label = 1) AS p
        FROM ML.PREDICT(
          MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_%s`,
          (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
           WHERE target IS NOT NULL AND YEAR_MONTH > %d AND YEAR_MONTH <= %d
             AND (GEO = '%s' OR GEO IS NULL)))))
  """, 100 - g.red_top_pct, 100 - g.red_top_pct - g.amber_next_pct,
       LOWER(g.geo), train_end, eval_end, g.geo)
  INTO red_thr, amber_thr;

  UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`
  SET red_threshold = red_thr, amber_threshold = amber_thr, updated_at = CURRENT_TIMESTAMP()
  WHERE geo = g.geo;
END FOR;

SELECT geo, method, red_top_pct, amber_next_pct,
       ROUND(red_threshold, 4) AS red_threshold, ROUND(amber_threshold, 4) AS amber_threshold, updated_at
FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`
ORDER BY geo;

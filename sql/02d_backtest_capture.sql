-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 02d  Backtest - business view: how well do Red / Amber capture real events (TEST months)?
-- Run as ONE script.
-- =====================================================================
DECLARE eval_end INT64 DEFAULT 202605;

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.bt_test_predictions` (
  geo STRING, EMP_ID STRING, YEAR_MONTH INT64, target INT64, risk_score FLOAT64
);

FOR g IN (SELECT GEO FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` ORDER BY GEO)
DO
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.bt_test_predictions`
    SELECT '%s', EMP_ID, YEAR_MONTH, target,
           (SELECT prob FROM UNNEST(predicted_target_probs) WHERE label = 1)
    FROM ML.PREDICT(
      MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_%s`,
      (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
       WHERE target IS NOT NULL AND YEAR_MONTH > %d AND (GEO = '%s' OR GEO IS NULL)))
  """, g.GEO, LOWER(g.GEO), eval_end, g.GEO);
END FOR;

SELECT geo,
       CASE WHEN risk_score >= red_threshold   THEN '1-RED'
            WHEN risk_score >= amber_threshold THEN '2-AMBER'
            ELSE '3-GREEN' END                                              AS bucket,
       COUNT(*)                                                             AS employees,
       SUM(target)                                                          AS actual_events,
       ROUND(AVG(target), 3)                                                AS hit_rate,
       ROUND(SUM(target) / SUM(SUM(target)) OVER (PARTITION BY geo), 3)     AS share_of_all_events
FROM `YOUR_PROJECT_ID.demo_bqml_classification.bt_test_predictions`
JOIN `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` USING (geo)
GROUP BY geo, bucket
ORDER BY geo, bucket;

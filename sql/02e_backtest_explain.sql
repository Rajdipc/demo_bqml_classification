-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 02e  Backtest - explainability (read-only queries)
-- Run as ONE script; each SELECT appears as a separate result in the results pane.
-- =====================================================================

-- Top global risk drivers for a Profile B geo (HR + telemetry)
SELECT 'PHY' AS geo, feature, ROUND(attribution, 4) AS attribution
FROM ML.GLOBAL_EXPLAIN(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_phy`)
ORDER BY attribution DESC LIMIT 15;

-- Top global risk drivers for a Profile A geo (HR only)
SELECT 'ULK' AS geo, feature, ROUND(attribution, 4) AS attribution
FROM ML.GLOBAL_EXPLAIN(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_ulk`)
ORDER BY attribution DESC LIMIT 15;

-- Direction of effect (+ raises risk, - lowers risk) from the benchmark model
SELECT processed_input AS feature, ROUND(weight, 4) AS weight
FROM ML.WEIGHTS(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_logreg_phy`, STRUCT(TRUE AS standardize))
WHERE processed_input != '__INTERCEPT__'
ORDER BY ABS(weight) DESC LIMIT 15;

-- Training curve: training vs validation loss per iteration (over-fitting / early-stop check)
SELECT iteration, ROUND(loss, 4) AS train_loss, ROUND(eval_loss, 4) AS eval_loss, duration_ms
FROM ML.TRAINING_INFO(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_phy`)
ORDER BY iteration;

-- Threshold trade-off on the TEST months (for discussion with the business)
SELECT ROUND(threshold, 3) AS threshold, ROUND(recall, 3) AS recall,
       ROUND(SAFE_DIVIDE(true_positives, true_positives + false_positives), 3) AS precision,
       ROUND(false_positive_rate, 3) AS false_positive_rate
FROM ML.ROC_CURVE(
  MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_phy`,
  (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features` WHERE target IS NOT NULL AND YEAR_MONTH > 202605))
ORDER BY threshold DESC;

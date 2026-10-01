-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 02a  Backtest - train 14 models (7 geos x Boosted Tree + Logistic Regression)
-- Run as ONE script. Longest step: ~30-60 minutes (models train one after another).
-- Watch progress in the results pane / Job history (one child job per statement).
-- =====================================================================
DECLARE train_end INT64 DEFAULT 202512;   -- TRAIN: up to 2025-12
DECLARE eval_end  INT64 DEFAULT 202605;   -- EVAL : 2026-01 .. 2026-05  |  TEST: after 2026-05 (never used here)
DECLARE features  STRING;

FOR g IN (SELECT GEO FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` ORDER BY GEO)
DO
  SET features = (SELECT feature_list FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = g.GEO);

  -- Primary model: Boosted Tree (XGBoost)
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_btree_%s`
    OPTIONS (
      model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['target'],
      data_split_method = 'CUSTOM', data_split_col = 'is_eval',
      auto_class_weights = TRUE, max_iterations = 100, early_stop = TRUE,
      min_rel_progress = 0.005, learn_rate = 0.1, max_tree_depth = 6,
      subsample = 0.8, colsample_bytree = 0.8, l2_reg = 1.0,
      enable_global_explain = TRUE
    ) AS
    SELECT target, %s, YEAR_MONTH > %d AS is_eval
    FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
    WHERE target IS NOT NULL AND YEAR_MONTH <= %d AND (GEO = '%s' OR GEO IS NULL)
  """, LOWER(g.GEO), features, train_end, eval_end, g.GEO);

  -- Benchmark model: Logistic Regression
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE MODEL `YOUR_PROJECT_ID.demo_bqml_classification.bt_logreg_%s`
    OPTIONS (
      model_type = 'LOGISTIC_REG', input_label_cols = ['target'],
      data_split_method = 'CUSTOM', data_split_col = 'is_eval',
      auto_class_weights = TRUE, l2_reg = 0.1, max_iterations = 30,
      enable_global_explain = TRUE
    ) AS
    SELECT target, %s, YEAR_MONTH > %d AS is_eval
    FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
    WHERE target IS NOT NULL AND YEAR_MONTH <= %d AND (GEO = '%s' OR GEO IS NULL)
  """, LOWER(g.GEO), features, train_end, eval_end, g.GEO);
END FOR;

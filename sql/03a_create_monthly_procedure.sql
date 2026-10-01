-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 03a  Monthly EWS run as ONE stored procedure (production equivalent of the Python sandbox)
--   GEO SELECTION     -> loop over geo_config until all geos are exhausted
--   FEATURE SELECTION -> v_geo_feature_list (from feature_config)
--   MODEL OBJECT      -> train on history incl. last month, calibrate Red/Amber, score current month,
--                        individual risk + bucket + risk at variable level
--   EWS SYSTEM        -> ews_employee_risk / ews_variable_risk / ews_geo_drivers (-> views in 04)
-- Run this file once to CREATE the procedure (takes seconds). Execution happens in 03b.
-- =====================================================================
CREATE OR REPLACE PROCEDURE `YOUR_PROJECT_ID.demo_bqml_classification.sp_ews_monthly_run`(scoring_month INT64)
BEGIN
  DECLARE features  STRING;
  DECLARE red_thr   FLOAT64;
  DECLARE amber_thr FLOAT64;
  -- The last 3 months of history are the validation window (early stopping + Red/Amber calibration)
  DECLARE eval_from INT64 DEFAULT CAST(FORMAT_DATE('%Y%m',
            DATE_SUB(PARSE_DATE('%Y%m', CAST(scoring_month AS STRING)), INTERVAL 3 MONTH)) AS INT64);

  -- Pick up any feature_config / geo_config changes
  CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

  -- Safe to re-run for the same month
  DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` WHERE YEAR_MONTH = scoring_month;
  DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` WHERE YEAR_MONTH = scoring_month;
  DELETE FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_geo_drivers`   WHERE YEAR_MONTH = scoring_month;

  -- ===== GEO SELECTION: one geo at a time until all geos are exhausted =====
  FOR g IN (SELECT GEO FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` ORDER BY GEO)
  DO
    -- ===== FEATURE SELECTION =====
    SET features = (SELECT feature_list FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` WHERE geo = g.GEO);
    IF features IS NULL THEN
      RAISE USING MESSAGE = FORMAT('No features resolved for geo %s - check feature_config', g.GEO);
    END IF;

    -- ===== MODEL OBJECT (a): train on history up to and including last month =====
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_%s`
      OPTIONS (
        model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['target'],
        data_split_method = 'CUSTOM', data_split_col = 'is_eval',
        auto_class_weights = TRUE, max_iterations = 100, early_stop = TRUE,
        min_rel_progress = 0.005, learn_rate = 0.1, max_tree_depth = 6,
        subsample = 0.8, colsample_bytree = 0.8, l2_reg = 1.0,
        enable_global_explain = TRUE
      ) AS
      SELECT target, %s, YEAR_MONTH >= %d AS is_eval
      FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
      WHERE target IS NOT NULL AND YEAR_MONTH < %d AND (GEO = '%s' OR GEO IS NULL)
    """, LOWER(g.GEO), features, eval_from, scoring_month, g.GEO);

    -- ===== MODEL OBJECT (b): Red / Amber thresholds (PERCENTILE geos) from this model's validation scores =====
    IF (SELECT method FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` WHERE geo = g.GEO) = 'PERCENTILE' THEN
      EXECUTE IMMEDIATE FORMAT("""
        SELECT q[OFFSET(100 - c.red_top_pct)], q[OFFSET(100 - c.red_top_pct - c.amber_next_pct)]
        FROM (
          SELECT APPROX_QUANTILES(p, 100) AS q
          FROM (
            SELECT (SELECT prob FROM UNNEST(predicted_target_probs) WHERE label = 1) AS p
            FROM ML.PREDICT(
              MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_%s`,
              (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
               WHERE target IS NOT NULL AND YEAR_MONTH >= %d AND YEAR_MONTH < %d
                 AND (GEO = '%s' OR GEO IS NULL))))),
             `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` c
        WHERE c.geo = '%s'
      """, LOWER(g.GEO), eval_from, scoring_month, g.GEO, g.GEO)
      INTO red_thr, amber_thr;

      UPDATE `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`
      SET red_threshold = red_thr, amber_threshold = amber_thr, updated_at = CURRENT_TIMESTAMP()
      WHERE geo = g.GEO;
    END IF;

    -- ===== MODEL OBJECT (c): score the current month with per-variable attributions =====
    -- All input columns pass through, so the stage row also carries each feature's actual value.
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.ews_scored_stage` AS
      SELECT '%s' AS model_geo,
             CAST(predicted_target AS STRING) = '1' AS is_positive,
             IF(CAST(predicted_target AS STRING) = '1', probability, 1 - probability) AS risk_score,
             *
      FROM ML.EXPLAIN_PREDICT(
        MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_%s`,
        (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`
         WHERE YEAR_MONTH = %d AND (GEO = '%s' OR GEO IS NULL)),
        STRUCT(10 AS top_k_features))
    """, g.GEO, LOWER(g.GEO), scoring_month, g.GEO);

    -- ===== Individual employee risk + Red / Amber bucket =====
    -- Attributions are returned for the PREDICTED class; the sign is flipped when the prediction is 0
    -- so that every contribution is expressed as "towards risk".
    INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk`
      (geo, EMP_ID, YEAR_MONTH, risk_score, risk_bucket, risk_rank_in_geo,
       top_risk_drivers, model_name, scored_at)
    SELECT
      s.model_geo, s.EMP_ID, s.YEAR_MONTH, s.risk_score,
      CASE WHEN s.risk_score >= c.red_threshold   THEN 'RED'
           WHEN s.risk_score >= c.amber_threshold THEN 'AMBER'
           ELSE 'GREEN' END,
      RANK() OVER (ORDER BY s.risk_score DESC),
      (SELECT STRING_AGG(a.feature, ', '
                ORDER BY IF(s.is_positive, a.attribution, -a.attribution) DESC LIMIT 3)
       FROM UNNEST(s.top_feature_attributions) a
       WHERE IF(s.is_positive, a.attribution, -a.attribution) > 0),
      CONCAT('ews_model_', LOWER(g.GEO)),
      CURRENT_TIMESTAMP()
    FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_scored_stage` s
    JOIN `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` c ON c.geo = s.model_geo;

    -- ===== Risk calculation at variable level (with the employee's actual value) =====
    INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk`
      (geo, EMP_ID, YEAR_MONTH, feature, feature_value, risk_contribution, driver_rank, scored_at)
    SELECT
      s.model_geo, s.EMP_ID, s.YEAR_MONTH, a.feature,
      JSON_VALUE(TO_JSON(s)[a.feature]),
      IF(s.is_positive, a.attribution, -a.attribution),
      RANK() OVER (PARTITION BY s.EMP_ID
                   ORDER BY IF(s.is_positive, a.attribution, -a.attribution) DESC),
      CURRENT_TIMESTAMP()
    FROM `YOUR_PROJECT_ID.demo_bqml_classification.ews_scored_stage` s
    CROSS JOIN UNNEST(s.top_feature_attributions) a
    WHERE IF(s.is_positive, a.attribution, -a.attribution) > 0;

    -- ===== Geo-level variable risk (global drivers of this month's model) =====
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `YOUR_PROJECT_ID.demo_bqml_classification.ews_geo_drivers` (geo, YEAR_MONTH, feature, attribution, scored_at)
      SELECT '%s', %d, feature, attribution, CURRENT_TIMESTAMP()
      FROM ML.GLOBAL_EXPLAIN(MODEL `YOUR_PROJECT_ID.demo_bqml_classification.ews_model_%s`)
    """, g.GEO, scoring_month, LOWER(g.GEO));
  END FOR;

  DROP TABLE IF EXISTS `YOUR_PROJECT_ID.demo_bqml_classification.ews_scored_stage`;
END;

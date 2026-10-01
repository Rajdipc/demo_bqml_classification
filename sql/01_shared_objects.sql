-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 01  Shared objects: helper function, model-ready view, geo feature flags,
--     guardrail, per-geo feature list, Red/Amber config, EWS output tables.
-- Run as ONE script (click Run once). Safe to re-run.
-- =====================================================================

-- 01a. Helper: parse a date that arrives as 'm/d/yyyy h:mm' text or as ISO DATE/DATETIME
CREATE OR REPLACE FUNCTION `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(s STRING) AS (
  COALESCE(SAFE_CAST(LEFT(s, 10) AS DATE),
           DATE(SAFE.PARSE_DATETIME('%m/%d/%Y %H:%M', s)))
);

-- 01b. Model-ready view over the feature store.
--      Dates -> "days before the snapshot month-end"; column names kept so feature_config still applies.
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features` AS
WITH base AS (
  SELECT *,
         LAST_DAY(PARSE_DATE('%Y%m', CAST(YEAR_MONTH AS STRING))) AS snapshot_date
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_store`
)
SELECT
  * EXCEPT (
    snapshot_date,
    EMP_ACTION_DATE, DV_WEEK_EMP_ACTION_DATE, DV_EMP_RECENT_DATE_JOINING,
    DV_MONTHS_EMP_ACTION_DATE, DV_DAY_EMP_ACTION_DATE, DV_EMP_COMPANY_SENIORITY_DATE,
    DV_WDAY_EMP_RECENT_DATE_JOINING, DV_WDAY_EMP_ACTION_DATE,
    DV_WEEK_EMP_ORGINSTANCE_SERVICE_DATE, DV_DAY_EMP_RECENT_DATE_JOINING),
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(EMP_ACTION_DATE AS STRING)), DAY)                      AS EMP_ACTION_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_WEEK_EMP_ACTION_DATE AS STRING)), DAY)              AS DV_WEEK_EMP_ACTION_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_EMP_RECENT_DATE_JOINING AS STRING)), DAY)           AS DV_EMP_RECENT_DATE_JOINING,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_MONTHS_EMP_ACTION_DATE AS STRING)), DAY)            AS DV_MONTHS_EMP_ACTION_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_DAY_EMP_ACTION_DATE AS STRING)), DAY)               AS DV_DAY_EMP_ACTION_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_EMP_COMPANY_SENIORITY_DATE AS STRING)), DAY)        AS DV_EMP_COMPANY_SENIORITY_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_WDAY_EMP_RECENT_DATE_JOINING AS STRING)), DAY)      AS DV_WDAY_EMP_RECENT_DATE_JOINING,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_WDAY_EMP_ACTION_DATE AS STRING)), DAY)              AS DV_WDAY_EMP_ACTION_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_WEEK_EMP_ORGINSTANCE_SERVICE_DATE AS STRING)), DAY) AS DV_WEEK_EMP_ORGINSTANCE_SERVICE_DATE,
  DATE_DIFF(snapshot_date, `YOUR_PROJECT_ID.demo_bqml_classification.to_date_any`(CAST(DV_DAY_EMP_RECENT_DATE_JOINING AS STRING)), DAY)       AS DV_DAY_EMP_RECENT_DATE_JOINING,
  CAST(NULL AS STRING) AS GEO   -- SAMPLE ONLY: Model_Data.csv has no GEO column. Remove this line when feature_store provides GEO.
FROM base;

-- 01c. Procedure that rebuilds the geo feature flags from feature_config (long format: feature, geo, flag).
--      The geo list is read from geo_config, so adding a geo needs no code change.
CREATE OR REPLACE PROCEDURE `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`()
BEGIN
  DECLARE geo_list STRING;
  SET geo_list = (SELECT STRING_AGG(GEO, ', ' ORDER BY GEO) FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config`);
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_flags` AS
    SELECT MODEL_FEATURES AS feature, geo, CAST(flag AS INT64) AS flag
    FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_config`
    UNPIVOT (flag FOR geo IN (%s))
  """, geo_list);
END;

CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_refresh_feature_flags`();

-- 01d. Guardrail: columns never used as model inputs, even if flagged in feature_config
CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.feature_exclusions` AS
SELECT * FROM UNNEST([
  STRUCT('target' AS feature, 'Label' AS reason),
  ('GEO',                    'Geo selector'),
  ('YEAR_MONTH',             'Snapshot key'),
  ('DV_EMP_MTH_YEAR_MONTH',  'Duplicate of YEAR_MONTH'),
  ('EMP_ID',                 'Identifier'),
  ('EMP_PROJECT_ID',         'Identifier'),
  ('EMP_SUPERVISOR_ID',      'Identifier'),
  ('EMP_SUB_PROGRAM_ID',     'Identifier'),
  ('EMP_PROJECT_MANAGER_ID', 'Identifier'),
  ('EMP_LAST_ACTION_REASON', 'Near-unique code'),
  ('EMP_LAST_ACTION',        'Near-unique code'),
  ('EMP_STATE',              'Near-unique code'),
  ('EMP_DESIGNATION',        'Near-unique code'),
  ('EMP_COMPANY',            'Near-unique code'),
  ('EMP_TYPE',               'Near-unique code'),
  ('EMP_VERTICAL',           'Near-unique code'),
  ('DV_EMP_DOJ',             'Near-unique code'),
  ('EMP_REGULAR_TEMP',       'Constant'),
  ('EMP_JOB_CODE',           'Constant'),
  ('EMP_MEDIUM',             'Constant'),
  ('EMP_TEAM_CODE',          'Constant')
]);

-- 01e. FEATURE SELECTION: final feature list per geo = flagged AND present in the view AND not excluded
CREATE OR REPLACE VIEW `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` AS
SELECT f.geo,
       COUNT(*) AS n_features,
       STRING_AGG(f.feature, ', ' ORDER BY f.feature) AS feature_list
FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_flags` f
JOIN `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS` c
  ON c.table_name = 'v_model_features' AND c.column_name = f.feature
LEFT JOIN `YOUR_PROJECT_ID.demo_bqml_classification.feature_exclusions` x ON x.feature = f.feature
WHERE f.flag = 1 AND x.feature IS NULL
GROUP BY f.geo;

-- 01f. Red / Amber configuration per geo.
--      method = 'PERCENTILE': RED = top red_top_pct % of scores, AMBER = next amber_next_pct %
--                             (thresholds recalculated automatically every run).
--      method = 'FIXED'     : red_threshold / amber_threshold are used as entered.
CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config` AS
SELECT GEO                 AS geo,
       'PERCENTILE'        AS method,
       10                  AS red_top_pct,
       20                  AS amber_next_pct,
       0.70                AS red_threshold,
       0.40                AS amber_threshold,
       CURRENT_TIMESTAMP() AS updated_at
FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config`;

-- 01g. EWS output tables (created once; the monthly procedure appends per month)
CREATE TABLE IF NOT EXISTS `YOUR_PROJECT_ID.demo_bqml_classification.ews_employee_risk` (
  geo STRING, EMP_ID STRING, YEAR_MONTH INT64,
  risk_score FLOAT64, risk_bucket STRING, risk_rank_in_geo INT64,
  top_risk_drivers STRING, model_name STRING, scored_at TIMESTAMP
) CLUSTER BY geo, risk_bucket;

CREATE TABLE IF NOT EXISTS `YOUR_PROJECT_ID.demo_bqml_classification.ews_variable_risk` (
  geo STRING, EMP_ID STRING, YEAR_MONTH INT64,
  feature STRING, feature_value STRING, risk_contribution FLOAT64,
  driver_rank INT64, scored_at TIMESTAMP
) CLUSTER BY geo, EMP_ID;

CREATE TABLE IF NOT EXISTS `YOUR_PROJECT_ID.demo_bqml_classification.ews_geo_drivers` (
  geo STRING, YEAR_MONTH INT64, feature STRING, attribution FLOAT64, scored_at TIMESTAMP
);

-- 01h. Quick look
SELECT geo, n_features FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list` ORDER BY geo;

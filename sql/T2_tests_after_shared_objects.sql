-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- T2  Tests after shared objects  (Checkpoint 2)
-- Run as ONE query. All rows should be PASS.
-- =====================================================================
WITH
v AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_model_features`),
gl AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.v_geo_feature_list`),
t AS (
  SELECT 'T201' AS test_id, 'feature_flags rows (100 features x 7 geos)' AS scenario,
         '700' AS expected, CAST(COUNT(*) AS STRING) AS observed, CAST(NULL AS BOOL) AS ok
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_flags`

  UNION ALL
  SELECT 'T202', 'feature_flags with flag = 1 (as in feature_config)', '549',
         CAST(COUNTIF(flag = 1) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_flags`

  UNION ALL
  SELECT 'T203', 'Resolved model features per geo (Profile A = 41, Profile B = 75)',
         'JEM:41, JYZ:75, KAS:41, MEY:75, PHY:75, SFY:75, ULK:41',
         STRING_AGG(FORMAT('%s:%d', geo, n_features), ', ' ORDER BY geo), NULL
  FROM gl

  UNION ALL
  SELECT 'T204', 'Guardrail: excluded columns present in any resolved feature list', '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM gl, UNNEST(SPLIT(gl.feature_list, ', ')) AS feat
  JOIN `YOUR_PROJECT_ID.demo_bqml_classification.feature_exclusions` x ON x.feature = feat

  UNION ALL
  SELECT 'T205', 'Workforce-telemetry (TOTAL_*) features per geo (A = 0, B = 34)',
         'JEM:0, JYZ:34, KAS:0, MEY:34, PHY:34, SFY:34, ULK:0',
         STRING_AGG(FORMAT('%s:%d', geo, n_total), ', ' ORDER BY geo), NULL
  FROM (SELECT geo,
               (SELECT COUNTIF(STARTS_WITH(f, 'TOTAL_')) FROM UNNEST(SPLIT(feature_list, ', ')) f) AS n_total
        FROM gl)

  UNION ALL
  SELECT 'T206', 'v_model_features row count', '5000', CAST(COUNT(*) AS STRING), NULL
  FROM v

  UNION ALL
  SELECT 'T207', 'Date columns that failed to convert (NULL day counts, 10 columns)', '0',
         CAST(COUNTIF(EMP_ACTION_DATE IS NULL OR DV_WEEK_EMP_ACTION_DATE IS NULL
                   OR DV_EMP_RECENT_DATE_JOINING IS NULL OR DV_MONTHS_EMP_ACTION_DATE IS NULL
                   OR DV_DAY_EMP_ACTION_DATE IS NULL OR DV_EMP_COMPANY_SENIORITY_DATE IS NULL
                   OR DV_WDAY_EMP_RECENT_DATE_JOINING IS NULL OR DV_WDAY_EMP_ACTION_DATE IS NULL
                   OR DV_WEEK_EMP_ORGINSTANCE_SERVICE_DATE IS NULL
                   OR DV_DAY_EMP_RECENT_DATE_JOINING IS NULL) AS STRING), NULL
  FROM v

  UNION ALL
  SELECT 'T208', 'Converted date column type in the view (EMP_ACTION_DATE)', 'INT64',
         ANY_VALUE(data_type), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'v_model_features' AND column_name = 'EMP_ACTION_DATE'

  UNION ALL
  SELECT 'T209', 'Known data issue: EMP_ACTION_DATE after snapshot month (negative days)', '1726',
         CAST(COUNTIF(EMP_ACTION_DATE < 0) AS STRING), NULL
  FROM v

  UNION ALL
  SELECT 'T210', 'Backtest split sizes', 'TRAIN 3649 / EVAL 749 / TEST 602',
         FORMAT('TRAIN %d / EVAL %d / TEST %d',
                COUNTIF(YEAR_MONTH <= 202512),
                COUNTIF(YEAR_MONTH BETWEEN 202601 AND 202605),
                COUNTIF(YEAR_MONTH > 202605)), NULL
  FROM v

  UNION ALL
  SELECT 'T211', 'Positives (target = 1) per split', 'TRAIN 1289 / EVAL 279 / TEST 194',
         FORMAT('TRAIN %d / EVAL %d / TEST %d',
                COUNTIF(YEAR_MONTH <= 202512 AND target = 1),
                COUNTIF(YEAR_MONTH BETWEEN 202601 AND 202605 AND target = 1),
                COUNTIF(YEAR_MONTH > 202605 AND target = 1)), NULL
  FROM v

  UNION ALL
  SELECT 'T212', 'risk_bucket_config defaults', '7 rows, PERCENTILE, RED top 10%, AMBER next 20%',
         FORMAT('%d rows, %s, RED top %d%%, AMBER next %d%%',
                COUNT(*), ANY_VALUE(method), MAX(red_top_pct), MAX(amber_next_pct)), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.risk_bucket_config`

  UNION ALL
  SELECT 'T213', 'EWS output tables exist', '3', CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.TABLES`
  WHERE table_name IN ('ews_employee_risk', 'ews_variable_risk', 'ews_geo_drivers')
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN STARTS_WITH(expected, 'INFO') THEN 'INFO'
            WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t
ORDER BY test_id;

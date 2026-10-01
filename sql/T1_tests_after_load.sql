-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- T1  Tests after data load  (Checkpoint 1)
-- Run as ONE query. Each output row = one test. All rows should be PASS.
-- =====================================================================
WITH
fs AS (SELECT * FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_store`),
t AS (
  SELECT 'T101' AS test_id, 'feature_store row count' AS scenario,
         '5000' AS expected, CAST(COUNT(*) AS STRING) AS observed, CAST(NULL AS BOOL) AS ok
  FROM fs

  UNION ALL
  SELECT 'T102', 'feature_store column count', '100', CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS` WHERE table_name = 'feature_store'

  UNION ALL
  SELECT 'T103', 'Label distribution (target=0 / target=1)', '3238 / 1762',
         FORMAT('%d / %d', COUNTIF(target = 0), COUNTIF(target = 1)), NULL
  FROM fs

  UNION ALL
  SELECT 'T104', 'Rows with NULL label', '0', CAST(COUNTIF(target IS NULL) AS STRING), NULL
  FROM fs

  UNION ALL
  SELECT 'T105', 'YEAR_MONTH range (distinct months)', '202401 - 202609 (33)',
         FORMAT('%d - %d (%d)', MIN(YEAR_MONTH), MAX(YEAR_MONTH), COUNT(DISTINCT YEAR_MONTH)), NULL
  FROM fs

  UNION ALL
  SELECT 'T106', 'Data types of target, YEAR_MONTH, EMP_ID, EMP_ACTION_DATE',
         'INT64, INT64, STRING, STRING',
         STRING_AGG(data_type, ', ' ORDER BY CASE column_name
                      WHEN 'target' THEN 1 WHEN 'YEAR_MONTH' THEN 2 WHEN 'EMP_ID' THEN 3 ELSE 4 END), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'feature_store'
    AND column_name IN ('target', 'YEAR_MONTH', 'EMP_ID', 'EMP_ACTION_DATE')

  UNION ALL
  SELECT 'T107', 'Duplicate (EMP_ID, YEAR_MONTH) keys - known synthetic-data issue (E777899 / 202504)',
         '1', CAST(COUNT(*) AS STRING), NULL
  FROM (SELECT EMP_ID, YEAR_MONTH FROM fs GROUP BY EMP_ID, YEAR_MONTH HAVING COUNT(*) > 1)

  UNION ALL
  SELECT 'T108', 'Rows in the scoring month 202609', '149',
         CAST(COUNTIF(YEAR_MONTH = 202609) AS STRING), NULL
  FROM fs

  UNION ALL
  SELECT 'T109', 'feature_config row count', '100', CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_config`

  UNION ALL
  SELECT 'T110', 'geo_config rows and values', '7: JEM,JYZ,KAS,MEY,PHY,SFY,ULK',
         FORMAT('%d: %s', COUNT(*), STRING_AGG(GEO, ',' ORDER BY GEO)), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config`

  UNION ALL
  SELECT 'T111', 'Geos in geo_config without a column in feature_config', '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.geo_config` g
  LEFT JOIN `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS` c
    ON c.table_name = 'feature_config' AND c.column_name = g.GEO
  WHERE c.column_name IS NULL

  UNION ALL
  SELECT 'T112', 'Features in feature_config missing from feature_store', '0',
         CAST(COUNT(*) AS STRING), NULL
  FROM `YOUR_PROJECT_ID.demo_bqml_classification.feature_config` f
  LEFT JOIN `YOUR_PROJECT_ID.demo_bqml_classification.INFORMATION_SCHEMA.COLUMNS` c
    ON c.table_name = 'feature_store' AND c.column_name = f.MODEL_FEATURES
  WHERE c.column_name IS NULL
)
SELECT test_id, scenario, expected, observed,
       CASE WHEN STARTS_WITH(expected, 'INFO') THEN 'INFO'
            WHEN ok IS NOT NULL THEN IF(ok, 'PASS', 'FAIL')
            WHEN expected = observed THEN 'PASS' ELSE 'FAIL' END AS status
FROM t
ORDER BY test_id;

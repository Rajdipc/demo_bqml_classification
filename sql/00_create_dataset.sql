-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 00  Create the dataset (us-central1)
-- Run in BigQuery Studio with project YOUR_PROJECT_ID selected.
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS `YOUR_PROJECT_ID.demo_bqml_classification`
OPTIONS (
  location    = 'us-central1',
  description = 'Demo: EWS employee risk classification with BigQuery ML'
);

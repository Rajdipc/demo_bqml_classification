-- =====================================================================
-- BEFORE RUNNING: replace every YOUR_PROJECT_ID in this file with your Google Cloud project ID.
-- 03b  Execute the monthly EWS run for September 2026 (latest month in the sample)
-- Trains 7 production models (ews_model_<geo>) and scores 202609. ~20-35 minutes.
-- In the results pane you will see every child statement the procedure executed.
-- =====================================================================
CALL `YOUR_PROJECT_ID.demo_bqml_classification.sp_ews_monthly_run`(202609);

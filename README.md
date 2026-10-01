# Employee Risk Classification for Early Warning System (EWS) on BigQuery ML

[![Release](https://img.shields.io/badge/Release-v1.0.0-blue.svg)](https://github.com/Rajdipc/demo_bqml_classification/releases)
[![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/)
[![BigQuery ML](https://img.shields.io/badge/BigQuery_ML-BQML-669DF6?logo=googlebigquery&logoColor=white)](https://cloud.google.com/bigquery/docs/bqml-introduction)
[![SQL](https://img.shields.io/badge/Dialect-GoogleSQL-0F9D58?logo=googlecloud&logoColor=white)](https://cloud.google.com/bigquery)
[![Model](https://img.shields.io/badge/Model-Boosted_Trees_(XGBoost)-34A853)](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create-boosted-tree)
[![Explainable AI](https://img.shields.io/badge/XAI-ML.EXPLAIN__PREDICT-EA4335)](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-explain-predict)
[![Automated Tests](https://img.shields.io/badge/Tests-63_Automated_Assertions-success)](sql/)

`#BigQuery` &nbsp;•&nbsp; `#BigQueryML` &nbsp;•&nbsp; `#BQML` &nbsp;•&nbsp; `#GoogleCloud` &nbsp;•&nbsp; `#MachineLearning` &nbsp;•&nbsp; `#Classification` &nbsp;•&nbsp; `#XGBoost` &nbsp;•&nbsp; `#BoostedTrees` &nbsp;•&nbsp; `#ExplainableAI` &nbsp;•&nbsp; `#EarlyWarningSystem` &nbsp;•&nbsp; `#MLOps` &nbsp;•&nbsp; `#SQL`

---

This repository contains an end-to-end BigQuery ML (BQML) implementation for **Employee Risk Classification** in the **Early Warning System (EWS)**, migrating the model sandbox from an on-premise SQL Server + custom Python environment to a serverless, in-database architecture on Google Cloud BigQuery.

## 📌 Overview

> [!NOTE]
> **Demo & Synthetic Data Notice:** This repository is developed **strictly for demonstration and architectural evaluation purposes**. All datasets included in [`data/`](data/) (`Model_Data.csv`, `geo_config.csv`, and `feature_config.csv`) consist of **entirely synthetic, anonymized sample data**. No confidential, customer, or real employee Personally Identifiable Information (PII) is present.

The solution replaces Python-based loops, external data extractions, and standalone serialized model objects with:
- **In-Database Training & Scoring:** BigQuery ML Boosted Tree models trained and evaluated directly inside BigQuery.
- **Dynamic Configuration:** Geo-specific feature selection and thresholds driven by configuration tables (`geo_config`, `feature_config`).
- **Explainability:** Native `ML.EXPLAIN_PREDICT` attribution identifying the top risk drivers per employee.
- **Automated Verification:** 63 automated test assertions (`T1`-`T5`) and 4 business change scenarios (`M1`-`M4`).

## 📖 Runbook & In-Depth Documentation

For complete technical specifications, architectural diagrams, operational procedures, and verification benchmarks, refer to **[`Runbook.md`](Runbook.md)**. Key sections covered in the Runbook include:
- **Architecture & System Mapping (§2 & §3):** Process mapping from SQL Server + Python to BigQuery ML.
- **Feature Store & Configuration Design (§4 & §5):** Dynamic feature resolution and error guardrails.
- **Model Training, Calibration & Explainability (§6 & §7):** Boosted Tree training, Red/Amber risk bucket calibration, and `ML.EXPLAIN_PREDICT` attribution.
- **Production Stored Procedure & EWS Feeds (§8 & §9):** Automated monthly runs and downstream view integration.
- **Automated Verification & Scenarios (§10):** 63 automated test assertions (`T1`–`T5`) and 4 business change scenarios (`M1`–`M4`).
- **Decision Guide (§11):** Go/no-go criteria and validation evidence.

---

## 📂 Repository Structure

```text
├── Runbook.md                               # Comprehensive runbook, solution design & verification approach
├── README.md                                # Project summary & guide
├── data/                                    # Dataset samples and schemas
│   ├── Model_Data.csv                       # Synthetic training & evaluation feature data
│   ├── Model_Data.schema.json               # BigQuery JSON schema for Model_Data
│   ├── Model_Data.schema.txt                # Plaintext schema reference
│   ├── feature_config.csv                   # Geo-level feature selection flags
│   ├── feature_config.schema.json           # Schema for feature_config
│   ├── geo_config.csv                       # Active geographies configuration
│   ├── geo_config.schema.json               # Schema for geo_config
│   └── raw/                                 # Raw input copies
└── sql/                                     # SQL scripts and pipelines
    ├── 00_create_dataset.sql                # Dataset creation and setup
    ├── 01_shared_objects.sql                # Base tables, views, and helper functions
    ├── 02a_backtest_train.sql               # Model training script for backtest
    ├── 02b_backtest_evaluate.sql            # Model evaluation metrics calculation
    ├── 02c_backtest_calibrate_buckets.sql   # Calibration of Red/Amber risk buckets
    ├── 02d_backtest_capture.sql             # Capture historical backtest predictions
    ├── 02e_backtest_explain.sql             # Feature attribution & explainability
    ├── 03a_create_monthly_procedure.sql     # Stored procedure for automated monthly run
    ├── 03b_call_monthly_procedure.sql       # Execution wrapper for monthly procedure
    ├── 04_ews_views.sql                     # Views feeding downstream EWS consumption
    ├── 98_optional_scheduled_query.sql      # Scheduled query orchestration template
    ├── 99_cleanup.sql                       # Teardown / cleanup script
    ├── M1_scenario_feature_config_change.sql# Scenario: Modifying feature selection
    ├── M2_scenario_new_geo_onboarding.sql   # Scenario: Onboarding a new geography
    ├── M3_scenario_rerun_idempotency.sql    # Scenario: Verifying rerun idempotency
    ├── M4_scenario_config_error_guard.sql   # Scenario: Guardrail against invalid configs
    ├── T1_tests_after_load.sql              # Test suite: Post data load verification
    ├── T2_tests_after_shared_objects.sql    # Test suite: Schema & shared objects verification
    ├── T3_tests_after_backtest.sql          # Test suite: Backtest metrics verification
    ├── T4_tests_after_monthly_run.sql       # Test suite: Monthly run outputs verification
    └── T5_tests_after_ews_views.sql         # Test suite: Downstream view output verification
```

---

## 🚀 Execution Sequence

1. **Setup & Initialization:**
   - Execute `sql/00_create_dataset.sql` to initialize target datasets.
   - Load CSVs from `data/` into corresponding BigQuery tables using the provided JSON schemas.
   - Execute `sql/01_shared_objects.sql` to build configuration tables and views.
   - Verify setup: Run `sql/T1_tests_after_load.sql` and `sql/T2_tests_after_shared_objects.sql`.

2. **Backtesting & Calibration:**
   - Execute scripts `sql/02a_backtest_train.sql` through `sql/02e_backtest_explain.sql`.
   - Verify backtest: Run `sql/T3_tests_after_backtest.sql`.

3. **Monthly Automated Run & EWS Views:**
   - Create and invoke the monthly run stored procedure via `sql/03a_create_monthly_procedure.sql` and `sql/03b_call_monthly_procedure.sql`.
   - Create downstream consumption views via `sql/04_ews_views.sql`.
   - Verify monthly pipeline: Run `sql/T4_tests_after_monthly_run.sql` and `sql/T5_tests_after_ews_views.sql`.

4. **Scenario Validation:**
   - Run `sql/M1_*` through `sql/M4_*` to validate configuration adjustments, geo onboarding, idempotency, and error handling.

---

## 🏭 Extending to Production

While this repository demonstrates end-to-end BQML modeling, explainability, and stored procedure logic on synthetic data, moving this solution to an enterprise production environment involves the following extensions:

| Dimension | Demo Implementation | Production Architecture Extension |
|---|---|---|
| **Data Ingestion** | Static CSV loads via `bq load` / schema files | Automated ELT pipelines using **Cloud Dataflow** or **BigQuery Data Transfer Service (DTS)** ingesting directly from source HR systems (SQL Server, Workday, SAP). Enforce automated schema validation, deduplication, and quarantine tables for malformed records. |
| **Workflow Orchestration** | Manual SQL runs / single Scheduled Query | Enterprise workflow orchestration using **Cloud Composer (Apache Airflow)** or **Cloud Workflows**. Orchestrate the end-to-end DAG: upstream data sync &rarr; feature store refresh &rarr; `sp_ews_monthly_run` &rarr; automated test assertion suites (`T1`–`T5`) &rarr; downstream publish & alerting. |
| **Table Optimization & Cost** | Standard BigQuery tables | **Partitioning** on snapshot date (`DATE(snapshot_date)`) and **Clustering** on `GEO` and `employee_id`. Enforce partition filters in queries to prevent full table scans and minimize BigQuery analysis slot costs. |
| **Security & Governance** | Dataset-level IAM permissions | **IAM Least Privilege** with dedicated Google Service Accounts for pipeline jobs. Enforce **Column-level Security (Policy Tags)** on sensitive attributes, **Row-Level Security (RLS)** by geography, **VPC Service Controls (VPC-SC)**, and **CMEK** encryption. |
| **MLOps & Governance** | In-database model objects (`ews_model_<geo>`) | Centralized model tracking via **Vertex AI Model Registry**. Set up automated performance monitoring (ROC-AUC drift, prediction distribution drift, feature attribution shifts) with alerting triggers for model retraining. |
| **Responsible AI & Fairness** | Business logic exclusion table (`feature_exclusions`) | Formal **Fairness & Bias Auditing** evaluated on mature historical cohorts across demographic dimensions prior to model deployment. Maintain model cards and compliance sign-off workflows. |
| **Downstream Delivery** | Static BigQuery views (`v_ews_feed`) | Direct read integration from authorized BI dashboards (Looker / PowerBI) and reverse ETL via **Dataflow** or **Eventarc + Cloud Functions** to push Red/Amber risk alerts directly into the EWS operational systems. |


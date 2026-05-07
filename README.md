# HCM Air Quality Analytics Pipeline

[![dbt CI](https://github.com/luc-dt/hcm-air-quality-pipeline/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/luc-dt/hcm-air-quality-pipeline/actions/workflows/dbt_ci.yml)

> An end-to-end batch data pipeline ingesting four years of Ho Chi Minh City
> air quality data through a medallion architecture on GCS and BigQuery.
>
> The pipeline uses production-grade patterns: fail-fast PySpark validation
> before silver writes, Hive-partitioned storage for predicate pushdown, custom
> dbt singular tests for domain constraints, and GitHub Actions CI — with
> infrastructure provisioned entirely via Terraform.


---

## Problem Statement

Ho Chi Minh City consistently ranks among Southeast Asia's most polluted cities,
with AQI levels frequently exceeding WHO safe thresholds due to dense traffic,
industrial activity, and seasonal weather patterns. Despite the availability of
historical air quality data, there is no accessible tool that surfaces multi-year
pollution trends and category distributions for public awareness.

This pipeline processes daily historical measurements (2022–2026) combined with
live hourly API data, enabling data-driven answers to questions like: _When does
air quality deteriorate most? Which pollutants dominate? Are conditions improving
year over year?_

---

## Table of Contents

- [Architecture & Tech Stack](#architecture--tech-stack)
- [Data Flow & Modeling](#data-flow--modeling)
- [Design Decisions](#design-decisions)
- [Repository Structure](#repository-structure)
- [How to Reproduce](#how-to-reproduce)

---

## Architecture & Tech Stack

```text
Open-Meteo API  ──► Kestra ──► GCS bronze/hourly/YYYY-MM-DD/HH/
Zenodo CSV      ──► Kestra ──► GCS bronze/historical/
                                        │
                                     PySpark
                                        │
                         GCS silver/hourly/  +  silver/historical/
                                        │
                                    BigQuery
                                        │
                   dbt (stg_hourly + stg_historical → mart_daily_aqi + mart_pollutants)
                                        │
                               Looker Studio dashboard
```

![Architecture Diagram](images/new_architecture.svg)

> Infrastructure (GCS bucket, BigQuery dataset, and external tables) is provisioned by Terraform.
> Kestra runs locally via Docker Compose.
> PySpark scripts live in `spark/`; exploratory notebooks are archived in `notebooks/exploration/`.

### Tech Stack

| Layer          | Tool                                            |
| -------------- | ----------------------------------------------- |
| **Infrastructure** | Terraform + GCP                                 |
| **Orchestration**  | Kestra (Docker Compose)                         |
| **Processing**     | PySpark                                         |
| **Data Lake**      | Google Cloud Storage (medallion: bronze/silver) |
| **Data Warehouse** | BigQuery (partitioned external tables)          |
| **Transformation** | dbt                                             |
| **Dashboard**      | Looker Studio                                   |

---

## Data Flow & Modeling

### 1. Data Sources

#### Historical (One-time backfill)
- **Source:** [Zenodo — Air Quality Dataset for Ho Chi Minh City](https://zenodo.org/records/18673714)
- **Coverage:** 2022-08-01 to 2026-02-18, daily averages
- **Columns:** `date, pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, aerosol_optical_depth, dust, uv_index, us_aqi, european_aqi`
- **Note:** Raw date format is `DD-MM-YY` — converted to `YYYY-MM-DD` in PySpark

#### Live (Hourly)
- **Source:** [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api)
- **Coordinates:** 10.8231° N, 106.6297° E (Ho Chi Minh City)
- **Frequency:** Every hour via Kestra scheduler

### 2. GCS Structure (Data Lake)

```text
hcm-air-quality-486008/
├── bronze/
│   ├── hourly/YYYY-MM-DD/HH/air_quality.json     ← raw API response (one per hour)
│   └── historical/air_quality_historical.csv     ← raw Zenodo CSV
└── silver/
    ├── hourly/date=YYYY-MM-DD/                   ← cleaned Parquet, partitioned by date
    └── historical/                               ← cleaned Parquet
```

### 3. Warehouse Design (BigQuery & dbt)

BigQuery external tables point directly at GCS silver Parquet files, partitioned by `date` to eliminate full scans for date-range queries.

**dbt Layers:**

| Layer   | Model             | Description                                          |
| ------- | ----------------- | ---------------------------------------------------- |
| Staging | `stg_hourly`      | Timestamp parsing, type casting, column renaming     |
| Staging | `stg_historical`  | Date format fix (`DD-MM-YY` → `DATE`), type casting  |
| Mart    | `mart_daily_aqi`  | Daily AQI, 7-day rolling average, AQI category label |
| Mart    | `mart_pollutants` | Daily pollutant concentrations (PM2.5, PM10, etc.)   |

![dbt Lineage](images/dbt_lineage.png)

### 4. Data Quality

**PySpark validation (pre-silver write):**
Both transform scripts raise an exception and abort the silver write if row count is zero, or all `us_aqi` values are null. This prevents silent data quality failures downstream.

**dbt tests (10 total):**

| Layer   | Model             | Column        | Test                                                     |
|---------|-------------------|---------------|----------------------------------------------------------|
| Staging | `stg_hourly`      | `observed_at` | `not_null`                                               |
| Staging | `stg_historical`  | `observed_at` | `not_null`                                               |
| Mart    | `mart_daily_aqi`  | `observed_at` | `not_null`, `unique`                                     |
| Mart    | `mart_daily_aqi`  | `us_aqi`      | `not_null`, `assert_aqi_range` (0-500)                   |
| Mart    | `mart_daily_aqi`  | `aqi_category`| `accepted_values` (Good → Hazardous)                     |
| Mart    | `mart_pollutants` | `observed_at` | `not_null`, `unique`                                     |
| Mart    | `mart_pollutants` | all pollutants| `assert_pollutants_non_negative`                         |

---

## Design Decisions

- **Strict Separation of Concerns:** `kestra/` contains only orchestration flows. PySpark processing scripts live in `spark/` and are invoked by Kestra at runtime. Mixing processing logic into orchestration flows makes both harder to test and maintain.
- **Local GCS Connector JAR:** Using `spark.jars.packages` downloads the connector from Maven Central at job startup (~40MB, ~60s). The JAR is pre-downloaded to `jars/` and loaded via `spark.driver.extraClassPath`, making job startup deterministic and offline-capable.
- **BigQuery External Tables:** Silver data stays in GCS (source of truth). External tables give BigQuery query access without duplicating storage or running a load job. Appropriate for this data volume and access pattern.
- **Fail-fast PySpark Validations:** Both transform scripts validate row count and null AQI values before any write, skipping if invalid.
- **Hourly Silver Partitioning:** Output path `silver/hourly/date=YYYY-MM-DD/` enables partition pruning on date-range queries in BigQuery without a full scan.

---

## Repository Structure

```text
hcm-air-quality-pipeline/
├── terraform/              # GCS + BigQuery provisioning
├── kestra/                 # Orchestration (Docker Compose, flows)
├── spark/                  # PySpark processing scripts
├── notebooks/              # Development notebooks (archived)
├── dbt/                    # Transformation models and data quality tests
├── data/                   # Local raw data (gitignored)
├── keys/                   # GCP service account key (gitignored)
├── Makefile                # Automation commands for terraform, kestra, dbt, spark
└── README.md
```

---

## How to Reproduce

### Prerequisites

- GCP account with billing enabled
- Terraform ≥ 1.5 installed
- Docker + Docker Compose installed
- Python 3.11+ with `uv` or `pip`, and Java 17 (required for PySpark)
- `make` (optional, but recommended for running shortcut commands)

### Step 1 — Clone and Configure

```bash
git clone https://github.com/luc-dt/hcm-air-quality-pipeline
cd hcm-air-quality-pipeline
```
Place your GCP service account key at `keys/hcm-pipeline-sa.json` (gitignored). Setup python environment using `make setup` and activate it.

### Step 2 — Provision Infrastructure

```bash
make tf-init
make tf-apply
```
_Creates GCS bucket `hcm-air-quality-486008` and BigQuery dataset `hcm_air_quality` in `asia-southeast1`. External tables are also provisioned by Terraform._

### Step 3 — Download Historical Dataset

Download `air_quality_historical.csv` from [Zenodo](https://zenodo.org/records/18673714) and place it at `data/air_quality_historical.csv`.

### Step 4 — Orchestration & Ingestion (Kestra)

```bash
make kestra-up
# UI available at http://localhost:8080
```
1. Import flows: Go to **Flows → Import** in Kestra UI and upload both YAML files from `kestra/flows/`.
2. Populate KV store with GCP credentials:
```bash
bash kestra/setup_kv.sh
```
3. Run flows from UI: `hcm_pipeline / historical_backfill` (once) and `hcm_pipeline / hourly_air_quality_ingest` (scheduler).

### Step 5 — Transform Data (PySpark)

You can trigger Spark jobs manually using Make commands:

```bash
# Historical (one-time)
make spark-historical

# Hourly (run for a specific date/hour you have in bronze)
make spark-hourly DATE=2024-01-15 HOUR=12
```

### Step 6 — Data Modeling & Tests (dbt)

Create `~/.dbt/profiles.yml` with the following content:

```yaml
hcm_air_quality:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: de-zoomcamp-2026-486008
      dataset: hcm_air_quality
      location: asia-southeast1
      keyfile: ../../keys/hcm-pipeline-sa.json
      threads: 4
      timeout_seconds: 300
```

Then use Make commands to install dependencies, run models, and test:
```bash
make dbt-deps
make dbt-build
```

### Step 7 — View Dashboard

- [View AQI Dashboard](https://lookerstudio.google.com/reporting/6439d918-7211-40b9-b49a-0bc56a0fd8e6)
- [View PM2.5 Dashboard](https://lookerstudio.google.com/reporting/4a9bf4b6-6383-4f5a-ac60-a8e2be89521e)

![AQI Trend](images/aqi_trend.png)
_7-day rolling AQI average shows consistent Moderate–Unhealthy levels across 2022–2026._

![PM2.5 Trend](images/pm25_trend.png)
_PM2.5 and PM10 concentrations consistently exceed WHO annual safe thresholds._

The Zenodo dataset is a fixed snapshot ending February 18, 2026; live hourly collection began April 8, 2026, leaving March without data.

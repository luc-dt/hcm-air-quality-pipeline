# HCM Air Quality Analytics Pipeline

> An end-to-end batch data pipeline that ingests four years of air quality data
> for Ho Chi Minh City, transforms it through a medallion architecture on GCS and
> BigQuery, and surfaces pollution trends via a Looker Studio dashboard.

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

## Architecture

```
Open-Meteo API  ──► Kestra ──► GCS bronze/hourly/YYYY-MM-DD/HH/
Zenodo CSV      ──► Kestra ──► GCS bronze/historical/
                                        │
                                     PySpark
                                        │
                         GCS silver/hourly/  +  silver/historical/
                                        │
                                    BigQuery
                                        │
                              dbt (stg → int_daily → mart_aqi)
                                        │
                               Looker Studio dashboard
```
![Architecture Diagram](images/new_architecture.svg)
> Infrastructure (GCS bucket + BigQuery dataset) is provisioned by Terraform.
> Kestra runs locally via Docker Compose.
> PySpark runs locally; development done in Jupyter notebooks under `notebooks/`.

---

## Tech Stack

| Layer          | Tool                                      |
| -------------- | ----------------------------------------- |
| Infrastructure | Terraform + GCP                           |
| Orchestration  | Kestra (Docker Compose)                   |
| Processing     | PySpark                                   |
| Data Lake      | Google Cloud Storage (medallion: bronze/silver) |
| Data Warehouse | BigQuery (partitioned + clustered)        |
| Transformation | dbt                                       |
| Dashboard      | Looker Studio                             |

---

## Why this stack?

PySpark is used for the bronze→silver transformation to demonstrate batch
processing skills. For this data volume (≈1,300 rows historical + hourly
increments), BigQuery SQL alone would be sufficient in production. The stack
reflects DE Zoomcamp curriculum coverage and a realistic junior DE portfolio.

---

## Data Sources

### Historical (one-time backfill)
- **Source:** [Zenodo — Air Quality Dataset for Ho Chi Minh City](https://zenodo.org/records/18673714)
- **Author:** Nitiraj Kulkarni
- **Coverage:** 2022-08-01 to 2026-02-18, daily averages
- **Columns:** `date, pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, aerosol_optical_depth, dust, uv_index, us_aqi, european_aqi`
- **Note:** Raw date format is `DD-MM-YY` — converted to `YYYY-MM-DD` in PySpark

### Live (hourly)
- **Source:** [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api)
- **Coordinates:** 10.8231° N, 106.6297° E (Ho Chi Minh City)
- **Frequency:** Every hour via Kestra scheduler
- **Auth:** None required (free API)

---

## GCS Structure

```
hcm-air-quality-486008/
├── bronze/
│   ├── hourly/YYYY-MM-DD/HH/air_quality.json    ← raw API response (24 hrs each)
│   └── historical/air_quality_historical.csv     ← raw Zenodo CSV
└── silver/
    ├── hourly/date=YYYY-MM-DD/                   ← cleaned Parquet, partitioned by date
    └── historical/                               ← cleaned Parquet
```

---

## Warehouse Design

The BigQuery tables loaded from silver Parquet are:

- **Partitioned by** `date` — eliminates full scans for date-range queries
- **Clustered by** `us_aqi` — accelerates AQI category filtering

dbt layers:

| Layer | Model | Description |
| ----- | ----- | ----------- |
| Staging | `stg_air_quality` | Type casting, column renaming |
| Intermediate | `int_daily` | Daily aggregates, 7-day rolling averages |
| Mart | `mart_aqi` | AQI category distribution, final dashboard grain |

---

## Dashboard

_(add Looker Studio public link here)_

---

## How to Reproduce

### Prerequisites

- GCP account with billing enabled
- Terraform ≥ 1.5 installed
- Docker + Docker Compose installed
- Python 3.11+ with `uv` or `pip`
- Java 17 (required for PySpark)

### Step 1 — Clone and configure

```bash
git clone https://github.com/luc-dt/hcm-air-quality-pipeline
cd hcm-air-quality-pipeline
```

Place your GCP service account key at `keys/hcm-pipeline-sa.json` (gitignored).

### Step 2 — Provision infrastructure

```bash
cd terraform
terraform init
terraform apply
```

Creates GCS bucket `hcm-air-quality-486008` and BigQuery dataset `hcm_air_quality`
in `asia-southeast1`.

### Step 3 — Download historical dataset

Download `air_quality_historical.csv` from
[Zenodo](https://zenodo.org/records/18673714) and place it at
`data/air_quality_historical.csv`.

### Step 4 — Start Kestra

```bash
cd kestra
docker compose up -d
# UI available at http://localhost:8080
# login: admin@kestra.io / Admin1234!
```

### Step 5 — Run Kestra flows

In the Kestra UI, execute:

1. `hcm.air_quality / historical_backfill` — uploads CSV to `bronze/historical/`
2. `hcm.air_quality / hourly_air_quality_ingest` — starts hourly data collection

### Step 6 — Run PySpark transforms

```bash
export GOOGLE_APPLICATION_CREDENTIALS=keys/hcm-pipeline-sa.json

# Historical (one-time)
jupyter notebook notebooks/transform_historical.ipynb

# Hourly (run for a specific date/hour you have in bronze)
jupyter notebook notebooks/transform_hourly.ipynb
```

### Step 7 — Load silver to BigQuery

_(BigQuery external table or load job — to be added)_

### Step 8 — Run dbt

```bash
cd dbt
dbt deps
dbt run
dbt test
```

### Step 9 — View dashboard

Open the Looker Studio link above.

---

## Repository Structure

```
hcm-air-quality-pipeline/
├── terraform/              # GCS + BigQuery provisioning
├── kestra/
│   ├── docker-compose.yml
│   └── flows/
│       ├── hourly_air_quality_ingest.yml
│       └── historical_backfill.yml
├── notebooks/              # PySpark development (Jupyter)
│   ├── transform_historical.ipynb
│   └── transform_hourly.ipynb
├── dbt/                    # Transformation models
├── data/                   # Local raw data (gitignored)
├── keys/                   # GCP service account key (gitignored)
└── README.md
```

---

## License

MIT

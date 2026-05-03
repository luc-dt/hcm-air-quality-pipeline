terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.6.0"
    }
  }

  # Remote state stored in GCS — credentials via GOOGLE_APPLICATION_CREDENTIALS env var
  backend "gcs" {
    bucket = "hcm-air-quality-486008"
    prefix = "terraform/state"
  }
}

# Credentials are resolved via GOOGLE_APPLICATION_CREDENTIALS env var (ADC)
provider "google" {
  project = var.project
  region  = var.region
}

# Data Lake (GCS Bucket)
resource "google_storage_bucket" "data-lake-bucket" {
  name          = var.gcs_bucket_name
  location      = var.location
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

# Data Warehouse (BigQuery Dataset)
resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.bq_dataset_name
  location   = var.location
}

# External table — silver/hourly (Hive-partitioned by date)
resource "google_bigquery_table" "raw_hourly" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = "raw_hourly"
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["gs://${var.gcs_bucket_name}/silver/hourly/*"]

    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "gs://${var.gcs_bucket_name}/silver/hourly/"
      require_partition_filter = false
    }
  }
}


# External table — silver/historical
resource "google_bigquery_table" "raw_historical" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = "raw_historical"
  deletion_protection = false

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris   = ["gs://${var.gcs_bucket_name}/silver/historical/*.parquet"]
  }
}
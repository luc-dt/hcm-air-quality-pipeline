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
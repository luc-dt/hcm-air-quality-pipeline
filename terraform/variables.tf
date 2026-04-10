variable "project" {
  description = "Project"
  default     = "de-zoomcamp-2026-486008"
}

variable "region" {
  description = "Region"
  default     = "asia-southeast1"
}

variable "location" {
  description = "Project Location"
  default     = "asia-southeast1"
}

variable "bq_dataset_name" {
  description = "My BigQuery Dataset Name"
  default     = "hcm_air_quality"
}

variable "gcs_bucket_name" {
  description = "GCS data lake bucket name"
  default     = "hcm-air-quality-486008"
}
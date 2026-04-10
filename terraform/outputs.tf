output "bucket_name" {
  description = "GCS data lake bucket name"
  value       = google_storage_bucket.data-lake-bucket.name
}

output "bq_dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.dataset.dataset_id
}

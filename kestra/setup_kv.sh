#!/bin/bash
set -e

# Task 1: Define the path to the local GCP Service Account JSON key
KEY_PATH="$(dirname "$0")/../keys/hcm-pipeline-sa.json"

# Task 2: Validate that the service account key actually exists
if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: Service account key not found at $KEY_PATH"
  exit 1
fi

# Task 3: Read the JSON credentials into a string variable
GCP_CREDS=$(cat "$KEY_PATH")

# Task 4: Push the credentials to Kestra's Key-Value store via REST API
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  http://localhost:8080/api/v1/namespaces/hcm_pipeline/kv/GCP_CREDS \
  -H "Content-Type: application/json" \
  # Default Kestra credentials — only valid on localhost
  -u "admin@kestra.io:Admin1234!" \
  -d "{\"value\": $(echo $GCP_CREDS | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}")

# Task 5: Verify the HTTP response code to ensure success
echo "HTTP: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "KV store populated: GCP_CREDS is ready."
else
  echo "ERROR: KV store population failed (HTTP $HTTP_CODE)"
  exit 1
fi
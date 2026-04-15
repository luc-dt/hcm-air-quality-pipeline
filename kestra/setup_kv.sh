#!/bin/bash
set -e

KEY_PATH="$(dirname "$0")/../keys/hcm-pipeline-sa.json"

if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: Service account key not found at $KEY_PATH"
  exit 1
fi

GCP_CREDS=$(cat "$KEY_PATH")

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  http://localhost:8080/api/v1/namespaces/hcm_pipeline/kv/GCP_CREDS \
  -H "Content-Type: application/json" \
  -u "admin@kestra.io:Admin1234!" \
  -d "{\"value\": $(echo $GCP_CREDS | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}")

echo "HTTP: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "KV store populated: GCP_CREDS is ready."
else
  echo "ERROR: KV store population failed (HTTP $HTTP_CODE)"
  exit 1
fi
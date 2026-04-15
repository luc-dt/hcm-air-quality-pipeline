#!/bin/bash
# Populates the Kestra KV store with GCP credentials.
# Run this ONCE after `docker compose up -d` and before executing any flows.
#
# Usage: bash kestra/setup_kv.sh

set -e

KEY_PATH="../keys/hcm-pipeline-sa.json"

if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: Service account key not found at $KEY_PATH"
  exit 1
fi

GCP_CREDS=$(cat "$KEY_PATH")

curl -s -o /dev/null -w "%{http_code}" -X PUT \
  http://localhost:8080/api/v1/namespaces/hcm_pipeline/variables/GCP_CREDS \
  -H "Content-Type: application/json" \
  -u "admin@kestra.io:Admin1234!" \
  -d "{\"value\": $(echo $GCP_CREDS | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}"

echo ""
echo "KV store populated: GCP_CREDS is ready."
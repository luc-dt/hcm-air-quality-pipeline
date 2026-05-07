# -------------------------------------------------------------------------
# HCM Air Quality Pipeline - Shortcut Menu
# -------------------------------------------------------------------------

.PHONY: setup tf-init tf-apply kestra-up kestra-down spark-historical spark-hourly dbt-deps dbt-build pipeline

# 1. Environment Setup
setup:
	@echo "Setting up Python environment..."
	python -m venv .venv
	@echo "Please activate your environment: source .venv/bin/activate (Linux/Mac) or .venv\Scripts\activate (Windows)"

# 2. Step 1: Infrastructure (Terraform)
tf-init:
	cd terraform && terraform init

tf-apply:
	cd terraform && terraform apply -auto-approve

# 3. Step 2: Orchestration (Kestra)
kestra-up:
	docker-compose -f kestra/docker-compose.yml up -d

kestra-down:
	docker-compose -f kestra/docker-compose.yml down

# 4. Step 3: Processing (Spark)
spark-historical:
	GOOGLE_APPLICATION_CREDENTIALS=keys/hcm-pipeline-sa.json \
	spark-submit spark/transform_historical.py

spark-hourly:
	GOOGLE_APPLICATION_CREDENTIALS=keys/hcm-pipeline-sa.json \
	DATE=$(DATE) HOUR=$(HOUR) spark-submit spark/transform_hourly.py

# 5. Step 4: Analytics (dbt)
dbt-deps:
	cd dbt/hcm_air_quality && dbt deps

dbt-build:
	cd dbt/hcm_air_quality && dbt build --profiles-dir ~/.dbt

# Run everything (Example)
pipeline: tf-apply kestra-up spark-historical dbt-build

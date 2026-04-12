FROM python:3.11-slim

# Install Java and curl, then clean up in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends default-jre-headless curl && \
    rm -rf /var/lib/apt/lists/*

# Install PySpark — bundles Spark binaries including spark-submit
RUN pip install --no-cache-dir pyspark==3.5.3

# Download the GCS connector fat JAR (shades its own Guava — avoids version conflicts)
RUN mkdir -p /app && curl -L -o /app/gcs-connector.jar \
    https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar

# Bake the transform script into the image
COPY transform_hourly.py /app/transform_hourly.py

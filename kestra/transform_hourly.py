import os
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

BUCKET = "hcm-air-quality-486008"
DATE = os.environ["DATE"]
HOUR = os.environ["HOUR"]
SA_KEY = "/tmp/sa_key.json"

spark = SparkSession.builder \
    .appName("hcm-hourly-silver") \
    .config("spark.driver.extraClassPath", "/app/gcs-connector.jar") \
    .config("spark.hadoop.google.cloud.auth.service.account.enable", "true") \
    .config("spark.hadoop.google.cloud.auth.service.account.json.keyfile", SA_KEY) \
    .config("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem") \
    .config("spark.hadoop.fs.AbstractFileSystem.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFS") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

src = f"gs://{BUCKET}/bronze/hourly/{DATE}/{HOUR}/air_quality.json"
print(f"Reading: {src}")

df = spark.read.option("multiline", "true").json(src)

df = df.select(
    F.col("observed_at").alias("timestamp"),
    F.col("pm10"),
    F.col("pm2_5"),
    F.col("carbon_monoxide"),
    F.col("nitrogen_dioxide"),
    F.col("sulphur_dioxide"),
    F.col("ozone"),
    F.col("us_aqi").cast("double"),
    F.col("european_aqi").cast("double"),
)

df = df.withColumn("date", F.to_date(F.col("timestamp")))
df = df.withColumn("hour", F.hour(F.to_timestamp(F.col("timestamp"))))
df = df.withColumn("ingested_at", F.current_timestamp())

# Data validation before writing to silver
row_count = df.count()
if row_count == 0:
    raise ValueError(f"No data rows for date={DATE}, hour={HOUR} — skipping silver write")

null_aqi_count = df.filter(F.col("us_aqi").isNull()).count()
if null_aqi_count == row_count:
    raise ValueError(f"All us_aqi values are null for date={DATE}, hour={HOUR} — skipping silver write")

print(f"Validation passed: {row_count} rows, {null_aqi_count} null AQI values")

dest = f"gs://{BUCKET}/silver/hourly/"
df.write.mode("append").partitionBy("date").parquet(dest)
print(f"Done — date={DATE}, hour={HOUR}")

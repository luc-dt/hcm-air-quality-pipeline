import os
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

BUCKET = "hcm-air-quality-486008"
SA_KEY = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "keys/hcm-pipeline-sa.json")

spark = SparkSession.builder \
    .appName("hcm-historical-silver") \
    .config("spark.driver.extraClassPath", "jars/gcs-connector.jar") \
    .config("spark.hadoop.google.cloud.auth.service.account.enable", "true") \
    .config("spark.hadoop.google.cloud.auth.service.account.json.keyfile", SA_KEY) \
    .config("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem") \
    .config("spark.hadoop.fs.AbstractFileSystem.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFS") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

src = f"gs://{BUCKET}/bronze/historical/air_quality_historical.csv"
print(f"Reading: {src}")

df = spark.read.option("header", "true").csv(src)

# Fix date format: DD-MM-YY → YYYY-MM-DD
df = df.withColumn(
    "date",
    F.date_format(F.to_date(F.col("date"), "dd-MM-yy"), "yyyy-MM-dd")
)

# Cast all pollutant columns from string to double
numeric_cols = [
    "pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide",
    "sulphur_dioxide", "ozone", "aerosol_optical_depth",
    "dust", "uv_index", "us_aqi", "european_aqi",
]
for col in numeric_cols:
    df = df.withColumn(col, F.col(col).cast("double"))

df = df.withColumn("ingested_at", F.current_timestamp())

# Data validation before writing to silver
row_count = df.count()
if row_count == 0:
    raise ValueError("No rows in historical CSV — skipping silver write")

all_null_count = df.filter(
    F.coalesce(*[F.col(c) for c in numeric_cols]).isNull()
).count()
df = df.dropna(how="all", subset=numeric_cols)
print(f"Validation passed: {row_count} rows, {all_null_count} all-null rows dropped")

dest = f"gs://{BUCKET}/silver/historical/"
df.write.mode("overwrite").parquet(dest)
print(f"Done — {dest}")
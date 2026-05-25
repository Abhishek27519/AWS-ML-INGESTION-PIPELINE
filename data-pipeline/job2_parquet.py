import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'INTERMEDIATE_PATH', 'OUTPUT_PATH'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print(f"Job 2: Loading intermediate clean CSV from {args['INTERMEDIATE_PATH']}")
df = spark.read.option("header", "true").option("inferSchema", "true").csv(args['INTERMEDIATE_PATH'])

# Convert datatypes for optimized storage
refined_df = df.withColumn("temperature", col("temperature").cast("double")) \
    .withColumn("vibration", col("vibration").cast("double")) \
    .withColumn("pressure", col("pressure").cast("double")) \
    .withColumn("timestamp", col("timestamp").cast("long"))

print(f"Job 2: Saving final Parquet files to {args['OUTPUT_PATH']}")
refined_df.write.mode("overwrite").parquet(args['OUTPUT_PATH'])

job.commit()
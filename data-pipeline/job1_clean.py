import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'INPUT_PATH', 'INTERMEDIATE_PATH'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print(f"Job 1: Extracting raw data from {args['INPUT_PATH']}")
df = spark.read.option("header", "true").option("inferSchema", "true").csv(args['INPUT_PATH'])

# Clean: Drop missing status values
cleaned_df = df.filter((col("status").isNotNull()) & (col("status") != ""))

print(f"Job 1: Saving intermediate clean CSV for Job 2 to {args['INTERMEDIATE_PATH']}")
# 1. Save standard clean data for Job 2
cleaned_df.write.mode("overwrite").option("header", "true").csv(args['INTERMEDIATE_PATH'])

print("Job 1: Preparing ML-Ready Feature Dataset for SageMaker")
# 2. Feature Engineering for SageMaker:
# Create a binary label (1 if Temp > 50 else 0), cast features to double, drop string columns
ml_ready_df = cleaned_df.withColumn("label", (col("temperature") > 50).cast("integer")) \
    .withColumn("temperature", col("temperature").cast("double")) \
    .withColumn("vibration", col("vibration").cast("double")) \
    .select("label", "temperature", "vibration")

# Save WITHOUT headers to a dedicated ML directory
# Save WITHOUT headers to a dedicated ML directory (Fixed path formatting)
ml_ready_df.write.mode("overwrite").option("header", "false").csv(args['INTERMEDIATE_PATH'].rstrip('/') + "-sagemaker/")

job.commit()
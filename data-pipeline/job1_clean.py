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

print(f"Job 1: Saving intermediate clean CSV to {args['INTERMEDIATE_PATH']}")
# Save as a temporary clean CSV for Job 2 to pick up
cleaned_df.write.mode("overwrite").option("header", "true").csv(args['INTERMEDIATE_PATH'])

job.commit()
variable "glue_role_arn" {}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "data_ingestion_bucket" {
  bucket        = "ml-ingestion-pipeline-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
  tags = { Name = "ml-ingestion-bucket", Environment = "homework" }
}

resource "aws_glue_catalog_database" "ml_pipeline_db" {
  name        = "ml_pipeline_metadata_db"
  description = "Holds structural schema definitions for raw and cleaned machine learning datasets"
}

resource "aws_glue_crawler" "raw_data_crawler" {
  database_name = aws_glue_catalog_database.ml_pipeline_db.name
  name          = "homework-raw-data-crawler"
  role          = var.glue_role_arn
  s3_target { path = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/raw-uploads/" }
  tags = { Environment = "homework" }
}

resource "aws_s3_object" "upload_job1_script" {
  bucket = aws_s3_bucket.data_ingestion_bucket.id
  key    = "scripts/job1_clean.py"
  source = "${path.root}/../data-pipeline/job1_clean.py"
  etag   = filemd5("${path.root}/../data-pipeline/job1_clean.py")
}

resource "aws_s3_object" "upload_job2_script" {
  bucket = aws_s3_bucket.data_ingestion_bucket.id
  key    = "scripts/job2_parquet.py"
  source = "${path.root}/../data-pipeline/job2_parquet.py"
  etag   = filemd5("${path.root}/../data-pipeline/job2_parquet.py")
}

resource "aws_glue_job" "glue_job_1" {
  name     = "homework-glue-job-1-clean"
  role_arn = var.glue_role_arn
  command {
    script_location = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/${aws_s3_object.upload_job1_script.key}"
    python_version  = "3"
  }
  default_arguments = {
    "--INPUT_PATH"        = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/raw-uploads/"
    "--INTERMEDIATE_PATH" = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/intermediate-clean/"
    "--job-language"      = "python"
  }
}

resource "aws_glue_job" "glue_job_2" {
  name     = "homework-glue-job-2-parquet"
  role_arn = var.glue_role_arn
  command {
    script_location = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/${aws_s3_object.upload_job2_script.key}"
    python_version  = "3"
  }
  default_arguments = {
    "--INTERMEDIATE_PATH" = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/intermediate-clean/"
    "--OUTPUT_PATH"       = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/cleaned-parquet/"
    "--job-language"      = "python"
  }
}

# Outputs for Step Functions
output "bucket_id" { value = aws_s3_bucket.data_ingestion_bucket.id }
output "crawler_name" { value = aws_glue_crawler.raw_data_crawler.name }
output "job1_name" { value = aws_glue_job.glue_job_1.name }
output "job2_name" { value = aws_glue_job.glue_job_2.name }
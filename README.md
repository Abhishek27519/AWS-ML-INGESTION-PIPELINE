# AWS Automated ML Ingestion & Training Pipeline

An end-to-end cloud data engineering and machine learning orchestration pipeline deployed on AWS using Infrastructure as Code (Terraform).

## Architectural Flow
1. **Ingestion:** API Gateway ➔ VPC Link ➔ ALB ➔ EC2 (Spring Boot Backend) ➔ S3 Pre-signed URL.
2. **ETL & Data Cleaning:** AWS Glue (PySpark) cleaning raw data into Parquet format.
3. **Orchestration & ML:** AWS Step Functions managing Glue workflows and triggering AWS SageMaker model training.

## Tech Stack
* **Infrastructure:** Terraform
* **Backend Application:** Java, Spring Boot, AWS SDK
* **Data Processing & ML:** Python, PySpark, AWS Glue, AWS SageMaker, AWS Step Functions
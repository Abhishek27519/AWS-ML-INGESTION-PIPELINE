# Enterprise AWS Machine Learning Ingestion Pipeline

A fully automated, serverless data pipeline and machine learning orchestration workflow built on AWS. This project demonstrates Infrastructure as Code (IaC) principles, PySpark data engineering, and automated ML model deployment using AWS Step Functions as the central orchestrator.

## 🏗️ Architecture Overview

The pipeline executes the following automated steps upon trigger:

1. **Data Cataloging:** An AWS Glue Crawler scans raw sensor data in Amazon S3 and updates the Glue Data Catalog.
2. **Data Cleaning & Feature Engineering (Glue Job 1):**
    * Reads raw CSV data using PySpark.
    * Drops empty or invalid records.
    * Branches the data:
        * Saves standard clean data for downstream analytics.
        * Performs feature engineering (target label creation, dropping string columns) and saves a headerless, purely numerical matrix explicitly formatted for SageMaker.
3. **Data Transformation (Glue Job 2):** Converts the standard clean data into optimized Apache Parquet format for efficient query storage.
4. **Model Training (SageMaker):** * Reads the feature-engineered dataset.
    * Trains a built-in Linear Learner binary classifier model (optimized with custom hyperparameter batch sizing for smaller datasets).
    * Outputs the trained model artifacts (`model.tar.gz`) back to S3.
5. **Real-Time Inference Deployment:** * Registers the model in SageMaker.
    * Creates an Endpoint Configuration.
    * Deploys a live SageMaker Endpoint for real-time, low-latency predictions.

## 🛠️ Technology Stack

* **Cloud Provider:** Amazon Web Services (AWS)
* **Infrastructure as Code:** Terraform
* **Orchestration:** AWS Step Functions
* **Data Engineering:** AWS Glue, Apache Spark (PySpark)
* **Machine Learning:** Amazon SageMaker
* **Storage:** Amazon S3
* **Scripting/Testing:** Python, Boto3

## 📋 Prerequisites

* An active AWS Account.
* [AWS CLI](https://aws.amazon.com/cli/) installed and configured with appropriate IAM credentials (`aws configure`).
* [Terraform](https://www.terraform.io/downloads) installed.
* Python 3.x and `boto3` installed locally for endpoint testing.

## 🚀 Deployment Instructions

### 1. Provision Infrastructure
Navigate to the `infrastructure` directory and deploy the AWS resources:

```bash
cd infrastructure
terraform init
terraform apply
```

*(Type `yes` when prompted to confirm the deployment).*

### 2. Execute the Pipeline
1. Log into the AWS Management Console.
2. Navigate to **Step Functions**.
3. Select the `ml-pipeline-orchestrator` state machine.
4. Click **Start execution** to trigger the end-to-end data processing and model training workflow.

### 3. Test the Live AI Endpoint
Once the Step Function completes successfully and the SageMaker endpoint status is `InService`, navigate to the `data-pipeline` directory to run a real-time prediction:

```bash
cd ../data-pipeline
pip install boto3
python test_endpoint.py
```

## 🧹 Teardown

**CRITICAL:** SageMaker endpoints incur hourly charges. To prevent unwanted AWS billing, completely destroy the infrastructure when you are finished testing.

```bash
cd infrastructure
terraform destroy
```
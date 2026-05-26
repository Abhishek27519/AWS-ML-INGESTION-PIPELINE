terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Create the Custom VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "homework-vpc"
  }
}

# 2. Create an Internet Gateway (Allows our public tier to face the web)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "homework-igw"
  }
}

# 3. Create the Public Subnet (For the Load Balancer / Edge Entryway)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "homework-public-subnet"
  }
}

# 4. Create the Private Subnet (Where your Spring Boot EC2 app lives)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "homework-private-subnet"
  }
}

# 5. Route Table for Public Traffic
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "homework-public-route-table"
  }
}

# Associate Public Route Table to Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Configure NACL on Subnet (Homework Step 4.b)
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private.id]

  # Inbound Rule: Allow traffic from the public subnet (ALB tier) on standard backend ports
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.public_subnet_cidr
    from_port  = 8080
    to_port    = 8080
  }

  # Outbound Rule: Allow response traffic out to the internet or VPC
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  tags = {
    Name = "homework-private-nacl"
  }
}

# 7. Create Security Group for the Spring Boot EC2 Instance (Homework Step 4.c)
resource "aws_security_group" "ec2_sg" {
  name        = "homework-ec2-security-group"
  description = "Control traffic flow entering the Spring Boot application instance"
  vpc_id      = aws_vpc.main.id

  # Inbound traffic rule: Allow port 8080 traffic coming from within the VPC network
  ingress {
    description = "Allow Spring Boot application requests"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Securely limits entry to inside our VPC architecture
  }

  # Outbound traffic rule: Allow the EC2 instance to reach out to the web (e.g., download packages, talk to S3)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols out
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "homework-ec2-sg"
  }
}

# Generate a random string to ensure a globally unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create the S3 Ingestion Bucket (Homework Step 2)
resource "aws_s3_bucket" "data_ingestion_bucket" {
  bucket        = "ml-ingestion-pipeline-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true # Allows terraform destroy to clean it up even if it contains data files later

  tags = {
    Name        = "ml-ingestion-bucket"
    Environment = "homework"
  }
}

# Output the bucket name so we can easily find it for our Spring Boot application
output "s3_bucket_name" {
  value       = aws_s3_bucket.data_ingestion_bucket.id
  description = "The globally unique name of your S3 ingestion bucket"
}

# 10. IAM Role for AWS Glue Execution Service
resource "aws_iam_role" "glue_service_role" {
  name = "homework-glue-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
      }
    ]
  })
}

# Attach standard managed policy so Glue can write logs and access S3 data
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Grant full S3 access to the Glue role so it can crawl your ingestion bucket files
resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 11. Create an AWS Glue Data Catalog Database
resource "aws_glue_catalog_database" "ml_pipeline_db" {
  name        = "ml_pipeline_metadata_db"
  description = "Holds structural schema definitions for raw and cleaned machine learning datasets"
}

# 12. Provision an AWS Glue Crawler to automatically discover CSV Schemas
resource "aws_glue_crawler" "raw_data_crawler" {
  database_name = aws_glue_catalog_database.ml_pipeline_db.name
  name          = "homework-raw-data-crawler"
  role          = aws_iam_role.glue_service_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/raw-uploads/"
  }

  tags = {

    Environment = "homework"
  }
}

# 13. Upload BOTH PySpark ETL scripts to S3
resource "aws_s3_object" "upload_job1_script" {
  bucket = aws_s3_bucket.data_ingestion_bucket.id
  key    = "scripts/job1_clean.py"
  source = "../data-pipeline/job1_clean.py"
  etag   = filemd5("../data-pipeline/job1_clean.py")
}

resource "aws_s3_object" "upload_job2_script" {
  bucket = aws_s3_bucket.data_ingestion_bucket.id
  key    = "scripts/job2_parquet.py"
  source = "../data-pipeline/job2_parquet.py"
  etag   = filemd5("../data-pipeline/job2_parquet.py")
}

# 14. Define both independent Glue Jobs
resource "aws_glue_job" "glue_job_1" {
  name     = "homework-glue-job-1-clean"
  role_arn = aws_iam_role.glue_service_role.arn
  command {
    script_location = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/${aws_s3_object.upload_job1_script.key}"
    python_version  = "3"
  }
  default_arguments = {
    "--INPUT_PATH"         = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/raw-uploads/"
    "--INTERMEDIATE_PATH"  = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/intermediate-clean/"
    "--job-language"       = "python"
  }
}

resource "aws_glue_job" "glue_job_2" {
  name     = "homework-glue-job-2-parquet"
  role_arn = aws_iam_role.glue_service_role.arn
  command {
    script_location = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/${aws_s3_object.upload_job2_script.key}"
    python_version  = "3"
  }
  default_arguments = {
    "--INTERMEDIATE_PATH"  = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/intermediate-clean/"
    "--OUTPUT_PATH"        = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/cleaned-parquet/"
    "--job-language"       = "python"
  }
}

# 15.a IAM Role for AWS Step Functions Orchestration (Kept intact)
resource "aws_iam_role" "states_execution_role" {
  name = "homework-stepfunctions-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "states.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "states_glue_policy" {
  name = "stepfunctions-glue-execution-policy"
  role = aws_iam_role.states_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:StartJobRun",
          "glue:GetJobRun"
        ]
        Resource = "*"
      },
      {
        # Crucial additions to allow Step Functions to monitor synchronous (.sync) jobs
        Effect = "Allow"
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ]
        Resource = [
          "arn:aws:events:*:*:rule/StepFunctionsGetEventsForGlueJobsRule",
          "arn:aws:events:*:*:rule/StepFunctionsGetEventsForSageMakerTrainingJobsRule"
        ]
      }
    ]
  })
}

# 15.b IAM Role for Amazon SageMaker Execution
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "homework-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })
}

# Grant full S3 access to SageMaker so it can pull Parquet training data and save model files
resource "aws_iam_role_policy_attachment" "sagemaker_s3_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Grant standard SageMaker execution privileges
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Allow Step Functions to invoke SageMaker tasks
resource "aws_iam_role_policy" "states_sagemaker_policy" {
  name = "stepfunctions-sagemaker-execution-policy"
  role = aws_iam_role.states_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:CreateEndpoint",
          "sagemaker:AddTags"
        ]
        Resource = "*"
      },
      {
        # Crucial addition: Allow Step Functions to safely pass the SageMaker role to the compute cluster
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.sagemaker_execution_role.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      }
    ]
  })
}

# 16. Define the Complete End-to-End Orchestration Workflow (Glue + SageMaker)
resource "aws_sfn_state_machine" "pipeline_orchestrator" {
  name     = "ml-pipeline-orchestrator"
  role_arn = aws_iam_role.states_execution_role.arn

  definition = jsonencode({
    Comment = "Orchestrates AWS Glue Data Prep and Amazon SageMaker Model Training/Hosting end-to-end"
    StartAt = "TriggerCrawler"
    States = {
      TriggerCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = { Name = aws_glue_crawler.raw_data_crawler.name }
        Next = "WaitForCrawlerToFinish"
      }
      WaitForCrawlerToFinish = {
        Type = "Wait"
        Seconds = 60
        Next    = "TriggerGlueJob1"
      }
      TriggerGlueJob1 = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.glue_job_1.name }
        Next     = "TriggerGlueJob2"
      }
      TriggerGlueJob2 = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = aws_glue_job.glue_job_2.name }
        Next     = "TrainMLModel"
      }
      TrainMLModel = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createTrainingJob.sync"
        Parameters = {
          # 1. Switched to $$.Execution.Name
          "TrainingJobName.$" = "States.Format('sensor-training-job-{}', $$.Execution.Name)"
          AlgorithmSpecification = {
            TrainingImage     = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1"
            TrainingInputMode = "File"
          }
          HyperParameters = {
            predictor_type  = "binary_classifier"
            mini_batch_size = "32"  # Added to prevent crashes on small mock datasets
          }
          InputDataConfig = [{
            ChannelName = "train"
            ContentType = "text/csv"
            DataSource = {
              S3DataSource = {
                S3DataType = "S3Prefix"
                # Pointing exactly to the new headerless numerical branch
                S3Uri      = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/intermediate-clean-sagemaker/"
              }
            }
          }]
          OutputDataConfig = {
            S3OutputPath = "s3://${aws_s3_bucket.data_ingestion_bucket.id}/model-artifacts/"
          }
          ResourceConfig = {
            InstanceCount  = 1
            InstanceType   = "ml.m5.xlarge" # Switched to a standard compute type that usually has a default quota of 1+
            VolumeSizeInGB = 5
          }
          RoleArn = aws_iam_role.sagemaker_execution_role.arn
          StoppingCondition = { MaxRuntimeInSeconds = 3600 }
        }
        Next = "RegisterModelInSageMaker"
      }
      RegisterModelInSageMaker = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createModel"
        Parameters = {
          # 2. Switched to $$.Execution.Name
          "ModelName.$" = "States.Format('sensor-predictive-model-{}', $$.Execution.Name)"
          PrimaryContainer = {
            Image          = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1"
            # 3. Switched to $$.Execution.Name
            "ModelDataUrl.$" = "States.Format('s3://${aws_s3_bucket.data_ingestion_bucket.id}/model-artifacts/sensor-training-job-{}/output/model.tar.gz', $$.Execution.Name)"
          }
          ExecutionRoleArn = aws_iam_role.sagemaker_execution_role.arn
        }
        Next = "CreateEndpointConfig"
      }
      CreateEndpointConfig = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createEndpointConfig"
        Parameters = {
          # 4. Switched to $$.Execution.Name
          "EndpointConfigName.$" = "States.Format('sensor-endpoint-config-{}', $$.Execution.Name)"
          ProductionVariants = [{
            InstanceType         = "ml.t2.medium"
            InitialInstanceCount = 1
            "ModelName.$"        = "States.Format('sensor-predictive-model-{}', $$.Execution.Name)"
            VariantName          = "AllTraffic"
          }]
        }
        Next = "DeploySageMakerEndpoint"
      }
      DeploySageMakerEndpoint = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createEndpoint"
        Parameters = {
          EndpointName           = "sensor-production-endpoint"
          "EndpointConfigName.$" = "States.Format('sensor-endpoint-config-{}', $$.Execution.Name)"
        }
        End = true
      }
    }
  })
}
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

module "networking" {
  source              = "./modules/networking"
  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "security" {
  source = "./modules/security"
}

module "storage_and_etl" {
  source        = "./modules/storage_and_etl"
  glue_role_arn = module.security.glue_role_arn
}

module "orchestration" {
  source             = "./modules/orchestration"
  states_role_arn    = module.security.states_role_arn
  sagemaker_role_arn = module.security.sagemaker_role_arn
  bucket_id          = module.storage_and_etl.bucket_id
  crawler_name       = module.storage_and_etl.crawler_name
  job1_name          = module.storage_and_etl.job1_name
  job2_name          = module.storage_and_etl.job2_name
}

output "s3_bucket_name" {
  value       = module.storage_and_etl.bucket_id
  description = "The globally unique name of your S3 ingestion bucket"
}
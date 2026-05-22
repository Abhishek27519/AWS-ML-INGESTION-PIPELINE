variable "aws_region" {
  type        = string
  description = "The AWS Region to deploy all infrastructure into"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The IP range for our overall custom VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "The IP range for the public web/load balancer tier"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "The IP range for our isolated Spring Boot EC2 instances"
  default     = "10.0.2.0/24"
}
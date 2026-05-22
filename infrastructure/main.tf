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
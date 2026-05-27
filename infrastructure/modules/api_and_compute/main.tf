variable "vpc_id" {}
variable "private_subnet_id" {}
variable "ec2_sg_id" {}

# 1. AWS Cognito (Step 2 - Security)
resource "aws_cognito_user_pool" "user_pool" {
  name = "homework-api-user-pool"
}

resource "aws_cognito_user_pool_client" "app_client" {
  name            = "homework-spring-boot-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = false
}

# 2. EC2 Instance Profile (Allows EC2 to securely talk to S3)
resource "aws_iam_role" "ec2_s3_role" {
  name = "homework-ec2-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "homework-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# 3. EC2 Instance (Step 4 - Compute)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "spring_boot_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  tags = { Name = "homework-spring-boot-server" }
}

# 4. API Gateway & Private VPC Link (Steps 1 & 4 - Secure Routing)
resource "aws_apigatewayv2_api" "api" {
  name          = "homework-ingestion-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  name               = "homework-vpc-link"
  security_group_ids = [var.ec2_sg_id]
  subnet_ids         = [var.private_subnet_id]
}

resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app_client.id]
    issuer   = "https://${aws_cognito_user_pool.user_pool.endpoint}"
  }
}

resource "aws_apigatewayv2_integration" "ec2_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.spring_boot_server.private_ip}:8080/{proxy}"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "POST /upload"
  target             = "integrations/${aws_apigatewayv2_integration.ec2_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}
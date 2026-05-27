# Glue Role
resource "aws_iam_role" "glue_service_role" {
  name = "homework-glue-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "glue.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Step Functions Role
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
        Action = ["glue:StartCrawler", "glue:GetCrawler", "glue:StartJobRun", "glue:GetJobRun"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
        Resource = [
          "arn:aws:events:*:*:rule/StepFunctionsGetEventsForGlueJobsRule",
          "arn:aws:events:*:*:rule/StepFunctionsGetEventsForSageMakerTrainingJobsRule"
        ]
      }
    ]
  })
}

# SageMaker Role
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "homework-sagemaker-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "sagemaker.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_s3_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# SFN to SageMaker Policy
resource "aws_iam_role_policy" "states_sagemaker_policy" {
  name = "stepfunctions-sagemaker-execution-policy"
  role = aws_iam_role.states_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob", "sagemaker:CreateModel", "sagemaker:CreateEndpointConfig", "sagemaker:CreateEndpoint", "sagemaker:AddTags"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.sagemaker_execution_role.arn
        Condition = { StringEquals = { "iam:PassedToService" = "sagemaker.amazonaws.com" } }
      }
    ]
  })
}

# Outputs for other modules
output "glue_role_arn" { value = aws_iam_role.glue_service_role.arn }
output "states_role_arn" { value = aws_iam_role.states_execution_role.arn }
output "sagemaker_role_arn" { value = aws_iam_role.sagemaker_execution_role.arn }
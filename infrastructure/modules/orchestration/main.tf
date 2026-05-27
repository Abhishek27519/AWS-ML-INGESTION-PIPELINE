variable "states_role_arn" {}
variable "sagemaker_role_arn" {}
variable "bucket_id" {}
variable "crawler_name" {}
variable "job1_name" {}
variable "job2_name" {}

resource "aws_sfn_state_machine" "pipeline_orchestrator" {
  name     = "ml-pipeline-orchestrator"
  role_arn = var.states_role_arn

  definition = jsonencode({
    Comment = "Orchestrates AWS Glue Data Prep and Amazon SageMaker Model Training/Hosting end-to-end"
    StartAt = "TriggerCrawler"
    States = {
      TriggerCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = { Name = var.crawler_name }
        Next = "WaitForCrawlerToFinish"
      }
      WaitForCrawlerToFinish = { Type = "Wait", Seconds = 60, Next = "TriggerGlueJob1" }
      TriggerGlueJob1 = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = var.job1_name }
        Next       = "TriggerGlueJob2"
      }
      TriggerGlueJob2 = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = var.job2_name }
        Next       = "TrainMLModel"
      }
      TrainMLModel = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createTrainingJob.sync"
        Parameters = {
          "TrainingJobName.$" = "States.Format('sensor-training-job-{}', $$.Execution.Name)"
          AlgorithmSpecification = { TrainingImage = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1", TrainingInputMode = "File" }
          HyperParameters = { predictor_type = "binary_classifier", mini_batch_size = "32" }
          InputDataConfig = [{
            ChannelName = "train"
            ContentType = "text/csv"
            DataSource = { S3DataSource = { S3DataType = "S3Prefix", S3Uri = "s3://${var.bucket_id}/intermediate-clean-sagemaker/" } }
          }]
          OutputDataConfig = { S3OutputPath = "s3://${var.bucket_id}/model-artifacts/" }
          ResourceConfig = { InstanceCount = 1, InstanceType = "ml.m5.xlarge", VolumeSizeInGB = 5 }
          RoleArn = var.sagemaker_role_arn
          StoppingCondition = { MaxRuntimeInSeconds = 3600 }
        }
        Next = "RegisterModelInSageMaker"
      }
      RegisterModelInSageMaker = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createModel"
        Parameters = {
          "ModelName.$" = "States.Format('sensor-predictive-model-{}', $$.Execution.Name)"
          PrimaryContainer = {
            Image          = "382416733822.dkr.ecr.us-east-1.amazonaws.com/linear-learner:1"
            "ModelDataUrl.$" = "States.Format('s3://${var.bucket_id}/model-artifacts/sensor-training-job-{}/output/model.tar.gz', $$.Execution.Name)"
          }
          ExecutionRoleArn = var.sagemaker_role_arn
        }
        Next = "CreateEndpointConfig"
      }
      CreateEndpointConfig = {
        Type     = "Task"
        Resource = "arn:aws:states:::sagemaker:createEndpointConfig"
        Parameters = {
          "EndpointConfigName.$" = "States.Format('sensor-endpoint-config-{}', $$.Execution.Name)"
          ProductionVariants = [{ InstanceType = "ml.t2.medium", InitialInstanceCount = 1, "ModelName.$" = "States.Format('sensor-predictive-model-{}', $$.Execution.Name)", VariantName = "AllTraffic" }]
        }
        Next = "DeploySageMakerEndpoint"
      }
      DeploySageMakerEndpoint = {
        Type       = "Task"
        Resource   = "arn:aws:states:::sagemaker:createEndpoint"
        Parameters = { EndpointName = "sensor-production-endpoint", "EndpointConfigName.$" = "States.Format('sensor-endpoint-config-{}', $$.Execution.Name)" }
        End        = true
      }
    }
  })
}
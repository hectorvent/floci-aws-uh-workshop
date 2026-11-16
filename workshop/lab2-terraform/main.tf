terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

variable "endpoint" {
  description = "Floci endpoint. Fake credentials below only work here."
  type        = string
  default     = "http://localhost:4566"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3     = var.endpoint
    sqs    = var.endpoint
    lambda = var.endpoint
    iam    = var.endpoint
    sts    = var.endpoint
    logs   = var.endpoint
  }
}

# --- Storage: where files land ---------------------------------------------

resource "aws_s3_bucket" "uploads" {
  bucket        = "uploads"
  force_destroy = true
}

# --- Messaging: S3 tells SQS about every new file --------------------------

resource "aws_sqs_queue" "events" {
  name = "uploads-events"
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.events.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.uploads.arn } }
    }]
  })
}

resource "aws_s3_bucket_notification" "to_queue" {
  bucket = aws_s3_bucket.uploads.id

  queue {
    queue_arn = aws_sqs_queue.events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

# --- Identity: what the Lambda is allowed to do ----------------------------

resource "aws_iam_role" "lambda" {
  name = "process-upload-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "process-upload-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.events.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# --- Compute: code that runs on every message ------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/build/handler.zip"
}

resource "aws_lambda_function" "process_upload" {
  function_name    = "process-upload"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
}

resource "aws_lambda_event_source_mapping" "from_queue" {
  event_source_arn = aws_sqs_queue.events.arn
  function_name    = aws_lambda_function.process_upload.arn
  batch_size       = 1

  depends_on = [aws_iam_role_policy.lambda]
}

output "bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "queue_url" {
  value = aws_sqs_queue.events.id
}

output "function" {
  value = aws_lambda_function.process_upload.function_name
}

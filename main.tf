terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 2.42"
  }
}

locals {
  postman_dir = "${path.module}/lambda/.postman"
}

resource "local_file" "copy_collection_to_lambda_dir" {
  filename = "${local.postman_dir}/${basename(var.postman_collection)}"
  content  = templatefile(var.postman_collection, {})
}

resource "local_file" "copy_environment_to_lambda_dir" {
  filename = "${local.postman_dir}/${basename(var.postman_environment)}"
  content  = templatefile(var.postman_environment, {})
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = "function.zip"
  source_dir  = "${path.module}/lambda"

  depends_on = [local_file.copy_collection_to_lambda_dir, local_file.copy_environment_to_lambda_dir]
}

resource "aws_lambda_function" "test_lambda" {
  filename         = data.archive_file.function_zip.output_path
  function_name    = "${var.app_name}-postman-tests"
  role             = aws_iam_role.test_lambda.arn
  handler          = "src/index.handler"
  runtime          = "nodejs12.x"
  timeout          = 30
  source_code_hash = data.archive_file.function_zip.output_base64sha256
  environment {
    variables = {
      "POSTMAN_COLLECTION"  = ".postman/${basename(local_file.copy_collection_to_lambda_dir.filename)}"
      "POSTMAN_ENVIRONMENT" = ".postman/${basename(local_file.copy_environment_to_lambda_dir.filename)}"
    }
  }
}

resource "aws_iam_role" "test_lambda" {
  name                 = "${var.app_name}-postman-tests"
  permissions_boundary = var.role_permissions_boundary_arn

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "test_lambda" {
  name = "${var.app_name}-postman-tests"
  role = aws_iam_role.test_lambda.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": "codedeploy:PutLifecycleEventHookExecutionStatus",
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

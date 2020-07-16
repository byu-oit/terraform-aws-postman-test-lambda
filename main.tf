terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 2.42"
  }
}

resource "aws_lambda_function" "test_lambda" {
  filename         = "${path.module}/lambda/dist/function.zip"
  function_name    = "${var.app_name}-postman-tests"
  role             = aws_iam_role.test_lambda.arn
  handler          = "src/index.handler"
  runtime          = "nodejs12.x"
  timeout          = 30
  source_code_hash = base64sha256("${path.module}/lambda/dist/function.zip")
  environment {
    variables = {
      "POSTMAN_COLLECTION_NAME"  = var.postman_collection_name
      "POSTMAN_ENVIRONMENT_NAME" = var.postman_environment_name
      "POSTMAN_API_KEY"          = var.postman_api_key
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

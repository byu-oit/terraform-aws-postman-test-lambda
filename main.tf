terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 2.42"
  }
}

data aws_caller_identity "current" {}

resource "aws_s3_bucket" "postman_bucket" {
  bucket = "${var.app_name}-postman-tests-${data.aws_caller_identity.current.account_id}"
  lifecycle_rule {
    id                                     = "AutoAbortFailedMultipartUpload"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 10
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket                  = aws_s3_bucket.postman_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "collection" {
  bucket = aws_s3_bucket.postman_bucket.bucket
  key    = basename(var.postman_collection)
  source = var.postman_collection
}

resource "aws_s3_bucket_object" "environment" {
  bucket = aws_s3_bucket.postman_bucket.bucket
  key    = basename(var.postman_environment)
  source = var.postman_environment
}

resource "aws_iam_policy" "s3_access" {
  name        = "${aws_s3_bucket.postman_bucket.bucket}-access"
  description = "A policy to allow access to s3 to this bucket: ${aws_s3_bucket.postman_bucket.bucket}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.postman_bucket.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "${aws_s3_bucket.postman_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_lambda_function" "test_lambda" {
  filename         = "${path.module}/lambda/dist/function.zip"
  function_name    = "${var.app_name}-postman-tests"
  role             = aws_iam_role.test_lambda.arn
  handler          = "src/index.handler"
  runtime          = "nodejs12.x"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/lambda/dist/function.zip")
  environment {
    variables = {
      "S3_BUCKET"           = aws_s3_bucket.postman_bucket.bucket
      "POSTMAN_COLLECTION"  = aws_s3_bucket_object.collection.key
      "POSTMAN_ENVIRONMENT" = aws_s3_bucket_object.environment.key
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

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.test_lambda.name
  policy_arn = aws_iam_policy.s3_access.arn
}
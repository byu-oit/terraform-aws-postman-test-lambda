terraform {
  required_version = ">= 0.12.16"
  required_providers {
    aws = ">= 3.0.0"
  }
}

locals {
  using_local_files = var.postman_api_key == null
  lambda_env_variables = local.using_local_files ? {
    S3_BUCKET           = aws_s3_bucket.postman_bucket[0].bucket
    POSTMAN_COLLECTION  = aws_s3_bucket_object.collection[0].key
    POSTMAN_ENVIRONMENT = aws_s3_bucket_object.environment[0].key
    } : {
    POSTMAN_COLLECTION_NAME  = var.postman_collection_name
    POSTMAN_ENVIRONMENT_NAME = var.postman_environment_name
    POSTMAN_API_KEY          = var.postman_api_key
  }
  lambda_function_name = "${var.app_name}-postman-tests"
}

# -----------------------------------------------------------------------------
# START OF LOCAL FILES
# Note if user is providing local collection and local environment we need to upload local files to an S3 bucket to be
# pulled down into the function
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "postman_bucket_logs" {
  count = local.using_local_files ? 1 : 0

  bucket = "${var.app_name}-postman-tests-${data.aws_caller_identity.current.account_id}-logs"
  acl    = "log-delivery-write"
  tags   = var.tags

  lifecycle_rule {
    id                                     = "AutoAbortFailedMultipartUpload"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 10

    expiration {
      days                         = 0
      expired_object_delete_marker = false
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket" "postman_bucket" {
  count = local.using_local_files ? 1 : 0

  bucket = var.postman_files_bucket_name != null ? var.postman_files_bucket_name : "${var.app_name}-postman-files"
  logging {
    target_bucket = aws_s3_bucket.postman_bucket_logs[0].id
    target_prefix = "log/"
  }
  lifecycle_rule {
    id                                     = "AutoAbortFailedMultipartUpload"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 10

    expiration {
      days                         = 0
      expired_object_delete_marker = false
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "default" {
  count = local.using_local_files ? 1 : 0

  bucket                  = aws_s3_bucket.postman_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "collection" {
  count = local.using_local_files ? 1 : 0

  bucket = aws_s3_bucket.postman_bucket[0].bucket
  key    = basename(var.postman_collection_file)
  source = var.postman_collection_file
  etag   = filemd5(var.postman_collection_file)
  tags   = var.tags
}

resource "aws_s3_bucket_object" "environment" {
  count = local.using_local_files ? 1 : 0

  bucket = aws_s3_bucket.postman_bucket[0].bucket
  key    = basename(var.postman_environment_file)
  source = var.postman_environment_file
  etag   = filemd5(var.postman_environment_file)
  tags   = var.tags
}

resource "aws_iam_policy" "s3_access" {
  count = local.using_local_files ? 1 : 0

  name        = "${aws_s3_bucket.postman_bucket[0].bucket}-access"
  description = "A policy to allow access to s3 to this bucket: ${aws_s3_bucket.postman_bucket[0].bucket}"

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
        "${aws_s3_bucket.postman_bucket[0].arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "${aws_s3_bucket.postman_bucket[0].arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  count = local.using_local_files ? 1 : 0

  policy_arn = aws_iam_policy.s3_access[0].arn
  role       = aws_iam_role.test_lambda.name
}
# -----------------------------------------------------------------------------
# END OF LOCAL FILES
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# START OF LAMBDA FUNCTION
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "test_lambda" {
  filename         = "${path.module}/lambda/dist/function.zip"
  function_name    = local.lambda_function_name
  role             = aws_iam_role.test_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = var.timeout
  memory_size      = var.memory_size
  source_code_hash = base64sha256("${path.module}/lambda/dist/function.zip")
  environment {
    variables = local.lambda_env_variables
  }
  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
  ]

  vpc_config {
    subnet_ids         = var.lambda_vpc_subnet_ids
    security_group_ids = var.lambda_vpc_subnet_ids != [] ? [aws_security_group.lambda_vpc_sg[0].id] : []
  }
}

resource "aws_iam_role" "test_lambda" {
  name                 = "${var.app_name}-postman-tests"
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags

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

# Role that allows lambda to create vpc config
resource "aws_iam_role_policy" "lambda_vpc_policy" {
  count = var.lambda_vpc_subnet_ids != [] ? 1 : 0

  name = "${var.app_name}-postman-tests-vpc-policy"
  role = aws_iam_role.test_lambda.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
  EOF
}

# A bare minimum security group for doing vpc config.
resource "aws_security_group" "lambda_vpc_sg" {
  count = var.lambda_vpc_subnet_ids != [] ? 1 : 0

  name = "${var.app_name}-postman-tests"
  description = "Bare minimum security group for lambda."
  vpc_id = var.lambda_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}
# -----------------------------------------------------------------------------
# END OF LAMBDA FUNCTION
# -----------------------------------------------------------------------------

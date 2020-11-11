output "lambda_function" {
  value = aws_lambda_function.test_lambda
}

output "lambda_iam_role" {
  value = aws_iam_role.test_lambda
}

output "postman_files_bucket" {
  value = local.using_local_files ? aws_s3_bucket.postman_bucket[0] : null
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.lambda_logs
}

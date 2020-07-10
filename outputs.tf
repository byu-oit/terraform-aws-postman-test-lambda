output "lambda_function" {
  value = aws_lambda_function.test_lambda
}

output "lambda_iam_role" {
  value = aws_iam_role.test_lambda
}

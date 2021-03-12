provider "aws" {
  version = "~> 3.0"
  region  = "us-west-2"
}

data aws_ssm_parameter role_permissions_boundary_arn {
  name = "/acs/iam/iamRolePermissionBoundary"
}

variable "postman_api_key" {
  type = string
}

module "postman_test_lambda" {
  source   = "../../"
  app_name = "postman-api-example"
  postman_collections = [{
    collection  = "1117094-d4bd5a5f-c37c-4fe9-8723-3c3e8b1e2015" # terraform-aws-postman-test-lambda-example collection from postman TF Modules and HW Examples workspace
    environment = "1117094-95627910-aeb0-4aed-b959-7e2034e2f6ce" # terraform-aws-postman-test-lambda-env environment from postman TF Modules and HW Examples workspace
  }]
  postman_api_key               = var.postman_api_key
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

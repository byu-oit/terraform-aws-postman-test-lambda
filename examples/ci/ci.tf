provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

data aws_ssm_parameter role_permissions_boundary_arn {
  name = "/acs/iam/iamRolePermissionBoundary"
}

variable "postman_api_key" {
  type = string
}

module "postman_test_lambda" {
  source                        = "../../"
  app_name                      = "simple-example"
  postman_collection_name       = "terraform-aws-postman-test-lambda-example"
  postman_environment_name      = "terraform-aws-postman-test-lambda-env"
  postman_api_key               = var.postman_api_key
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

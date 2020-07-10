provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

data aws_ssm_parameter role_permissions_boundary_arn {
  name = "/acs/iam/iamRolePermissionBoundary"
}

module "postman_test_lambda" {
  source = "../../"
  app_name = "postman-test-lambda-ci-example"
  postman_collection = "test_collection.json"
  postman_environment = "test_environment.json"
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

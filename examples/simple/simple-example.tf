provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

data aws_ssm_parameter role_permissions_boundary_arn {
  name = "/acs/iam/iamRolePermissionBoundary"
}

module "postman_test_lambda" {
  source                        = "../../"
  app_name                      = "simple-example"
  postman_collection_file       = "terraform-aws-postman-test-lambda-example.postman_collection.json"
  postman_environment_file      = "terraform-aws-postman-test-lambda-env.postman_environment.json"
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

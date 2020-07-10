provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

data aws_ssm_parameter role_permissions_boundary_arn {
  name = "/acs/iam/iamRolePermissionBoundary"
}

module "postman_test_lambda" {
  //  source = "github.com/byu-oit/terraform-aws-<module_name>?ref=v1.0.0"
  source = "../../" # for local testing during module development
  app_name = "simple-example"
  postman_collection = "test_collection.json"
  postman_environment = "test_environment.json"
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

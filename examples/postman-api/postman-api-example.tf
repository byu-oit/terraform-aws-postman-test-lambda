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
  source                        = "../../"
  app_name                      = "postman-api-example"
  postman_collections = [{
    collection = "10321111-fc485922-7348-4c84-afcf-68a72362d12e"
    environment = "10321111-18fc41dc-086c-4bc6-bf54-9d4c5f40608a"
  }]
  postman_api_key               = var.postman_api_key
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

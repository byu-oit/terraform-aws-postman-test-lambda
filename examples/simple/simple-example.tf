terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_ssm_parameter" "role_permissions_boundary_arn" {
  name = "/acs/iam/iamRolePermissionBoundary"
}

module "postman_test_lambda" {
  source   = "../../"
  app_name = "simple-example"
  postman_collections = [
    {
      collection  = "terraform-aws-postman-test-lambda-example.postman_collection.json"
      environment = null
    }
  ]
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}

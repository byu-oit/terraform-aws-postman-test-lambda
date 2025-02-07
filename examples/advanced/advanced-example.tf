terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

variable "postman_api_key" {
  type = string
}

data "aws_ssm_parameter" "role_permissions_boundary_arn" {
  name = "/acs/iam/iamRolePermissionBoundary"
}
data "aws_ssm_parameter" "vpc_name" {
  name = "/acs/vpc/vpc-name"
}
data "aws_ssm_parameter" "vpc_id" {
  name = "/acs/vpc/${data.aws_ssm_parameter.vpc_name.value}"
}
data "aws_ssm_parameter" "subnet_id" {
  name = "/acs/vpc/${data.aws_ssm_parameter.vpc_name.value}-private-a"
}

module "postman_test_lambda" {
  source   = "../../"
  app_name = "advanced-example"
  postman_collections = [
    {
      collection  = "1117094-d4bd5a5f-c37c-4fe9-8723-3c3e8b1e2015" # terraform-aws-postman-test-lambda-example collection from postman TF Modules and HW Examples workspace
      environment = "1117094-95627910-aeb0-4aed-b959-7e2034e2f6ce" # terraform-aws-postman-test-lambda-env environment from postman TF Modules and HW Examples workspace
    },
    {
      collection  = "terraform-aws-postman-test-lambda-example.postman_collection.json"
      environment = "terraform-aws-postman-test-lambda-env.postman_environment.json"
    }
  ]
  postman_api_key               = var.postman_api_key
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
  vpc_id                        = data.aws_ssm_parameter.vpc_id.value
  vpc_subnet_ids                = [data.aws_ssm_parameter.subnet_id.value]
  memory_size                   = 528
  timeout                       = 120
  test_env_var_overrides = {
    foo = "boo"
  }
}

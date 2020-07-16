![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-postman-test-lambda?sort=semver)

# Terraform AWS Postman Test Lambda
Terraform module that creates a generic lambda function that runs newman tests against a postman collection.

This lambda function is intended for use with [CodeDeploy's lifecycle hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html).
This lambda function will attempt to run the [newman](https://www.npmjs.com/package/newman) CLI to run your Postman collection as a test.
This lambda function will tell CodeDeploy if the tests pass or fail.

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage
```hcl
module "postman_test_lambda" {
  source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v0.1.0"
    app_name                      = "simple-example"
    postman_collection_name       = "terraform-aws-postman-test-lambda-example"
    postman_environment_name      = "terraform-aws-postman-test-lambda-env"
    postman_api_key               = var.postman_api_key
    role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}
```

Then add your lambda function_name to the CodeDeploy lifecycle hook you want the postman tests to run on.
For instance, if you're using the [fargate-api module](https://github.com/byu-oit/terraform-aws-fargate-api):
```hcl
# ... postman-test-lambda module

module "fargate_api" {
  source = "github.com/byu-oit/terraform-aws-fargate-api?ref=" # latest version
  # .. all other variables
  codedeploy_lifecycle_hooks = {
    BeforeInstall         = null
    AfterInstall          = null
    AfterAllowTestTraffic = module.postman_test_lambda.lambda_function.function_name
    BeforeAllowTraffic    = null
    AfterAllowTraffic     = null
  }
}
```
Or if you're using the [lambda-api module](https://github.com/byu-oit/terraform-aws-lambda-api):
```hcl
# ... postman-test-lambda module

module "lambda_api" {
  source = "github.com/byu-oit/terraform-aws-lambda-api?ref=" # latest version
  # .. all other variables
  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = module.postman_test_lambda.lambda_function.function_name
    AfterAllowTraffic  = null
  }
}
```

## Requirements
* Terraform version 0.12.16 or greater

## Inputs
| Name | Type  | Description | Default |
| --- | --- | --- | --- |
| app_name | string | Application name to name your postman test lambda function | |
| postman_collection_name | string | Name of Postman collection to download from Postman API | | 
| postman_environment_name | string | Name of Postman environment to download from Postman API | |
| postman_api_key | string | postman API key to download collection and environment from Postman API | |
| role_permissions_boundary_arn | string | ARN of the IAM Role permissions boundary to place on each IAM role created | |

## Outputs
| Name | Type | Description |
| ---  | ---  | --- |
| lambda_function | [object](https://www.terraform.io/docs/providers/aws/r/lambda_function.html#attributes-reference) | Created lambda function that runs newman to test the `postman_collection` |
| lambda_iam_role | [object](https://www.terraform.io/docs/providers/aws/r/iam_role.html#attributes-reference) | Created IAM role for the `lambda_function` |

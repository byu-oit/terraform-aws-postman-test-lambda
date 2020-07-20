![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-postman-test-lambda?sort=semver)

# Terraform AWS Postman Test Lambda
Terraform module that creates a generic lambda function that runs newman tests against a postman collection.

This lambda function is intended for use with [CodeDeploy's lifecycle hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html).
This lambda function will attempt to run the [newman](https://www.npmjs.com/package/newman) CLI to run your Postman collection as a test.
This lambda function will tell CodeDeploy if the tests pass or fail.

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage
You can provide a postman collection and environment to be tested in one of two ways:
1. Provided in your github repo
    ```hcl
    module "postman_test_lambda" {
      source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v.0.2.0"
        app_name                      = "simple-example"
        postman_collection_file       = "terraform-aws-postman-test-lambda-example.postman_collection.json"
        postman_environment_file      = "terraform-aws-postman-test-lambda-env.postman_environment.json"
        role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
    }
    ```
2. Or from the Postman API
    ```hcl
    module "postman_test_lambda" {
      source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v.0.2.0"
        app_name                      = "simple-example"
        postman_collection_name       = "terraform-aws-postman-test-lambda-example"
        postman_environment_name      = "terraform-aws-postman-test-lambda-env"
        postman_api_key               = var.postman_api_key
        role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
    }
    ```
   Using this method allows you to not have to export your collection and commit the JSON file to your repo.
   
   **Note:** The postman collection/environment must be viewable by the postman account tied to the API key you provide.
   
   **DON'T** hard code your postman API key, treat it like all other secrets.

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
| postman_collection_file | string | Path to the postman collection JSON file relative from terraform dir (must be provided with postman_environment_file) | null |
| postman_environment_file | string | Path to the postman environment JSON file relative from terraform dir (must be provided with postman_collection_file) | null |
| postman_collection_name | string | Name of Postman collection to download from Postman API  (must be provided with postman_api_key and postman_environment_name) | null | 
| postman_environment_name | string | Name of Postman environment to download from Postman API  (must be provided with postman_api_key and postman_collection_name) | null |
| postman_api_key | string | postman API key to download collection and environment from Postman API (must be provided with postman_collection_name and postman_environment_name) | null |
| role_permissions_boundary_arn | string | ARN of the IAM Role permissions boundary to place on each IAM role created | |
| tags | map(string) | A map of AWS Tags to attach to each resource created | {} |

## Outputs
| Name | Type | Description |
| ---  | ---  | --- |
| lambda_function | [object](https://www.terraform.io/docs/providers/aws/r/lambda_function.html#attributes-reference) | Created lambda function that runs newman to test the `postman_collection` |
| lambda_iam_role | [object](https://www.terraform.io/docs/providers/aws/r/iam_role.html#attributes-reference) | Created IAM role for the `lambda_function` |

## Contributing
To contribute to this terraform module make a feature branch and create a Pull Request to the `master` branch.

This terraform module bakes in the lambda function code in the committed [function.zip](lambda/dist/function.zip) file.

If you change the javascript in [index.js](lambda/src/index.js) then you'll need to run `npm run package` and commit the [function.zip](lambda/dist/function.zip) file.
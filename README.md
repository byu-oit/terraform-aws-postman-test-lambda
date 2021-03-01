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
      source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v2.4.1"
        app_name                      = "simple-example"
        postman_collection_file       = "terraform-aws-postman-test-lambda-example.postman_collection.json"
        postman_environment_file      = "terraform-aws-postman-test-lambda-env.postman_environment.json"
        role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
    }
    ```
2. Or from the Postman API
    ```hcl
    module "postman_test_lambda" {
      source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v2.4.1"
        app_name                      = "simple-example"
        postman_collection_name       = "terraform-aws-postman-test-lambda-example"
        postman_environment_name      = "terraform-aws-postman-test-lambda-env"
        postman_api_key               = var.postman_api_key
        role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
    }
    ```
   Using this method allows you to not have to export your collection and commit the JSON file to your repo.
   
   **Note:** The postman collection/environment must be viewable by the postman account tied to the API key you provide.
   
   **Note 2:** Make sure your postman collection/environment names are unique, otherwise you will get an error if the postman API finds more than 1 collection/environment with the same name.
   
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
| Name                          | Type        | Description                                                                                                                                          | Default |
| ----------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| app_name                      | string      | Application name to prefix your postman test lambda function's name                                                                                  |         |
| postman_collection_file       | string      | Path to the postman collection JSON file relative from terraform dir (must be provided with postman_environment_file)                                | null    |
| postman_environment_file      | string      | Path to the postman environment JSON file relative from terraform dir (must be provided with postman_collection_file)                                | null    |
| postman_files_bucket_name     | string      | S3 Bucket name for the S3 Bucket this module will upload the postman_collection_file and postman_environment_file to                                 | <app_name>-postman-files    |
| postman_collection_name       | string      | Name of Postman collection to download from Postman API  (must be provided with postman_api_key and postman_environment_name)                        | null    |
| postman_environment_name      | string      | Name of Postman environment to download from Postman API  (must be provided with postman_api_key and postman_collection_name)                        | null    |
| postman_api_key               | string      | postman API key to download collection and environment from Postman API (must be provided with postman_collection_name and postman_environment_name) | null    |
| role_permissions_boundary_arn | string      | ARN of the IAM Role permissions boundary to place on each IAM role created                                                                           |         |
| log_retention_in_days         | number      | CloudWatch log group retention in days                                                                                                               | 7       |
| tags                          | map(string) | A map of AWS Tags to attach to each resource created                                                                                                 | {}      |
| timeout                       | number      | The max number of seconds the lambda will run for without stopping.                                                | 30      |
| memory_size                   | number      | The size of the memory of the lambda                                                                               | 128     |

## Outputs
| Name            | Type                                                                                              | Description                                                               |
| --------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| lambda_function | [object](https://www.terraform.io/docs/providers/aws/r/lambda_function.html#attributes-reference) | Created lambda function that runs newman to test the `postman_collection` |
| lambda_iam_role | [object](https://www.terraform.io/docs/providers/aws/r/iam_role.html#attributes-reference)        | Created IAM role for the `lambda_function`                                |
| postman_files_bucket | [object](https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#attributes-reference)  | Created S3 Bucket where local postman files are uploaded                  |
| cloudwatch_log_group | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#attributes-reference)  | Created CloudWatch Log Group for the postman lambda logs       |

## Contributing
To contribute to this terraform module make a feature branch and create a Pull Request to the `master` branch.

This terraform module bakes in the lambda function code in the committed [function.zip](lambda/dist/function.zip) file.

If you change the [index.js](lambda/src/index.js) file then you'll need to run `npm run package` and commit the [function.zip](lambda/dist/function.zip) file.

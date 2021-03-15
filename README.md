![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-postman-test-lambda?sort=semver)

# Terraform AWS Postman Test Lambda

Terraform module that creates a generic lambda function that runs newman tests against a postman collection.

This lambda function is intended for use
with [CodeDeploy's lifecycle hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html)
. This lambda function will attempt to run the [newman](https://www.npmjs.com/package/newman) CLI to run your Postman
collection as a test. This lambda function will tell CodeDeploy if the tests pass or fail.

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage

```hcl
module "postman_test_lambda" {
  source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v3.0.0"
  app_name = "simple-example"
  postman_collections = [
    {
      collection = "terraform-aws-postman-test-lambda-example.postman_collection.json"
      environment = "terraform-aws-postman-test-lambda-env.postman_environment.json"
    }
  ]
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}
```

You can specify multiple collections and environments to run in the lambda function. The function will run the
collections in order.

You can run collections/environments from local json files or using the [Postman API](#using-the-postman-api).

**Note:** When [using the Postman API](#using-the-postman-api): the postman collections/environments must be viewable by
the postman account tied to the API key you provide.

**DON'T** hard code your postman API key, treat it like all other secrets.

Then add your lambda function_name to the CodeDeploy lifecycle hook you want the postman tests to run on. For instance,
if you're using the [fargate-api module](https://github.com/byu-oit/terraform-aws-fargate-api):

```hcl
# ... postman-test-lambda module

module "fargate_api" {
  source = "github.com/byu-oit/terraform-aws-fargate-api?ref="
  # latest version
  # .. all other variables
  codedeploy_lifecycle_hooks = {
    BeforeInstall = null
    AfterInstall = null
    AfterAllowTestTraffic = module.postman_test_lambda.lambda_function.function_name
    BeforeAllowTraffic = null
    AfterAllowTraffic = null
  }
}
```

Or if you're using the [lambda-api module](https://github.com/byu-oit/terraform-aws-lambda-api):

```hcl
# ... postman-test-lambda module

module "lambda_api" {
  source = "github.com/byu-oit/terraform-aws-lambda-api?ref="
  # latest version
  # .. all other variables
  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = module.postman_test_lambda.lambda_function.function_name
    AfterAllowTraffic = null
  }
}
```

### Using the Postman API

If you don't want to export your postman collections/environments into json files in order to run tests you can use the
Postman API. Using the Postman API allows you to keep your postman collections/environments in Postman and not have to
worry about keeping json files up to date.

In order to use the Postman API to retrieve the collections/environments you will need to provide the `postman_api_key`.
You can [generate an API key](https://learning.postman.com/docs/developer/intro-api/) from a Postman account.
**PLEASE DON'T** hardcode the api key into your github repo.

Provide the collection and environment IDs instead of the name of each. You can find the ID on the v8 Postman Client by
selecting your collection/environment and clicking on the info icon.

```hcl
module "postman_test_lambda" {
  source = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v3.0.0"
  app_name = "from-postman-api-example"
  postman_collections = [
    {
      collection  = "1117094-d4bd5a5f-c37c-4fe9-8723-3c3e8b1e2015" # terraform-aws-postman-test-lambda-example collection from postman TF Modules and HW Examples workspace
      environment = "1117094-95627910-aeb0-4aed-b959-7e2034e2f6ce" # terraform-aws-postman-test-lambda-env environment from postman TF Modules and HW Examples workspace
    }
  ]
  postman_api_key               = var.postman_api_key
  role_permissions_boundary_arn = data.aws_ssm_parameter.role_permissions_boundary_arn.value
}
```

## Requirements

* Terraform version 0.12.16 or greater
* _Postman JSON collections/environments files (optional)_ if you want export them to JSON files and include them in your project repo
* _Postman API (optional)_ if you want to download Postman collections/environments from Postman instead of providing the json files in your repo

## Inputs

| Name                          | Type        | Description                                                                                                                                          | Default |
| ----------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| app_name                      | string      | Application name to prefix your postman test lambda function's name                                                                                  |         |
| postman_collections           | list([object](#postman_collection))| List of postman collections and environments. See [postman_collection](#postman_collection)                                   |         |
| postman_api_key               | string      | Postman API key to download collections/environments from Postman API (must be provided if you provide any postman IDs in `postman_collection` variable) | null    |
| role_permissions_boundary_arn | string      | ARN of the IAM Role permissions boundary to place on each IAM role created                                                                           |         |
| log_retention_in_days         | number      | CloudWatch log group retention in days                                                                                                               | 7       |
| tags                          | map(string) | A map of AWS Tags to attach to each resource created                                                                                                 | {}      |
| timeout                       | number      | The max number of seconds the lambda will run for without stopping.                                                | 30      |
| memory_size                   | number      | The size of the memory of the lambda                                                                               | 128     |

### postman_collection
Object defining the collection and environment to run.
* **`collection`** - (Required) path to local collection json file or Postman collection ID
* **`environment`** - (Optional) path to local environment json file or Postman environment ID (can be set to `null` if you don't want an environment on your postman collection)

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

If you change the [index.js](lambda/src/index.js) file then you'll need to run `npm run package` and commit
the [function.zip](lambda/dist/function.zip) file.

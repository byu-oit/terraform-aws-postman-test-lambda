![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-<module_name>?sort=semver)

# Terraform Module Template
GitHub template to quickly create Terraform modules

## To Use Template
1. Click the "Use this template" button 
2. Name your terraform module repo as `terraform-aws-<module_name>` (if creating non-AWS module change `aws` to the cloud provider)
3. Rename this README's title to the title you named your repo in #2
4. Update the shield badge URL to match the module's repo at the top of this README
5. Update this README to match the module's title (in the usage section)
6. Update `example/example.tf` to match the module's title
7. Remove [this section](#to-use-template) from the README

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage
```hcl
module "<module_name>" {
  source = "github.com/byu-oit/terraform-aws-<module_name>?ref=v1.0.0"
}
```

## Requirements
* Terraform version 0.12.16 or greater

## Inputs
| Name | Type  | Description | Default |
| --- | --- | --- | --- |
| | | | |

## Outputs
| Name | Type | Description |
| ---  | ---  | --- |
| | | |

variable "alb_wait_time" {
  type        = number
  description = "The number of seconds the Lambda function should wait for the new ALB target group to initialize before running tests."
  default     = 10
}

variable "app_name" {
  type        = string
  description = "Application name to name your postman test lambda function"
}

variable "postman_collections" {
  type = list(object({
    collection  = string
    environment = string
  }))
  description = "A list of postman collections (and environments) to run during the execution of the lambda function (in order). Collections and environments from the Postman API must be the collection/environment id"
}

variable "postman_files_bucket_name" {
  type        = string
  description = "S3 Bucket name for the S3 Bucket this module will upload the postman_collection_file and postman_environment_file to (defaults to <app_name>-postman-files)"
  default     = null
}

variable "postman_api_key" {
  type        = string
  description = "Postman API key to pull collection and environment from Postman's API (must be provided with postman_collection_name and postman_environment_name)"
  default     = null
}

variable "role_permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM Role permissions boundary to place on each IAM role created."
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log group retention in days. Defaults to 7."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "A map of AWS Tags to attach to each resource created"
  default     = {}
}

variable "memory_size" {
  type        = number
  description = "the size of memory for the lambda"
  default     = 128
}

variable "timeout" {
  type        = number
  description = "the amount of time the lambda is allowed to run for"
  default     = 30
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "Subnet ids that the lambda should be in."
  default     = []
}

variable "vpc_id" {
  type        = string
  description = "ID for the lambda's VPC"
  default     = null
}

variable "test_env_var_overrides" {
  type        = map(string)
  description = "Values to set or override in the Postman test environment."
  default     = {}
}
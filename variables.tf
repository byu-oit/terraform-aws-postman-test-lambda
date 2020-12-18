variable "app_name" {
  type        = string
  description = "Application name to name your postman test lambda function"
}

variable "postman_collection_file" {
  type        = string
  description = "Path to the postman collection JSON file relative from terraform dir (must be provided with postman_environment_file) "
  default     = null
}

variable "postman_environment_file" {
  type        = string
  description = "Path to the postman environment JSON file relative from terraform dir (must be provided with postman_collection_file) "
  default     = null
}

variable "postman_files_bucket_name" {
  type        = string
  description = "S3 Bucket name for the S3 Bucket this module will upload the postman_collection_file and postman_environment_file to (defaults to <app_name>-postman-files)"
  default     = null
}

variable "postman_collection_name" {
  type        = string
  description = "Name of Postman collection to download from Postman API (must be provided with postman_api_key and postman_environment_name)"
  default     = null
}

variable "postman_environment_name" {
  type        = string
  description = "Name of the postman environment to download from Postman's API (must be provided with postman_api_key and postman_collection_name)"
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

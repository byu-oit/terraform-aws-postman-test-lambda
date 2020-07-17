variable "app_name" {
  type        = string
  description = "Application name to name your postman test lambda function"
}

variable "postman_collection_file" {
  type        = string
  description = "Postman collection JSON file to test"
  default     = null
}

variable "postman_environment_file" {
  type        = string
  description = "Postman environment JSON file to use during test"
  default     = null
}

variable "postman_collection_name" {
  type        = string
  description = "Name of Postman collection to download from Postman API"
  default     = null
}

variable "postman_environment_name" {
  type        = string
  description = "Name of the postman environment to download from Postman's API"
  default     = null
}

variable "postman_api_key" {
  type        = string
  description = "Postman API key to pull collection and environment from Postman's API"
  default     = null
}

variable "role_permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM Role permissions boundary to place on each IAM role created."
}

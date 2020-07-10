variable "app_name" {
  type        = string
  description = "Application name to name your postman test lambda function"
}

variable "postman_collection" {
  type        = string
  description = "Postman collection JSON file to test"
}

variable "postman_environment" {
  type        = string
  description = "Postman environment JSON file to use during test"
}

variable "role_permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM Role permissions boundary to place on each IAM role created."
}
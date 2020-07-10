variable "app_name" {
  type = string
}

variable "postman_collection" {
  description = "Postman collection JSON file"
  type = string
}

variable "postman_environment" {
  description = "Postman environment JSON file"
  type = string
}

variable "role_permissions_boundary_arn" {
  type = string
}
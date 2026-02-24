variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the secret to grant access to"
  type        = string
}

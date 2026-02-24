variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "jenkins_instance_id" {
  description = "Jenkins instance ID"
  type        = string
}

variable "app_instance_id" {
  description = "App server instance ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

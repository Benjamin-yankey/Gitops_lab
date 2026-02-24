variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  type        = string
}

variable "app_instance_id" {
  description = "App server EC2 instance ID (legacy, may be empty string if using ECS)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "enable_ec2_app_alarm" {
  description = "Whether to create the EC2 app CPU alarm (disable when using ECS)"
  type        = bool
  default     = true
}

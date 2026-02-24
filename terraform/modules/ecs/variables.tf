variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS task (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory (MiB) for the ECS task"
  type        = string
  default     = "512"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 5000
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "ecr_repository_url" {
  description = "Full ECR repository URL for the initial task definition image"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ECS security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "app_allowed_ips" {
  description = "CIDR blocks allowed to reach the container port"
  type        = list(string)
}

variable "log_group_name" {
  description = "CloudWatch log group name for ECS container logs"
  type        = string
  default     = "/ecs/cicd-node-app"
}

variable "log_retention_days" {
  description = "Number of days to retain ECS container logs"
  type        = number
  default     = 30
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

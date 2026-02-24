variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret to grant access to"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository for Jenkins push/pull permissions"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role (Jenkins needs iam:PassRole on this)"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role (Jenkins needs iam:PassRole on this)"
  type        = string
}

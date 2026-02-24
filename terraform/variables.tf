# ─────────────────────────────────────────────────────────────
# Core Configuration
# ─────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cicd-pipeline"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# ─────────────────────────────────────────────────────────────
# Network Configuration
# ─────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ─────────────────────────────────────────────────────────────
# Access Control
# ─────────────────────────────────────────────────────────────
variable "allowed_ips" {
  description = "List of allowed IP addresses for SSH and Jenkins access. MUST be set to specific IPs (e.g., YOUR_IP/32)"
  type        = list(string)

  validation {
    condition     = length(var.allowed_ips) > 0 && !contains(var.allowed_ips, "0.0.0.0/0")
    error_message = "allowed_ips cannot be 0.0.0.0/0. Specify your IP address (e.g., YOUR_IP/32) for security."
  }
}

variable "app_allowed_ips" {
  description = "List of allowed IP addresses for application port 5000. Use specific IPs or load balancer security group"
  type        = list(string)

  validation {
    condition     = length(var.app_allowed_ips) > 0 && !contains(var.app_allowed_ips, "0.0.0.0/0")
    error_message = "app_allowed_ips cannot be 0.0.0.0/0. Specify trusted IPs or use a load balancer."
  }
}

# ─────────────────────────────────────────────────────────────
# EC2 Configuration (Jenkins + Legacy App Server)
# ─────────────────────────────────────────────────────────────
variable "jenkins_volume_size" {
  description = "Root volume size for Jenkins instance in GB"
  type        = number
  default     = 20
}

variable "app_volume_size" {
  description = "Root volume size for application instance in GB"
  type        = number
  default     = 20
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "Instance type for application server"
  type        = string
  default     = "t3.micro"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Name for EC2 key pair that Terraform will generate locally and create in AWS."
  type        = string

  validation {
    condition     = length(var.key_name) > 0
    error_message = "key_name must be set (Terraform will create this key pair name in AWS)."
  }
}

# ─────────────────────────────────────────────────────────────
# ECR Configuration (Container Registry)
# ─────────────────────────────────────────────────────────────
variable "ecr_repository_name" {
  description = "Name of the ECR repository for storing app Docker images"
  type        = string
  default     = "cicd-node-app"
}

variable "ecr_max_image_count" {
  description = "Maximum number of tagged images to retain in ECR before lifecycle cleanup"
  type        = number
  default     = 20
}

# ─────────────────────────────────────────────────────────────
# ECS Configuration (Container Orchestration)
# ─────────────────────────────────────────────────────────────
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "cicd-node-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "cicd-node-service"
}

variable "ecs_task_family" {
  description = "ECS task definition family name"
  type        = string
  default     = "cicd-node-app"
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS Fargate task (256 = 0.25 vCPU, 512 = 0.5 vCPU)"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Memory in MiB for ECS Fargate task"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "Number of ECS task instances to run"
  type        = number
  default     = 1
}

variable "ecs_log_group_name" {
  description = "CloudWatch log group name for ECS container logs"
  type        = string
  default     = "/ecs/cicd-node-app"
}

variable "ecs_log_retention_days" {
  description = "Number of days to retain ECS container logs in CloudWatch"
  type        = number
  default     = 30
}

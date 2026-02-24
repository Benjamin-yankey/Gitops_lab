variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
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
  description = "Name of existing EC2 key pair in AWS. Do not generate keys via Terraform."
  type        = string

  validation {
    condition     = length(var.key_name) > 0
    error_message = "key_name must be set to an existing EC2 key pair name in your AWS account."
  }
}

# Terraform Variables Configuration
# Copy this file to terraform.tfvars and update with your values

# AWS Configuration
aws_region = "eu-central-1"  # Change to your preferred region

# Project Configuration
project_name = "cicd-pipeline"
environment = "dev"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

# Security Configuration
# IMPORTANT: Replace with your actual IP address for security
# Get your IP: curl ifconfig.me
allowed_ips = ["196.61.44.164/32"]  # SSH and Jenkins access
app_allowed_ips = ["196.61.44.164/32"]  # Application port 5000 access

# EC2 Configuration
# IMPORTANT: This must be an existing key pair in your AWS account
key_name = "cicd-pipeline-keypair"  # Created via AWS CLI or Console

# Instance Types (adjust based on your needs and budget)
jenkins_instance_type = "t3.micro"  # Recommended for Jenkins
app_instance_type = "t3.micro"       # Sufficient for demo app

# Jenkins Configuration
# IMPORTANT: Use a strong password
jenkins_admin_password = "YourSecurePassword123!"

# Optional: Uncomment and modify if needed
# vpc_cidr = "172.16.0.0/16"  # Alternative VPC CIDR
# jenkins_instance_type = "t3.large"  # For heavy Jenkins usage
# app_instance_type = "t3.medium"     # For production workloads

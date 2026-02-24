# ═══════════════════════════════════════════════════════════════
# Terraform Variables - YOUR ACTUAL VALUES
# ═══════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
# AWS Configuration
# ─────────────────────────────────────────────────────────────
aws_region = "eu-central-1"

# ─────────────────────────────────────────────────────────────
# Project Configuration
# ─────────────────────────────────────────────────────────────
project_name = "cicd-pipeline"
environment  = "dev"

# ─────────────────────────────────────────────────────────────
# Network Configuration
# ─────────────────────────────────────────────────────────────
vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

# ─────────────────────────────────────────────────────────────
# Security Configuration
# ─────────────────────────────────────────────────────────────
allowed_ips     = ["196.61.44.164/32"]
app_allowed_ips = ["196.61.44.164/32"]

# ─────────────────────────────────────────────────────────────
# EC2 Configuration
# ─────────────────────────────────────────────────────────────
key_name              = "cicd-pipeline-dev-keypair2"
jenkins_instance_type = "t3.micro"
app_instance_type     = "t3.micro"
jenkins_volume_size   = 20
app_volume_size       = 20

# ─────────────────────────────────────────────────────────────
# Jenkins Configuration
# ─────────────────────────────────────────────────────────────
jenkins_admin_password = "YourSecurePassword123!"

# ─────────────────────────────────────────────────────────────
# ECR Configuration (Container Registry)
# ─────────────────────────────────────────────────────────────
ecr_repository_name = "cicd-node-app"
ecr_max_image_count = 20

# ─────────────────────────────────────────────────────────────
# ECS Configuration (Container Orchestration)
# ─────────────────────────────────────────────────────────────
ecs_cluster_name       = "cicd-node-cluster"
ecs_service_name       = "cicd-node-service"
ecs_task_family        = "cicd-node-app"
ecs_task_cpu           = "256"
ecs_task_memory        = "512"
ecs_desired_count      = 1
ecs_log_group_name     = "/ecs/cicd-node-app"
ecs_log_retention_days = 30

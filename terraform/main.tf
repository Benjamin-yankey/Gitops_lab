# Terraform configuration for provisioning a secure CI/CD infrastructure on AWS
# Includes: VPC, Jenkins EC2, ECR, ECS Fargate, IAM, CloudWatch, and monitoring
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider with region and default tags for all resources
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources to fetch available AWS infrastructure information
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ─────────────────────────────────────────────────────────────
# Networking Layer: VPC, Subnets, Route Tables
# ─────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
}

# ─────────────────────────────────────────────────────────────
# EC2 Authentication: SSH Key Pair
# ─────────────────────────────────────────────────────────────
module "keypair" {
  source = "./modules/keypair"

  project_name = var.project_name
  environment  = var.environment
  key_name     = var.key_name
}

# ─────────────────────────────────────────────────────────────
# Security Layer: Security Groups for Jenkins and App
# ─────────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  allowed_ips     = var.allowed_ips
  app_allowed_ips = var.app_allowed_ips
}

# ─────────────────────────────────────────────────────────────
# Secure Connectivity: VPC Endpoints for private AWS access
# ─────────────────────────────────────────────────────────────
module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  aws_region      = var.aws_region
  subnet_ids      = module.vpc.public_subnets
  route_table_ids = module.vpc.public_route_table_ids
}

# ─────────────────────────────────────────────────────────────
# Secret Management: Jenkins credentials in Secrets Manager
# ─────────────────────────────────────────────────────────────
module "secrets" {
  source = "./modules/secrets"

  project_name           = var.project_name
  environment            = var.environment
  jenkins_admin_password = var.jenkins_admin_password
  ssh_key_name           = module.keypair.key_name
  ssh_private_key_pem    = module.keypair.private_key_pem
  ssh_public_key_openssh = module.keypair.public_key_openssh
}

# ─────────────────────────────────────────────────────────────
# Container Registry: ECR repository for Docker images
# ─────────────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  project_name    = var.project_name
  environment     = var.environment
  repository_name = var.ecr_repository_name
  max_image_count = var.ecr_max_image_count
}

# ─────────────────────────────────────────────────────────────
# Container Orchestration: ECS Cluster, Service, Task Definition
# IAM Roles, Security Group, CloudWatch Logs, and Alarms
# ─────────────────────────────────────────────────────────────
module "ecs" {
  source = "./modules/ecs"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  cluster_name              = var.ecs_cluster_name
  service_name              = var.ecs_service_name
  task_family               = var.ecs_task_family
  task_cpu                  = var.ecs_task_cpu
  task_memory               = var.ecs_task_memory
  container_port            = 5000
  desired_count             = var.ecs_desired_count
  ecr_repository_url        = module.ecr.repository_url
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.public_subnets
  app_allowed_ips           = var.app_allowed_ips
  log_group_name            = var.ecs_log_group_name
  log_retention_days        = var.ecs_log_retention_days
  enable_container_insights = true
}

# ─────────────────────────────────────────────────────────────
# Identity Layer: IAM roles for Jenkins EC2 (with ECR/ECS perms)
# ─────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  project_name               = var.project_name
  environment                = var.environment
  secret_arn                 = module.secrets.secret_arn
  ecr_repository_arn         = module.ecr.repository_arn
  ecs_task_execution_role_arn = module.ecs.task_execution_role_arn
  ecs_task_role_arn           = module.ecs.task_role_arn
}

# ─────────────────────────────────────────────────────────────
# CI/CD Server: Jenkins on EC2
# ─────────────────────────────────────────────────────────────
module "jenkins" {
  source = "./modules/jenkins"

  project_name         = var.project_name
  environment          = var.environment
  ami_id               = data.aws_ami.amazon_linux.id
  instance_type        = var.jenkins_instance_type
  key_name             = module.keypair.key_name
  subnet_id            = module.vpc.public_subnets[0]
  security_group_ids   = [module.security_groups.jenkins_sg_id]
  secret_name          = module.secrets.secret_name
  iam_instance_profile = module.iam.instance_profile_name
  volume_size          = var.jenkins_volume_size
}

# ─────────────────────────────────────────────────────────────
# Application Hosting (Legacy EC2): Kept for backwards compat
# ─────────────────────────────────────────────────────────────
module "app_server" {
  source = "./modules/ec2"

  project_name       = var.project_name
  environment        = var.environment
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = var.app_instance_type
  key_name           = module.keypair.key_name
  subnet_id          = module.vpc.public_subnets[1]
  security_group_ids = [module.security_groups.app_sg_id]
  user_data          = file("${path.module}/scripts/app-server-setup.sh")
  volume_size        = var.app_volume_size
}

# ─────────────────────────────────────────────────────────────
# Observability: CloudWatch dashboards and alarms
# ─────────────────────────────────────────────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  jenkins_instance_id = module.jenkins.instance_id
  app_instance_id   = module.app_server.instance_id
  vpc_id            = module.vpc.vpc_id
  ecs_cluster_name  = module.ecs.cluster_name
  ecs_service_name  = module.ecs.service_name
  enable_ec2_app_alarm = false
  enable_ecs_alarms = true
}

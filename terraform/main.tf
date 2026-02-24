# Terraform configuration for provisioning a secure CI/CD infrastructure on AWS
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

# Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Networking layer: Create VPC, Subnets, and Route Tables
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
}

# EC2 Authentication: Generate SSH key pair locally and register in AWS
module "keypair" {
  source = "./modules/keypair"

  project_name = var.project_name
  environment  = var.environment
  key_name     = var.key_name
}

# Security Layer: Define firewall rules (Security Groups)
module "security_groups" {
  source = "./modules/security"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  allowed_ips     = var.allowed_ips
  app_allowed_ips = var.app_allowed_ips
}

# Secure Connectivity: Configure VPC endpoints for private AWS service access
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

# Identity Layer: Create IAM roles and instance profiles for EC2
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  secret_arn   = module.secrets.secret_arn
}

# Secret Management: Securely store sensitive credentials
module "secrets" {
  source = "./modules/secrets"

  project_name           = var.project_name
  environment            = var.environment
  jenkins_admin_password = var.jenkins_admin_password
  ssh_key_name           = module.keypair.key_name
  ssh_private_key_pem    = module.keypair.private_key_pem
  ssh_public_key_openssh = module.keypair.public_key_openssh
}

# CI/CD Server: Provision Jenkins on EC2
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

# Observability Layer: Configure CloudWatch dashboards and alarms
module "monitoring" {
  source = "./modules/monitoring"

  project_name        = var.project_name
  environment         = var.environment
  jenkins_instance_id = module.jenkins.instance_id
  app_instance_id     = module.app_server.instance_id
  vpc_id              = module.vpc.vpc_id
}

# Application Hosting: Provision the node-app server on EC2
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

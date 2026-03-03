# Jenkins EC2 Module
# Provisions an EC2 instance to run Jenkins CI/CD server
# Includes user data script for Jenkins installation and configuration

resource "aws_instance" "jenkins" {
  # Amazon Machine Image
  ami = var.ami_id
  # Instance size (e.g., t3.medium for Jenkins)
  instance_type = var.instance_type
  # SSH key for access
  key_name = var.key_name
  # Subnet placement
  subnet_id = var.subnet_id
  # Network security
  vpc_security_group_ids = var.security_group_ids
  # IAM profile for AWS access
  iam_instance_profile = var.iam_instance_profile

  # Bootstrap script to install and configure Jenkins
  user_data = templatefile("${path.module}/jenkins-setup.sh", {
    secret_name = var.secret_name
    aws_region  = data.aws_region.current.name
  })

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  # Resource tags
  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins"
    Type = "Jenkins"
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Elastic IP for persistent public IP address
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-eip"
  }
}

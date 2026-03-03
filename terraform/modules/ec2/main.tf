# EC2 Instance Module for Application Server
# This module provisions an EC2 instance to host the Node.js application
# Includes root volume encryption and proper tagging for organization

resource "aws_instance" "app_server" {
  # Amazon Machine Image ID for the instance
  ami = var.ami_id
  # EC2 instance type (e.g., t3.micro, t3.small)
  instance_type = var.instance_type
  # SSH key pair name for instance access
  key_name = var.key_name
  # VPC subnet where the instance will be launched
  subnet_id = var.subnet_id
  # Security groups to attach for network access control
  vpc_security_group_ids = var.security_group_ids
  # Cloud-init script to configure instance on first boot
  user_data = var.user_data

  # Root block device configuration
  root_block_device {
    # Use gp3 for better performance and cost efficiency
    volume_type = "gp3"
    # Size in GiB
    volume_size = var.volume_size
    # Enable encryption at rest for security compliance
    encrypted = true
  }

  # Tags for resource identification and cost tracking
  tags = {
    # Instance name for easy identification in AWS console
    Name = "${var.project_name}-${var.environment}-app-server"
    # Project tag for grouping related resources
    Project = var.project_name
    # Environment tag (dev, staging, production)
    Environment = var.environment
  }
}

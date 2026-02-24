#!/bin/bash
# Script to install Docker on an Amazon Linux EC2 instance and configure user permissions
# Run this on your EC2 instance as the default 'ec2-user'

# Update the system's package index to ensure the latest versions are available
sudo yum update -y
# Install the Docker engine package
sudo yum install -y docker
# Start the Docker daemon
sudo systemctl start docker
# Enable Docker to start automatically on system boot
sudo systemctl enable docker
# Add the current user ('ec2-user') to the 'docker' group to allow running commands without sudo
sudo usermod -a -G docker ec2-user

echo "Docker installed! Please logout and login again for group changes to take effect."
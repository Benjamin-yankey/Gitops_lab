#!/bin/bash
# Script to install and configure Jenkins on an Amazon Linux EC2 instance.
# This should be executed after Docker has been set up on the instance.

# Update package repository and install Java 11 OpenJDK (required for Jenkins)
sudo yum install -y java-11-openjdk

# Download the Jenkins repository configuration and import the GPG key for package validation
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install the Jenkins package
sudo yum install -y jenkins

# Start the Jenkins service and configure it to start automatically on system boot
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Add the 'jenkins' system user to the 'docker' group to allow Jenkins to run Docker commands
sudo usermod -a -G docker jenkins
# Restart Jenkins to apply group membership changes
sudo systemctl restart jenkins

echo "Jenkins installed! Access it at http://YOUR_EC2_IP:8080"
echo "Initial admin password:"
# Display the initial admin password needed for the first-time setup
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
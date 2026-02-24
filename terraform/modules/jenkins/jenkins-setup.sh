#!/bin/bash
set -e

exec > >(tee /var/log/jenkins-setup.log)
exec 2>&1

echo "Starting Jenkins setup at $(date)"

yum update -y

echo "Installing AWS CLI..."
yum install -y aws-cli

echo "Installing Docker..."
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

echo "Installing Java..."
amazon-linux-extras install java-openjdk11 -y
java -version

echo "Adding Jenkins repository..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

echo "Installing Jenkins..."
yum install -y jenkins
usermod -a -G docker jenkins

echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

echo "Retrieving Jenkins password from Secrets Manager..."
JENKINS_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --region ${aws_region} --query SecretString --output text)

echo "Configuring Jenkins..."
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << GROOVYEOF
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "$JENKINS_PASSWORD")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()

Jenkins.instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)
GROOVYEOF

echo "Starting Jenkins service..."
systemctl start jenkins
systemctl enable jenkins

echo "Waiting for Jenkins to start..."
sleep 60

systemctl status jenkins

echo "Installing additional tools..."
yum install -y git

echo "Jenkins setup completed at $(date)!"
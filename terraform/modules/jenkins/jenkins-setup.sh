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

echo "Installing additional tools..."
yum install -y git

echo "Retrieving Jenkins password from Secrets Manager..."
JENKINS_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --region ${aws_region} --query SecretString --output text)

echo "Preparing Jenkins Docker configuration..."
systemctl disable --now jenkins || true

mkdir -p /opt/jenkins_home /opt/jenkins_init
chown -R 1000:1000 /opt/jenkins_home /opt/jenkins_init

cat > /opt/jenkins_init/basic-security.groovy << 'GROOVYEOF'
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()
def adminUser = System.getenv("JENKINS_ADMIN_ID") ?: "admin"
def adminPassword = System.getenv("JENKINS_ADMIN_PASSWORD")

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount(adminUser, adminPassword)
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()

Jenkins.instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)
GROOVYEOF

echo "Starting Jenkins container..."
docker rm -f jenkins || true
docker pull jenkins/jenkins:lts-jdk17
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -u root \
  -p 8080:8080 \
  -p 50000:50000 \
  -e JENKINS_ADMIN_ID=admin \
  -e JENKINS_ADMIN_PASSWORD="$${JENKINS_PASSWORD}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -v /opt/jenkins_home:/var/jenkins_home \
  -v /opt/jenkins_init:/usr/share/jenkins/ref/init.groovy.d \
  jenkins/jenkins:lts-jdk17

echo "Waiting for Jenkins to start..."
for i in {1..30}; do
  if curl -fsS http://localhost:8080/login >/dev/null 2>&1; then
    echo "Jenkins is up."
    break
  fi
  sleep 10
done

docker ps --filter "name=jenkins"
docker logs --tail 50 jenkins || true

echo "Jenkins setup completed at $(date)!"

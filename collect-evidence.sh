#!/bin/bash
# automated evidence collection script for CI/CD pipeline audit and submission
# This script automates the collection of logs and evidence for project submission

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
echo -e "${YELLOW}🔧 CI/CD Pipeline Evidence Collection${NC}"
echo "========================================"
echo ""

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo -e "${RED}❌ Error: terraform directory not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Get EC2 IP from Terraform output
cd terraform
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}❌ Error: Terraform state not found${NC}"
    echo "Please run 'terraform apply' first"
    exit 1
fi

echo -e "${GREEN}📡 Getting EC2 IP from Terraform...${NC}"
EC2_IP=$(terraform output -raw app_server_public_ip 2>/dev/null || echo "")
JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")

if [ -z "$EC2_IP" ]; then
    echo -e "${RED}❌ Error: Could not get EC2 IP from Terraform${NC}"
    echo "Please ensure Terraform has been applied successfully"
    exit 1
fi

echo -e "${GREEN}✅ App Server IP: $EC2_IP${NC}"
echo -e "${GREEN}✅ Jenkins IP: $JENKINS_IP${NC}"
cd ..

# Find SSH key
SSH_KEY=$(find . -name "*.pem" -type f | head -n 1)
if [ -z "$SSH_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: No .pem file found in project directory${NC}"
    echo "Please specify SSH key path manually for EC2 access"
    SSH_KEY="~/.ssh/your-key.pem"
fi

echo -e "${GREEN}🔑 Using SSH key: $SSH_KEY${NC}"
echo ""

# Create directories
echo -e "${GREEN}📁 Creating directories...${NC}"
mkdir -p screenshots logs evidence

# Collect logs
echo ""
echo -e "${GREEN}📋 Collecting logs and evidence...${NC}"
echo "========================================"

# 1. Test results
echo -e "${YELLOW}[1/8]${NC} Running tests and collecting results..."
npm test > logs/test-results.txt 2>&1 || echo "Tests completed with status: $?"
echo -e "${GREEN}✅ Test results saved${NC}"

# 2. Terraform state
echo -e "${YELLOW}[2/8]${NC} Collecting Terraform state..."
cd terraform
terraform state list > ../logs/terraform-state.txt 2>/dev/null || echo "Terraform state list failed"
echo -e "\n=== Terraform Outputs ===" >> ../logs/terraform-state.txt
terraform output >> ../logs/terraform-state.txt 2>/dev/null || echo "Terraform output failed"
cd ..
echo -e "${GREEN}✅ Terraform state saved${NC}"

# 3. Application responses
echo -e "${YELLOW}[3/8]${NC} Collecting application responses..."
{
    echo "=== Root Endpoint ==="
    curl -s http://$EC2_IP:5000/ || echo "Failed to reach root endpoint"
    echo -e "\n\n=== Health Endpoint ==="
    curl -s http://$EC2_IP:5000/health | jq 2>/dev/null || curl -s http://$EC2_IP:5000/health || echo "Failed to reach health endpoint"
    echo -e "\n\n=== API Info Endpoint ==="
    curl -s http://$EC2_IP:5000/api/info | jq 2>/dev/null || curl -s http://$EC2_IP:5000/api/info || echo "Failed to reach API endpoint"
} > logs/app-responses.txt
echo -e "${GREEN}✅ Application responses saved${NC}"

# 4. Docker images on EC2
echo -e "${YELLOW}[4/8]${NC} Collecting Docker images from EC2..."
if [ -f "$SSH_KEY" ]; then
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY" ec2-user@$EC2_IP "docker images" > logs/docker-images.txt 2>/dev/null || echo "Could not connect to EC2 via SSH"
    echo -e "${GREEN}✅ Docker images list saved${NC}"
else
    echo -e "${YELLOW}⚠️  Skipped: SSH key not accessible${NC}"
    echo "Manual command: ssh -i your-key.pem ec2-user@$EC2_IP 'docker images' > logs/docker-images.txt"
fi

# 5. Container logs
echo -e "${YELLOW}[5/8]${NC} Collecting container logs from EC2..."
if [ -f "$SSH_KEY" ]; then
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY" ec2-user@$EC2_IP "docker logs node-app 2>&1" > logs/container-logs.txt 2>/dev/null || echo "Could not get container logs"
    echo -e "${GREEN}✅ Container logs saved${NC}"
else
    echo -e "${YELLOW}⚠️  Skipped: SSH key not accessible${NC}"
    echo "Manual command: ssh -i your-key.pem ec2-user@$EC2_IP 'docker logs node-app' > logs/container-logs.txt"
fi

# 6. Container status
echo -e "${YELLOW}[6/8]${NC} Collecting container status from EC2..."
if [ -f "$SSH_KEY" ]; then
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY" ec2-user@$EC2_IP "docker ps" > logs/container-status.txt 2>/dev/null || echo "Could not get container status"
    echo -e "${GREEN}✅ Container status saved${NC}"
else
    echo -e "${YELLOW}⚠️  Skipped: SSH key not accessible${NC}"
    echo "Manual command: ssh -i your-key.pem ec2-user@$EC2_IP 'docker ps' > logs/container-status.txt"
fi

# 7. Project structure
echo -e "${YELLOW}[7/8]${NC} Documenting project structure..."
tree -L 3 -I 'node_modules|.terraform|.git' > logs/project-structure.txt 2>/dev/null || ls -R > logs/project-structure.txt
echo -e "${GREEN}✅ Project structure saved${NC}"

# 8. Package information
echo -e "${YELLOW}[8/8]${NC} Collecting package information..."
{
    echo "=== Node.js Version ==="
    node --version
    echo -e "\n=== NPM Version ==="
    npm --version
    echo -e "\n=== Installed Packages ==="
    npm list --depth=0
} > logs/package-info.txt 2>&1
echo -e "${GREEN}✅ Package information saved${NC}"

# Create README for evidence
echo ""
echo -e "${GREEN}📝 Creating evidence README...${NC}"
cat > logs/README.md << 'EOF'
# Evidence Collection Results

This directory contains all automatically collected logs and evidence for the CI/CD pipeline project.

## Files Included

1. **test-results.txt** - Unit test execution results
2. **terraform-state.txt** - Terraform infrastructure state and outputs
3. **app-responses.txt** - Application endpoint responses (/, /health, /api/info)
4. **docker-images.txt** - List of Docker images on EC2
5. **container-logs.txt** - Application container logs
6. **container-status.txt** - Running container status
7. **project-structure.txt** - Project directory structure
8. **package-info.txt** - Node.js and package information

## Manual Steps Required

The following evidence must be collected manually:

### Screenshots Needed (save in ../screenshots/)
1. Jenkins pipeline success view
2. Jenkins console output
3. Docker Hub repository with pushed images
4. Application running in browser
5. EC2 container status (terminal)
6. Jenkins credentials configuration
7. AWS EC2 instances dashboard

### Jenkins Console Output
- Navigate to Jenkins build → Console Output
- Copy full output and save as: jenkins-console-output.txt

## Verification Commands

```bash
# Verify application is accessible
curl http://EC2_IP:5000/health

# Check container on EC2
ssh -i key.pem ec2-user@EC2_IP
docker ps
docker logs node-app
```

## Collection Timestamp
EOF

date >> logs/README.md

echo -e "${GREEN}✅ Evidence README created${NC}"

# Create summary
echo ""
echo -e "${GREEN}📊 Evidence Collection Summary${NC}"
echo "========================================"
echo ""
echo -e "${GREEN}✅ Automated collection complete!${NC}"
echo ""
echo "📁 Collected files:"
ls -lh logs/ | tail -n +2 | awk '{print "   - " $9 " (" $5 ")"}'
echo ""
echo -e "${YELLOW}📸 Manual steps remaining:${NC}"
echo "   1. Capture Jenkins pipeline success screenshot"
echo "   2. Capture Jenkins console output screenshot"
echo "   3. Save Jenkins console output as logs/jenkins-console-output.txt"
echo "   4. Capture Docker Hub image screenshot"
echo "   5. Capture application browser screenshot"
echo "   6. Capture EC2 container status screenshot"
echo "   7. Capture Jenkins credentials screenshot"
echo "   8. Capture AWS EC2 instances screenshot"
echo ""
echo -e "${GREEN}📍 Important URLs:${NC}"
echo "   Jenkins: http://$JENKINS_IP:8080"
echo "   Application: http://$EC2_IP:5000"
echo "   Health Check: http://$EC2_IP:5000/health"
echo "   API Info: http://$EC2_IP:5000/api/info"
echo ""
echo -e "${GREEN}🔑 SSH Commands:${NC}"
echo "   Jenkins: ssh -i $SSH_KEY ec2-user@$JENKINS_IP"
echo "   App Server: ssh -i $SSH_KEY ec2-user@$EC2_IP"
echo ""
echo -e "${GREEN}✅ All logs saved in ./logs/ directory${NC}"
echo -e "${GREEN}📸 Save screenshots in ./screenshots/ directory${NC}"
echo ""
echo -e "${YELLOW}📖 For detailed instructions, see EVIDENCE-GUIDE.md${NC}"
echo ""

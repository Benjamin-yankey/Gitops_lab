#!/bin/bash
# Secure Deployment Script
# Automates security-hardened infrastructure deployment

set -e

echo "🚀 Secure CI/CD Infrastructure Deployment"
echo "=========================================="
echo ""

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Please run this script from the terraform directory"
    exit 1
fi

# Step 1: Validate security configuration
echo "Step 1: Validating security configuration..."
./validate-security.sh
if [ $? -ne 0 ]; then
    echo ""
    echo "Please fix security issues before proceeding."
    exit 1
fi
echo ""

# Step 2: Initialize Terraform
echo "Step 2: Initializing Terraform..."
terraform init
echo ""

# Step 3: Validate Terraform configuration
echo "Step 3: Validating Terraform configuration..."
terraform validate
echo ""

# Step 4: Plan deployment
echo "Step 4: Planning deployment..."
terraform plan -out=tfplan
echo ""

# Step 5: Confirm deployment
echo "Step 5: Ready to deploy"
read -p "Do you want to proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi
echo ""

# Step 6: Apply configuration
echo "Step 6: Deploying infrastructure..."
terraform apply tfplan
rm -f tfplan
echo ""

# Step 7: Display outputs
echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Access Information:"
terraform output
echo ""
echo "🔐 Security Reminders:"
echo "  - Jenkins password is stored in AWS Secrets Manager"
echo "  - SSH key pair is stored in AWS Secrets Manager: $(terraform output -raw ssh_keypair_secret_name)"
echo "  - SSH access is restricted to allowed_ips"
echo "  - Private key saved locally: $(terraform output -raw ssh_private_key_local_path)"
echo ""
echo "📖 Next Steps:"
echo "  1. Access Jenkins: terraform output jenkins_url"
echo "  2. Configure Jenkins credentials (registry_creds, ec2_ssh)"
echo "  3. Create pipeline job"
echo "  4. See QUICKSTART.md for detailed instructions"

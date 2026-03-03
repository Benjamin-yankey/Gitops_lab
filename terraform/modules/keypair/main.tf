# Key Pair Module
# Generates an SSH key pair locally using TLS provider
# Saves private key locally and uploads public key to AWS for EC2 access

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Generate SSH key pair locally and upload public key to AWS
# Generate RSA key pair with 4096-bit encryption
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally with restricted permissions
resource "local_sensitive_file" "private_key_pem" {
  filename        = "${path.root}/${var.key_name}.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

# Save public key locally for reference
resource "local_file" "public_key_openssh" {
  filename        = "${path.root}/${var.key_name}.pub"
  content         = tls_private_key.ssh_key.public_key_openssh
  file_permission = "0644"
}

# Import public key into AWS for EC2 instance access
resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

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
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key_pem" {
  filename        = "${path.root}/${var.key_name}.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

resource "local_file" "public_key_openssh" {
  filename        = "${path.root}/${var.key_name}.pub"
  content         = tls_private_key.ssh_key.public_key_openssh
  file_permission = "0644"
}

resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

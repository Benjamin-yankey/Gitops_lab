variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of SSH key pair"
  type        = string
}

variable "ssh_private_key_pem" {
  description = "SSH private key in PEM format"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_openssh" {
  description = "SSH public key in OpenSSH format"
  type        = string
}

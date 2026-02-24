resource "aws_secretsmanager_secret" "jenkins_admin_password" {
  name        = "${var.project_name}-${var.environment}-jenkins-admin-password"
  description = "Jenkins admin password for CI/CD pipeline"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-password"
  }
}

resource "aws_secretsmanager_secret_version" "jenkins_admin_password" {
  secret_id     = aws_secretsmanager_secret.jenkins_admin_password.id
  secret_string = var.jenkins_admin_password
}

resource "aws_secretsmanager_secret" "ssh_keypair" {
  name        = "${var.project_name}-${var.environment}-ssh-keypair"
  description = "Generated SSH key pair for EC2 access"

  tags = {
    Name = "${var.project_name}-${var.environment}-ssh-keypair"
  }
}

resource "aws_secretsmanager_secret_version" "ssh_keypair" {
  secret_id = aws_secretsmanager_secret.ssh_keypair.id
  secret_string = jsonencode({
    key_name    = var.ssh_key_name
    private_key = var.ssh_private_key_pem
    public_key  = var.ssh_public_key_openssh
  })
}

output "secret_arn" {
  description = "ARN of the Jenkins admin password secret"
  value       = aws_secretsmanager_secret.jenkins_admin_password.arn
}

output "secret_name" {
  description = "Name of the Jenkins admin password secret"
  value       = aws_secretsmanager_secret.jenkins_admin_password.name
}

output "ssh_keypair_secret_arn" {
  description = "ARN of the SSH key pair secret"
  value       = aws_secretsmanager_secret.ssh_keypair.arn
}

output "ssh_keypair_secret_name" {
  description = "Name of the SSH key pair secret"
  value       = aws_secretsmanager_secret.ssh_keypair.name
}

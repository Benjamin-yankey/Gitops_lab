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

output "secret_arn" {
  description = "ARN of the Jenkins admin password secret"
  value       = aws_secretsmanager_secret.jenkins_admin_password.arn
}

output "secret_name" {
  description = "Name of the Jenkins admin password secret"
  value       = aws_secretsmanager_secret.jenkins_admin_password.name
}

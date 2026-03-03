output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.mail_db.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mail_db.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.mail_db.db_name
}

output "db_username" {
  description = "Database username"
  value       = aws_db_instance.mail_db.username
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}
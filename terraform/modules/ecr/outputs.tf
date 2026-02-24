output "repository_url" {
  description = "Full URL of the ECR repository (used as image URI prefix)"
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app.name
}

output "registry_id" {
  description = "The registry ID (AWS account ID) where the repository was created"
  value       = aws_ecr_repository.app.registry_id
}

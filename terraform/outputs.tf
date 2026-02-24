# ─────────────────────────────────────────────────────────────
# Network Outputs
# ─────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

# ─────────────────────────────────────────────────────────────
# Jenkins Outputs
# ─────────────────────────────────────────────────────────────
output "jenkins_public_ip" {
  description = "Public IP address of Jenkins server"
  value       = module.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.jenkins.public_ip}:8080"
}

output "ssh_jenkins" {
  description = "SSH command for Jenkins server"
  value       = "ssh -i ${module.keypair.private_key_path} ec2-user@${module.jenkins.public_ip}"
}

output "jenkins_password_secret_name" {
  description = "AWS Secrets Manager secret name for Jenkins admin password"
  value       = module.secrets.secret_name
}

output "jenkins_password_secret_arn" {
  description = "AWS Secrets Manager secret ARN for Jenkins admin password"
  value       = module.secrets.secret_arn
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────
# Legacy App Server Outputs
# ─────────────────────────────────────────────────────────────
output "app_server_public_ip" {
  description = "Public IP address of application server"
  value       = module.app_server.public_ip
}

output "app_url" {
  description = "Application URL (legacy EC2)"
  value       = "http://${module.app_server.public_ip}:5000"
}

output "ssh_app_server" {
  description = "SSH command for application server"
  value       = "ssh -i ${module.keypair.private_key_path} ec2-user@${module.app_server.public_ip}"
}

# ─────────────────────────────────────────────────────────────
# SSH Key Outputs
# ─────────────────────────────────────────────────────────────
output "ssh_keypair_secret_name" {
  description = "AWS Secrets Manager secret name for generated SSH key pair"
  value       = module.secrets.ssh_keypair_secret_name
}

output "ssh_private_key_local_path" {
  description = "Local path to generated private key file"
  value       = module.keypair.private_key_path
}

# ─────────────────────────────────────────────────────────────
# ECR Outputs
# ─────────────────────────────────────────────────────────────
output "ecr_repository_url" {
  description = "Full ECR repository URL (use as image URI prefix in Jenkins)"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.repository_name
}

# ─────────────────────────────────────────────────────────────
# ECS Outputs
# ─────────────────────────────────────────────────────────────
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN (for Jenkins pipeline parameter)"
  value       = module.ecs.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN (for Jenkins pipeline parameter)"
  value       = module.ecs.task_role_arn
}

output "ecs_log_group_name" {
  description = "CloudWatch log group for ECS container logs"
  value       = module.ecs.log_group_name
}

# ─────────────────────────────────────────────────────────────
# AWS Account Info
# ─────────────────────────────────────────────────────────────
output "aws_account_id" {
  description = "AWS Account ID (for Jenkins pipeline parameter)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used"
  value       = var.aws_region
}

# ─────────────────────────────────────────────────────────────
# Jenkins Pipeline Parameters (copy-paste ready!)
# ─────────────────────────────────────────────────────────────
output "jenkins_pipeline_parameters" {
  description = "All values needed for Jenkins 'Build with Parameters'. Copy these into Jenkins."
  value = <<-EOT

    ╔════════════════════════════════════════════════════════════╗
    ║        JENKINS PIPELINE PARAMETERS (copy these!)         ║
    ╠════════════════════════════════════════════════════════════╣
    ║                                                          ║
    ║  AWS_REGION             = ${var.aws_region}
    ║  AWS_ACCOUNT_ID         = ${data.aws_caller_identity.current.account_id}
    ║  ECR_REPOSITORY         = ${module.ecr.repository_name}
    ║  ECS_CLUSTER            = ${module.ecs.cluster_name}
    ║  ECS_SERVICE            = ${module.ecs.service_name}
    ║  ECS_TASK_FAMILY        = ${module.ecs.task_definition_family}
    ║  ECS_EXECUTION_ROLE_ARN = ${module.ecs.task_execution_role_arn}
    ║  ECS_TASK_ROLE_ARN      = ${module.ecs.task_role_arn}
    ║  CLOUDWATCH_LOG_GROUP   = ${module.ecs.log_group_name}
    ║                                                          ║
    ╚════════════════════════════════════════════════════════════╝

  EOT
}

output "jenkins_log_group" {
  description = "Jenkins CloudWatch log group name"
  value       = aws_cloudwatch_log_group.jenkins.name
}

output "app_log_group" {
  description = "App CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "vpc_flow_log_id" {
  description = "VPC Flow Log ID"
  value       = aws_flow_log.vpc.id
}

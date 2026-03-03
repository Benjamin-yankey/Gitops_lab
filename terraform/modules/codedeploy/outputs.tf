output "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_application.ecs_app.name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.ecs_deployment_group.deployment_group_name
}

output "codedeploy_service_role_arn" {
  description = "ARN of the CodeDeploy service role"
  value       = aws_iam_role.codedeploy_service_role.arn
}

output "high_error_rate_alarm_name" {
  description = "Name of the high error rate CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.high_error_rate.alarm_name
}

output "high_response_time_alarm_name" {
  description = "Name of the high response time CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.high_response_time.alarm_name
}
# CodeDeploy Application for Blue/Green ECS Deployments
resource "aws_codedeploy_application" "ecs_app" {
  name             = "${var.app_name}-codedeploy"
  compute_platform = "ECS"

  tags = {
    Name        = "${var.app_name}-codedeploy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_application.ecs_app.name
  deployment_group_name  = "${var.app_name}-dg"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn
  deployment_config_name = "CodeDeployDefault.ECSBlueGreenCanary10Percent5Minutes"

  # ECS Service configuration
  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  # Load balancer configuration (required for blue-green)
  load_balancer_info {
    target_group_info {
      name = var.target_group_name
    }
  }

  # Blue/Green deployment configuration
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                         = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  # Automatic rollback configuration
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # CloudWatch alarms for automatic rollback
  alarm_configuration {
    enabled = true
    alarms  = [
      aws_cloudwatch_metric_alarm.high_error_rate.name,
      aws_cloudwatch_metric_alarm.high_response_time.name
    ]
  }

  tags = {
    Name        = "${var.app_name}-deployment-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarms for automatic rollback
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.app_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5xx error rate"
  alarm_actions       = []

  dimensions = {
    TargetGroup = var.target_group_arn
  }

  tags = {
    Name        = "${var.app_name}-high-error-rate-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${var.app_name}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors response time"
  alarm_actions       = []

  dimensions = {
    TargetGroup = var.target_group_arn
  }

  tags = {
    Name        = "${var.app_name}-high-response-time-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Role for CodeDeploy Service
resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.app_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-codedeploy-service-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach AWS managed policy for ECS CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_ecs_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# Additional permissions for blue-green deployments
resource "aws_iam_role_policy" "codedeploy_additional_permissions" {
  name = "${var.app_name}-codedeploy-additional-permissions"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateTaskSet",
          "ecs:UpdateTaskSet",
          "ecs:DeleteTaskSet",
          "ecs:DescribeTaskSets",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "cloudwatch:DescribeAlarms",
          "sns:Publish",
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}
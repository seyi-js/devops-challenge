resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# SNS topic for alarm notifications
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EC2 CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU utilization above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}

# Memory utilization alarm (requires CloudWatch Agent on the instance)
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EC2 memory utilization above 85% (CloudWatch Agent)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}

# ALB 5xx error alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB 5xx errors above 10 per minute"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EC2 CPU Utilization"
          region  = var.aws_region
          period  = 60
          stat    = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instance_id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EC2 Memory Utilization (CWAgent)"
          region  = var.aws_region
          period  = 60
          stat    = "Average"
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", var.ec2_instance_id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB 5xx Errors"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Application Logs (last 20 lines)"
          region = var.aws_region
          query  = "SOURCE '${var.log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          view   = "table"
        }
      }
    ]
  })
}

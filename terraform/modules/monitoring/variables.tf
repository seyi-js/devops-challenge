variable "name" {
  description = "Resource name prefix / dashboard name"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "ec2_instance_id" {
  description = "EC2 instance ID (used for CPU and memory metric dimensions)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (used for ALB metric dimensions)"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to skip)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region (used in dashboard log widget)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

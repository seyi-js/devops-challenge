variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in (use a private subnet)"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID — allows inbound app traffic from ALB only"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to attach this instance to"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "app_port" {
  description = "Application port exposed by the Docker container"
  type        = number
  default     = 3000
}

variable "log_group_name" {
  description = "CloudWatch log group name for the application"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

output "app_url" {
  description = "Application URL (ALB DNS)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL — add as ECR_REPO_NAME secret in GitHub"
  value       = module.ecr.repository_url
}

output "ec2_instance_id" {
  description = "EC2 instance ID — add as EC2_INSTANCE_ID secret in GitHub"
  value       = module.ec2.instance_id
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}

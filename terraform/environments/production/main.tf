terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devops-challenge-tfstate"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devops-challenge-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name = "devops-challenge"
  common_tags = {
    Project     = "devops-challenge"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  tags                 = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  name = local.name
  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = 3000
  tags              = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name             = local.name
  log_group_name   = "/ec2/${local.name}"
  ec2_instance_id  = module.ec2.instance_id
  alb_arn_suffix   = module.alb.alb_arn_suffix
  alert_email      = var.alert_email
  aws_region       = var.aws_region
  tags             = local.common_tags
}

module "ec2" {
  source = "../../modules/ec2"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.vpc.private_subnet_ids[0]
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn
  instance_type         = var.instance_type
  app_port              = 3000
  log_group_name        = "/ec2/${local.name}"
  tags                  = local.common_tags

  depends_on = [module.monitoring]
}

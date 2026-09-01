# ============================================================================
# Dev Environment - Main Configuration
# ============================================================================

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "terraform-state-msk-platform-dev"
    key            = "msk/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-msk-platform"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Import root module
module "msk_platform" {
  source = "../../"

  # Pass all variables to root module
  aws_region                            = var.aws_region
  environment                           = var.environment
  project_name                          = var.project_name
  owner                                 = var.owner
  cost_center                           = var.cost_center
  vpc_cidr                              = var.vpc_cidr
  availability_zones                    = var.availability_zones
  private_subnet_cidrs                  = var.private_subnet_cidrs
  public_subnet_cidrs                   = var.public_subnet_cidrs
  enable_nat_gateway                    = var.enable_nat_gateway
  single_nat_gateway                    = var.single_nat_gateway
  msk_cluster_name                      = var.msk_cluster_name
  kafka_version                         = var.kafka_version
  broker_instance_type                  = var.broker_instance_type
  number_of_broker_nodes                = var.number_of_broker_nodes
  broker_volume_size                    = var.broker_volume_size
  enable_tls                            = var.enable_tls
  enable_iam_auth                       = var.enable_iam_auth
  enable_encryption_at_rest             = var.enable_encryption_at_rest
  client_authentication                 = var.client_authentication
  allowed_cidr_blocks                   = var.allowed_cidr_blocks
  enable_cloudwatch_logs                = var.enable_cloudwatch_logs
  cloudwatch_log_retention_days         = var.cloudwatch_log_retention_days
  enhanced_monitoring                   = var.enhanced_monitoring
  prometheus_jmx_exporter_enabled       = var.prometheus_jmx_exporter_enabled
  prometheus_node_exporter_enabled      = var.prometheus_node_exporter_enabled
  enable_storage_autoscaling            = var.enable_storage_autoscaling
  storage_autoscaling_max_capacity      = var.storage_autoscaling_max_capacity
  storage_autoscaling_target_percentage = var.storage_autoscaling_target_percentage
  eks_cluster_name                      = var.eks_cluster_name
  service_namespaces                    = var.service_namespaces
  additional_tags                       = var.additional_tags
}

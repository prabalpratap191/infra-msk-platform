# ============================================================================
# Main Terraform Configuration for MSK Platform
# ============================================================================

# Local variables for common configurations
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(
    {
      Name        = local.name_prefix
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}

# ============================================================================
# Networking Module
# ============================================================================

module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

# ============================================================================
# Security Group Module
# ============================================================================

module "security_group" {
  source = "./modules/security-group"

  vpc_id                        = module.networking.vpc_id
  allowed_cidr_blocks           = var.allowed_cidr_blocks
  eks_cluster_security_group_id = var.eks_cluster_security_group_id
  
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

# ============================================================================
# MSK Cluster Module
# ============================================================================

module "msk" {
  source = "./modules/msk"

  cluster_name                   = var.msk_cluster_name
  kafka_version                  = var.kafka_version
  broker_instance_type           = var.broker_instance_type
  number_of_broker_nodes         = var.number_of_broker_nodes
  broker_volume_size             = var.broker_volume_size
  
  # Networking
  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security_group.security_group_id]
  
  # Security
  enable_tls                 = var.enable_tls
  enable_iam_auth            = var.enable_iam_auth
  enable_encryption_at_rest  = var.enable_encryption_at_rest
  client_authentication      = var.client_authentication
  
  # Monitoring
  enable_cloudwatch_logs            = var.enable_cloudwatch_logs
  enable_firehose_logs              = var.enable_firehose_logs
  enable_s3_logs                    = var.enable_s3_logs
  cloudwatch_log_retention_days     = var.cloudwatch_log_retention_days
  enhanced_monitoring               = var.enhanced_monitoring
  prometheus_jmx_exporter_enabled   = var.prometheus_jmx_exporter_enabled
  prometheus_node_exporter_enabled  = var.prometheus_node_exporter_enabled
  
  # Storage Autoscaling
  enable_storage_autoscaling            = var.enable_storage_autoscaling
  storage_autoscaling_max_capacity      = var.storage_autoscaling_max_capacity
  storage_autoscaling_target_percentage = var.storage_autoscaling_target_percentage
  
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

# ============================================================================
# Kafka Topics Module
# ============================================================================

module "kafka_topics" {
  source = "./modules/kafka-topics"

  bootstrap_brokers = module.msk.bootstrap_brokers_sasl_iam
  kafka_topics      = var.kafka_topics
  
  # This module will create configuration files for topic creation
  # Actual topic creation will be handled by scripts post-deployment
  cluster_arn = module.msk.cluster_arn
  
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

# ============================================================================
# Monitoring Module
# ============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  cluster_name          = module.msk.cluster_name
  cluster_arn           = module.msk.cluster_arn
  bootstrap_brokers     = module.msk.bootstrap_brokers_sasl_iam
  kafka_topics          = var.kafka_topics[*].name
  number_of_brokers     = var.number_of_broker_nodes
  log_retention_days    = var.cloudwatch_log_retention_days
  
  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags
}

# ============================================================================
# MSK Cluster Outputs
# ============================================================================

output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = module.msk.cluster_arn
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = module.msk.cluster_name
}

output "bootstrap_brokers" {
  description = "Plaintext bootstrap brokers (if enabled)"
  value       = module.msk.bootstrap_brokers
  sensitive   = true
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap brokers"
  value       = module.msk.bootstrap_brokers_tls
  sensitive   = true
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM bootstrap brokers"
  value       = module.msk.bootstrap_brokers_sasl_iam
  sensitive   = true
}

output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = module.msk.zookeeper_connect_string
  sensitive   = true
}

output "msk_cluster_version" {
  description = "Kafka version of the MSK cluster"
  value       = module.msk.cluster_version
}

# ============================================================================
# Security Outputs
# ============================================================================

output "msk_security_group_id" {
  description = "Security group ID for MSK cluster"
  value       = module.security_group.security_group_id
}

output "msk_security_group_name" {
  description = "Security group name for MSK cluster"
  value       = module.security_group.security_group_name
}

output "kms_key_id" {
  description = "KMS key ID for MSK encryption"
  value       = module.msk.kms_key_id
}

# ============================================================================
# Networking Outputs
# ============================================================================

output "vpc_id" {
  description = "VPC ID where MSK is deployed"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for MSK brokers"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

# ============================================================================
# Monitoring Outputs
# ============================================================================

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for MSK logs"
  value       = module.monitoring.cloudwatch_log_group_name
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for MSK metrics"
  value       = module.monitoring.dashboard_name
}

# ============================================================================
# Kafka Topics Outputs
# ============================================================================

output "kafka_topics" {
  description = "List of created Kafka topics"
  value       = var.kafka_topics[*].name
}

output "kafka_topics_config" {
  description = "Configuration of Kafka topics"
  value = {
    for topic in var.kafka_topics : topic.name => {
      partitions         = topic.partitions
      replication_factor = topic.replication_factor
      config             = topic.config
    }
  }
}

# ============================================================================
# IAM Outputs for EKS Integration
# ============================================================================

output "msk_client_iam_policy_arn" {
  description = "IAM policy ARN for MSK client access"
  value       = module.msk.client_iam_policy_arn
}

output "service_account_roles" {
  description = "IAM roles for Kubernetes service accounts"
  value = {
    for ns in var.service_namespaces :
    ns => "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/msk-${var.environment}-${ns}-role"
  }
}

# ============================================================================
# Connection Information for Spring Boot
# ============================================================================

output "spring_boot_config" {
  description = "Spring Boot Kafka configuration"
  value = {
    bootstrap_servers   = module.msk.bootstrap_brokers_sasl_iam
    security_protocol   = "SASL_SSL"
    sasl_mechanism      = "AWS_MSK_IAM"
    ssl_truststore_location = "/tmp/kafka.client.truststore.jks"
  }
  sensitive = true
}

# ============================================================================
# Utility Outputs
# ============================================================================

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

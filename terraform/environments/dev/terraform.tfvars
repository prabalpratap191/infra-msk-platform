# ============================================================================
# Dev Environment Configuration for MSK Platform
# ============================================================================

# General Settings
aws_region   = "us-east-1"
environment  = "dev"
project_name = "msk-platform"
owner        = "DevOps-Team"
cost_center  = "Engineering"

# Networking Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# NAT Gateway Settings (Cost Optimization for Dev)
enable_nat_gateway = true
single_nat_gateway = true # Single NAT Gateway to reduce costs in dev

# MSK Cluster Configuration
msk_cluster_name       = "msk-cluster-dev"
kafka_version          = "3.6.0"
broker_instance_type   = "kafka.t3.small" # Cost-optimized for dev
number_of_broker_nodes = 3
broker_volume_size     = 100

# Security Settings
enable_tls                 = true
enable_iam_auth            = true
enable_encryption_at_rest  = true
client_authentication      = "TLS_IAM"
allowed_cidr_blocks        = ["10.0.0.0/16"]

# Monitoring Configuration
enable_cloudwatch_logs            = true
enable_firehose_logs              = false
enable_s3_logs                    = false
cloudwatch_log_retention_days     = 7
enhanced_monitoring               = "PER_BROKER"
prometheus_jmx_exporter_enabled   = true
prometheus_node_exporter_enabled  = true

# Storage Autoscaling
enable_storage_autoscaling            = true
storage_autoscaling_max_capacity      = 500
storage_autoscaling_target_percentage = 70

# EKS Integration
eks_cluster_name = "meracommerce-dev-cluster"
# eks_cluster_security_group_id = "sg-xxxxxxxxx" # Update with actual EKS SG ID after getting from: aws eks describe-cluster --name meracommerce-dev-cluster

# Service Namespaces (Already created in meracommerce-dev-cluster)
service_namespaces = [
  "customer-service-ns",
  "order-service-ns",
  "catalog-service-ns",
  "order-history-service-ns",
  "notification-service-ns",
  "payments-service-ns"
]

# Additional Tags
additional_tags = {
  Terraform   = "true"
  CostOptimization = "enabled"
  Backup      = "daily"
}

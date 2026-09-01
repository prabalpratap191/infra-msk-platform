# ============================================================================
# General Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for MSK deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "msk-platform"
}

variable "owner" {
  description = "Owner or team responsible for the infrastructure"
  type        = string
  default     = "DevOps-Team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Engineering"
}

# ============================================================================
# Networking Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost optimization for dev)"
  type        = bool
  default     = true # Set to false for production
}

# ============================================================================
# MSK Cluster Variables
# ============================================================================

variable "msk_cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
  default     = "msk-cluster-dev"
}

variable "kafka_version" {
  description = "Kafka version for MSK cluster"
  type        = string
  default     = "3.6.0" # Latest stable version
}

variable "broker_instance_type" {
  description = "Instance type for Kafka brokers"
  type        = string
  default     = "kafka.t3.small" # Cost-optimized for dev
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes in the cluster"
  type        = number
  default     = 3
}

variable "broker_volume_size" {
  description = "Size of EBS volume for each broker (GB)"
  type        = number
  default     = 100
}

variable "enable_storage_autoscaling" {
  description = "Enable auto scaling of broker storage"
  type        = bool
  default     = true
}

variable "storage_autoscaling_max_capacity" {
  description = "Maximum storage capacity for autoscaling (GB)"
  type        = number
  default     = 500
}

variable "storage_autoscaling_target_percentage" {
  description = "Target percentage for storage autoscaling"
  type        = number
  default     = 70
}

# ============================================================================
# MSK Security Variables
# ============================================================================

variable "enable_tls" {
  description = "Enable TLS encryption for MSK cluster"
  type        = bool
  default     = true
}

variable "enable_iam_auth" {
  description = "Enable IAM authentication for MSK cluster"
  type        = bool
  default     = true
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for MSK cluster"
  type        = bool
  default     = true
}

variable "client_authentication" {
  description = "Client authentication configuration"
  type        = string
  default     = "TLS_IAM" # TLS, IAM, or TLS_IAM
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to MSK cluster"
  type        = list(string)
  default     = ["10.0.0.0/16"] # VPC CIDR by default
}

# ============================================================================
# MSK Monitoring Variables
# ============================================================================

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for MSK cluster"
  type        = bool
  default     = true
}

variable "enable_firehose_logs" {
  description = "Enable Kinesis Data Firehose logs"
  type        = bool
  default     = false
}

variable "enable_s3_logs" {
  description = "Enable S3 logs for MSK cluster"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enhanced_monitoring" {
  description = "Enhanced monitoring level (DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION)"
  type        = string
  default     = "PER_BROKER"
}

variable "prometheus_jmx_exporter_enabled" {
  description = "Enable Prometheus JMX Exporter"
  type        = bool
  default     = true
}

variable "prometheus_node_exporter_enabled" {
  description = "Enable Prometheus Node Exporter"
  type        = bool
  default     = true
}

# ============================================================================
# Kafka Topics Configuration
# ============================================================================

variable "kafka_topics" {
  description = "List of Kafka topics to create"
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = number
    config = map(string)
  }))
  default = [
    {
      name               = "customer-orderstatus-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000" # 7 days
        "cleanup.policy"      = "delete"
      }
    },
    {
      name               = "order-create-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000"
        "cleanup.policy"      = "delete"
      }
    },
    {
      name               = "catalog-updation-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000"
        "cleanup.policy"      = "delete"
      }
    },
    {
      name               = "payment-confirm-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000"
        "cleanup.policy"      = "delete"
      }
    },
    {
      name               = "notification-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000"
        "cleanup.policy"      = "delete"
      }
    },
    {
      name               = "dead-letter-events"
      partitions         = 6
      replication_factor = 3
      config = {
        "min.insync.replicas" = "2"
        "retention.ms"        = "604800000"
        "cleanup.policy"      = "delete"
      }
    }
  ]
}

# ============================================================================
# EKS Integration Variables
# ============================================================================

variable "eks_cluster_name" {
  description = "Name of the EKS cluster for integration"
  type        = string
  default     = "eks-cluster-dev"
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
  default     = "" # To be provided or looked up
}

variable "service_namespaces" {
  description = "List of Kubernetes namespaces for microservices"
  type        = list(string)
  default = [
    "customer-service-ns",
    "order-service-ns",
    "catalog-service-ns",
    "order-history-service-ns",
    "notification-service-ns",
    "payments-service-ns"
  ]
}

# ============================================================================
# Configuration Server Variables (Optional)
# ============================================================================

variable "enable_configuration_server" {
  description = "Enable MSK Configuration Server for topic management"
  type        = bool
  default     = false
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

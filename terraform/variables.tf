# ============================================================================
# Global Variables
# ============================================================================

variable "project_name" {
  description = "Project name to be used as prefix for all resources"
  type        = string
  default     = "meracommerce"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# Networking Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = true
}

# ============================================================================
# Kafka EC2 Variables
# ============================================================================

variable "kafka_instance_type" {
  description = "EC2 instance type for Kafka brokers"
  type        = string
  default     = "t3.medium"
}

variable "kafka_instance_count" {
  description = "Number of Kafka broker instances"
  type        = number
  default     = 3
}

variable "kafka_volume_size" {
  description = "EBS volume size in GB for each Kafka broker"
  type        = number
  default     = 100
}

variable "kafka_volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "kafka_version" {
  description = "Apache Kafka version"
  type        = string
  default     = "3.6.1"
}

variable "kafka_private_ips" {
  description = "Static private IPs for Kafka brokers"
  type        = list(string)
  default     = ["10.0.101.10", "10.0.102.10", "10.0.103.10"]
}

variable "kafka_public_dns" {
  description = "Public DNS for external Kafka access"
  type        = string
  default     = "kafka-public.meracommerce.dev"
}

# ============================================================================
# Security Variables
# ============================================================================

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # CHANGE THIS IN PRODUCTION!
}

variable "enable_public_access" {
  description = "Enable public access to Kafka on port 9094"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "Name of existing EKS cluster"
  type        = string
  default     = "meracommerce-dev-cluster"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair (will be created if not exists)"
  type        = string
  default     = "kafka-key"
}

# ============================================================================
# Route53 Variables
# ============================================================================

variable "create_route53_zone" {
  description = "Create a new Route53 private hosted zone"
  type        = bool
  default     = true
}

variable "route53_zone_name" {
  description = "Route53 private hosted zone name"
  type        = string
  default     = "internal"
}

# ============================================================================
# Monitoring Variables
# ============================================================================

variable "enable_cloudwatch_monitoring" {
  description = "Enable CloudWatch detailed monitoring"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus and Grafana monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

# ============================================================================
# Kafka Configuration Variables
# ============================================================================

variable "kafka_topics" {
  description = "Kafka topics to create"
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = number
    min_insync_replicas = number
  }))
  default = [
    {
      name                = "customer-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "order-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "catalog-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "payment-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "notification-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "dead-letter-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    },
    {
      name                = "audit-events"
      partitions          = 6
      replication_factor  = 3
      min_insync_replicas = 2
    }
  ]
}

variable "kafka_heap_opts" {
  description = "JVM heap options for Kafka"
  type        = string
  default     = "-Xms2G -Xmx2G"
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

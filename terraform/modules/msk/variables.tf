variable "cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
}

variable "kafka_version" {
  description = "Kafka version"
  type        = string
}

variable "broker_instance_type" {
  description = "Instance type for Kafka brokers"
  type        = string
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes"
  type        = number
}

variable "broker_volume_size" {
  description = "Size of EBS volume for each broker (GB)"
  type        = number
}

variable "subnet_ids" {
  description = "List of subnet IDs for brokers"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "enable_tls" {
  description = "Enable TLS encryption"
  type        = bool
  default     = true
}

variable "enable_iam_auth" {
  description = "Enable IAM authentication"
  type        = bool
  default     = true
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "client_authentication" {
  description = "Client authentication type"
  type        = string
  default     = "TLS_IAM"
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "enable_firehose_logs" {
  description = "Enable Firehose logs"
  type        = bool
  default     = false
}

variable "enable_s3_logs" {
  description = "Enable S3 logs"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "firehose_delivery_stream_name" {
  description = "Firehose delivery stream name"
  type        = string
  default     = ""
}

variable "s3_logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
  default     = ""
}

variable "s3_logs_prefix" {
  description = "S3 logs prefix"
  type        = string
  default     = ""
}

variable "enhanced_monitoring" {
  description = "Enhanced monitoring level"
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

variable "enable_storage_autoscaling" {
  description = "Enable storage autoscaling"
  type        = bool
  default     = true
}

variable "storage_autoscaling_max_capacity" {
  description = "Maximum storage capacity (GB)"
  type        = number
  default     = 500
}

variable "storage_autoscaling_target_percentage" {
  description = "Target percentage for storage autoscaling"
  type        = number
  default     = 70
}

variable "enable_provisioned_throughput" {
  description = "Enable provisioned throughput"
  type        = bool
  default     = false
}

variable "provisioned_throughput_volume" {
  description = "Provisioned throughput volume (MiB/s)"
  type        = number
  default     = 250
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_custom_configuration" {
  description = "Enable custom MSK configuration (requires kafka:CreateConfiguration permission)"
  type        = bool
  default     = false
}

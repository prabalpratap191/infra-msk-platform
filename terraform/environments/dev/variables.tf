# Import all variables from root module
variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "owner" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "msk_cluster_name" {
  type = string
}

variable "kafka_version" {
  type = string
}

variable "broker_instance_type" {
  type = string
}

variable "number_of_broker_nodes" {
  type = number
}

variable "broker_volume_size" {
  type = number
}

variable "enable_tls" {
  type = bool
}

variable "enable_iam_auth" {
  type = bool
}

variable "enable_encryption_at_rest" {
  type = bool
}

variable "client_authentication" {
  type = string
}

variable "allowed_cidr_blocks" {
  type = list(string)
}

variable "enable_cloudwatch_logs" {
  type = bool
}

variable "enable_firehose_logs" {
  type    = bool
  default = false
}

variable "enable_s3_logs" {
  type    = bool
  default = false
}

variable "cloudwatch_log_retention_days" {
  type = number
}

variable "enhanced_monitoring" {
  type = string
}

variable "prometheus_jmx_exporter_enabled" {
  type = bool
}

variable "prometheus_node_exporter_enabled" {
  type = bool
}

variable "enable_storage_autoscaling" {
  type = bool
}

variable "storage_autoscaling_max_capacity" {
  type = number
}

variable "storage_autoscaling_target_percentage" {
  type = number
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_security_group_id" {
  type    = string
  default = ""
}

variable "service_namespaces" {
  type = list(string)
}

variable "additional_tags" {
  type = map(string)
}

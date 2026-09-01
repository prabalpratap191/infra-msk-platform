variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kafka_instance_type" {
  description = "EC2 instance type for Kafka brokers"
  type        = string
}

variable "kafka_instance_count" {
  description = "Number of Kafka broker instances"
  type        = number
}

variable "kafka_volume_size" {
  description = "EBS volume size in GB"
  type        = number
}

variable "kafka_volume_type" {
  description = "EBS volume type"
  type        = string
}

variable "kafka_version" {
  description = "Kafka version"
  type        = string
}

variable "kafka_private_ips" {
  description = "Static private IPs for Kafka brokers"
  type        = list(string)
}

variable "kafka_public_dns" {
  description = "Public DNS for Kafka"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "kafka_security_group_id" {
  description = "Kafka security group ID"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "kafka_topics" {
  description = "Kafka topics configuration"
  type = list(object({
    name                = string
    partitions          = number
    replication_factor  = number
    min_insync_replicas = number
  }))
}

variable "kafka_heap_opts" {
  description = "JVM heap options"
  type        = string
}

variable "enable_public_ips" {
  description = "Enable public IPs for Kafka brokers"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

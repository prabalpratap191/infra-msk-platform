variable "bootstrap_brokers" {
  description = "Kafka bootstrap brokers"
  type        = string
}

variable "kafka_topics" {
  description = "List of Kafka topics to create"
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = number
    config             = map(string)
  }))
}

variable "cluster_arn" {
  description = "MSK cluster ARN"
  type        = string
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

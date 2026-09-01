variable "cluster_name" {
  description = "MSK cluster name"
  type        = string
}

variable "cluster_arn" {
  description = "MSK cluster ARN"
  type        = string
}

variable "bootstrap_brokers" {
  description = "Bootstrap brokers"
  type        = string
}

variable "kafka_topics" {
  description = "List of Kafka topics"
  type        = list(string)
}

variable "number_of_brokers" {
  description = "Number of brokers"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
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

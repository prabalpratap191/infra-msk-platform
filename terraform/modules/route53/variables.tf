variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "create_zone" {
  description = "Create a new Route53 private hosted zone"
  type        = bool
  default     = true
}

variable "zone_name" {
  description = "Route53 zone name"
  type        = string
}

variable "existing_zone_id" {
  description = "Existing Route53 zone ID (if not creating new)"
  type        = string
  default     = ""
}

variable "kafka_broker_ips" {
  description = "List of Kafka broker private IPs"
  type        = list(string)
}

variable "kafka_broker_count" {
  description = "Number of Kafka brokers"
  type        = number
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

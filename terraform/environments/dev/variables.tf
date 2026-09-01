# This file inherits all variable definitions from root module
# You can override defaults in terraform.tfvars

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "kafka_instance_type" {
  type = string
}

variable "kafka_instance_count" {
  type = number
}

variable "kafka_volume_size" {
  type = number
}

variable "kafka_volume_type" {
  type = string
}

variable "kafka_version" {
  type = string
}

variable "kafka_private_ips" {
  type = list(string)
}

variable "kafka_public_dns" {
  type = string
}

variable "kafka_heap_opts" {
  type = string
}

variable "kafka_topics" {
  type = list(object({
    name                = string
    partitions          = number
    replication_factor  = number
    min_insync_replicas = number
  }))
}

variable "admin_cidr_blocks" {
  type = list(string)
}

variable "enable_public_access" {
  type = bool
}

variable "eks_cluster_name" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "create_route53_zone" {
  type = bool
}

variable "route53_zone_name" {
  type = string
}

variable "enable_cloudwatch_monitoring" {
  type = bool
}

variable "enable_prometheus" {
  type = bool
}

variable "cloudwatch_retention_days" {
  type = number
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}

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

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for admin access"
  type        = list(string)
}

variable "enable_public_access" {
  description = "Enable public access to Kafka"
  type        = bool
  default     = false
}

variable "eks_node_sg_ids" {
  description = "EKS node security group IDs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

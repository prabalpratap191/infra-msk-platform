variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 40
}

variable "vpc_id" {
  description = "VPC ID where Kafka EC2 will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Kafka EC2 instance"
  type        = string
}

variable "private_vpc_cidr" {
  description = "Private VPC CIDR block for security group rules"
  type        = string
}

variable "eks_worker_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
  default     = ""
}

variable "admin_ip_address" {
  description = "Admin IP address for SSH access"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "kafka_cluster_name" {
  description = "Kafka cluster name"
  type        = string
  default     = "kafka-cluster-dev"
}

variable "kafka_broker_id" {
  description = "Kafka broker ID"
  type        = number
  default     = 1
}

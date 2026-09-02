variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Root Volume Size"
  type        = number
  default     = 40
}

variable "key_name" {
  description = "AWS Key Pair Name"
  type        = string
}

variable "admin_ip_address" {
  description = "54.91.126.56"
  #admin_ip_address = "54.91.126.56"
  type        = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "kafka_cluster_name" {
  default = "kafka-cluster-dev"
}
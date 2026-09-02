# Project Configuration
project_name = "kafka-platform"
environment  = "dev"
aws_region   = "us-east-1"

# Network Configuration
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones    = ["us-east-1a", "us-east-1b"]
enable_nat_gateway    = true
single_nat_gateway    = false

# Kafka Configuration
kafka_instance_type   = "t3.medium"
kafka_instance_count  = 3
kafka_volume_size     = 100
kafka_volume_type     = "gp3"
kafka_version         = "3.5.1"
kafka_private_ips     = ["10.0.10.10", "10.0.10.11", "10.0.10.12"]
kafka_public_dns      = ["kafka1.example.com", "kafka2.example.com", "kafka3.example.com"]
kafka_heap_opts       = "-Xmx4G -Xms4G"
kafka_topics          = ["events", "logs", "metrics"]

# Security Configuration
admin_cidr_blocks     = ["0.0.0.0/0"]  # Replace with your IP range
enable_public_access  = false
ssh_key_name          = "kafka_ssh_ec2-key"

# EKS Configuration
eks_cluster_name      = "kafka-eks-cluster"

# DNS Configuration
create_route53_zone   = false
route53_zone_name     = "meracommerce.com"

# Monitoring Configuration
enable_cloudwatch_monitoring = true
enable_prometheus            = true
cloudwatch_retention_days    = 7

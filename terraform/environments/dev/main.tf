# ============================================================================
# Dev Environment - Kafka Infrastructure
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
}

# Include root module
module "kafka_infrastructure" {
  source = "../../"

  # Global settings
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Networking
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  # Kafka EC2
  kafka_instance_type  = var.kafka_instance_type
  kafka_instance_count = var.kafka_instance_count
  kafka_volume_size    = var.kafka_volume_size
  kafka_volume_type    = var.kafka_volume_type
  kafka_version        = var.kafka_version
  kafka_private_ips    = var.kafka_private_ips
  kafka_public_dns     = var.kafka_public_dns
  kafka_heap_opts      = var.kafka_heap_opts
  kafka_topics         = var.kafka_topics

  # Security
  admin_cidr_blocks    = var.admin_cidr_blocks
  enable_public_access = var.enable_public_access
  eks_cluster_name     = var.eks_cluster_name
  ssh_key_name         = var.ssh_key_name

  # Route53
  create_route53_zone = var.create_route53_zone
  route53_zone_name   = var.route53_zone_name

  # Monitoring
  enable_cloudwatch_monitoring = var.enable_cloudwatch_monitoring
  enable_prometheus            = var.enable_prometheus
  cloudwatch_retention_days    = var.cloudwatch_retention_days

  # Tags
  additional_tags = var.additional_tags
}

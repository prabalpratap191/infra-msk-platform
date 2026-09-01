# ============================================================================
# Main Terraform Configuration for Kafka Infrastructure
# ============================================================================

data "aws_eks_cluster" "existing" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  name = var.eks_cluster_name
}

# Get EKS node security group
data "aws_security_groups" "eks_nodes" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [var.eks_cluster_name]
  }

  filter {
    name   = "tag:Name"
    values = ["*node*", "*Node*"]
  }
}

# ============================================================================
# Networking Module
# ============================================================================

module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = var.single_nat_gateway

  tags = merge(
    var.additional_tags,
    {
      Module = "networking"
    }
  )
}

# ============================================================================
# Security Group Module
# ============================================================================

module "security_group" {
  source = "./modules/security-group"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  admin_cidr_blocks    = var.admin_cidr_blocks
  enable_public_access = var.enable_public_access
  eks_node_sg_ids      = data.aws_security_groups.eks_nodes.ids

  tags = merge(
    var.additional_tags,
    {
      Module = "security-group"
    }
  )
}

# ============================================================================
# SSH Key Pair
# ============================================================================

resource "tls_private_key" "kafka_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kafka_key" {
  key_name   = "${var.project_name}-${var.environment}-kafka-key"
  public_key = tls_private_key.kafka_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-key"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.kafka_key.private_key_pem
  filename        = "${path.module}/../secrets/${var.project_name}-${var.environment}-kafka-key.pem"
  file_permission = "0400"
}

# ============================================================================
# Kafka EC2 Module
# ============================================================================

module "kafka_ec2" {
  source = "./modules/kafka-ec2"

  project_name           = var.project_name
  environment            = var.environment
  kafka_instance_type    = var.kafka_instance_type
  kafka_instance_count   = var.kafka_instance_count
  kafka_volume_size      = var.kafka_volume_size
  kafka_volume_type      = var.kafka_volume_type
  kafka_version          = var.kafka_version
  kafka_private_ips      = var.kafka_private_ips
  kafka_public_dns       = var.kafka_public_dns
  private_subnet_ids     = module.networking.private_subnet_ids
  kafka_security_group_id = module.security_group.kafka_sg_id
  key_name               = aws_key_pair.kafka_key.key_name
  kafka_topics           = var.kafka_topics
  kafka_heap_opts        = var.kafka_heap_opts

  tags = merge(
    var.additional_tags,
    {
      Module = "kafka-ec2"
    }
  )
}

# ============================================================================
# Route53 Module
# ============================================================================

module "route53" {
  source = "./modules/route53"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  create_zone         = var.create_route53_zone
  zone_name           = var.route53_zone_name
  kafka_broker_ips    = module.kafka_ec2.kafka_private_ips
  kafka_broker_count  = var.kafka_instance_count

  tags = merge(
    var.additional_tags,
    {
      Module = "route53"
    }
  )
}

# ============================================================================
# Monitoring Module
# ============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  project_name                = var.project_name
  environment                 = var.environment
  kafka_instance_ids          = module.kafka_ec2.kafka_instance_ids
  enable_cloudwatch_monitoring = var.enable_cloudwatch_monitoring
  cloudwatch_retention_days   = var.cloudwatch_retention_days

  tags = merge(
    var.additional_tags,
    {
      Module = "monitoring"
    }
  )
}

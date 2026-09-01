# ============================================================================
# Security Group Module for MSK Cluster
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# MSK Security Group
# ============================================================================

resource "aws_security_group" "msk" {
  name_prefix = "${local.name_prefix}-msk-"
  description = "Security group for MSK cluster - allows traffic from EKS and within VPC"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-msk-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Ingress Rules
# ============================================================================

# Allow Kafka plaintext traffic (9092) from within VPC
resource "aws_security_group_rule" "kafka_plaintext" {
  count = var.enable_plaintext ? 1 : 0

  type              = "ingress"
  from_port         = 9092
  to_port           = 9092
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Kafka plaintext traffic from VPC"
}

# Allow Kafka TLS traffic (9094)
resource "aws_security_group_rule" "kafka_tls" {
  type              = "ingress"
  from_port         = 9094
  to_port           = 9094
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Kafka TLS traffic from VPC"
}

# Allow Kafka SASL/IAM traffic (9098)
resource "aws_security_group_rule" "kafka_sasl_iam" {
  type              = "ingress"
  from_port         = 9098
  to_port           = 9098
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Kafka SASL/IAM traffic from VPC"
}

# Allow Zookeeper traffic (2181) from within VPC
resource "aws_security_group_rule" "zookeeper" {
  type              = "ingress"
  from_port         = 2181
  to_port           = 2181
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Zookeeper traffic from VPC"
}

# Allow Zookeeper TLS traffic (2182)
resource "aws_security_group_rule" "zookeeper_tls" {
  type              = "ingress"
  from_port         = 2182
  to_port           = 2182
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Zookeeper TLS traffic from VPC"
}

# Allow JMX Exporter traffic for Prometheus (11001, 11002)
resource "aws_security_group_rule" "jmx_exporter" {
  type              = "ingress"
  from_port         = 11001
  to_port           = 11002
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow JMX Exporter traffic for Prometheus monitoring"
}

# Allow Node Exporter traffic for Prometheus (11000)
resource "aws_security_group_rule" "node_exporter" {
  type              = "ingress"
  from_port         = 11000
  to_port           = 11000
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.msk.id
  description       = "Allow Node Exporter traffic for Prometheus monitoring"
}

# Allow traffic from EKS cluster security group if provided
resource "aws_security_group_rule" "from_eks" {
  count = var.eks_cluster_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = var.eks_cluster_security_group_id
  security_group_id        = aws_security_group.msk.id
  description              = "Allow all traffic from EKS cluster"
}

# Self-referencing rule for broker-to-broker communication
resource "aws_security_group_rule" "self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.msk.id
  description       = "Allow all traffic within security group (broker-to-broker)"
}

# ============================================================================
# Egress Rules
# ============================================================================

# Allow all outbound traffic
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.msk.id
  description       = "Allow all outbound traffic"
}

# ============================================================================
# Kafka Security Group
# ============================================================================

resource "aws_security_group" "kafka" {
  name        = "${var.project_name}-${var.environment}-kafka-sg"
  description = "Security group for Kafka brokers"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-kafka-sg"
    }
  )
}

# ============================================================================
# Ingress Rules
# ============================================================================

# Port 9092 - Internal Kafka Communication (from EKS)
resource "aws_security_group_rule" "kafka_internal" {
  count                    = length(var.eks_node_sg_ids)
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = var.eks_node_sg_ids[count.index]
  security_group_id        = aws_security_group.kafka.id
  description              = "Allow Kafka internal traffic from EKS nodes"
}

# Port 9093 - Inter-broker Communication
resource "aws_security_group_rule" "kafka_inter_broker" {
  type              = "ingress"
  from_port         = 9093
  to_port           = 9093
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.kafka.id
  description       = "Allow inter-broker communication"
}

# Port 9094 - External Access (optional)
resource "aws_security_group_rule" "kafka_external" {
  count             = var.enable_public_access ? 1 : 0
  type              = "ingress"
  from_port         = 9094
  to_port           = 9094
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kafka.id
  description       = "Allow external Kafka access"
}

# Port 22 - SSH Access
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.kafka.id
  description       = "Allow SSH access from admin CIDR"
}

# Port 9308 - Kafka Exporter for Prometheus
resource "aws_security_group_rule" "kafka_exporter" {
  type              = "ingress"
  from_port         = 9308
  to_port           = 9308
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.kafka.id
  description       = "Allow Kafka Exporter access"
}

# Port 9100 - Node Exporter for Prometheus
resource "aws_security_group_rule" "node_exporter" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.kafka.id
  description       = "Allow Node Exporter access"
}

# Port 9090 - Prometheus
resource "aws_security_group_rule" "prometheus" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.kafka.id
  description       = "Allow Prometheus access"
}

# Port 3000 - Grafana
resource "aws_security_group_rule" "grafana" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.kafka.id
  description       = "Allow Grafana dashboard access"
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
  security_group_id = aws_security_group.kafka.id
  description       = "Allow all outbound traffic"
}

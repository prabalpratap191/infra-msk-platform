# ============================================================================
# Route53 Private Hosted Zone for Kafka
# ============================================================================

resource "aws_route53_zone" "private" {
  count = var.create_zone ? 1 : 0
  name  = var.zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-zone"
    }
  )
}

# ============================================================================
# Individual Kafka Broker DNS Records
# ============================================================================

resource "aws_route53_record" "kafka_brokers" {
  count   = var.kafka_broker_count
  zone_id = var.create_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
  name    = "kafka-${count.index + 1}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [var.kafka_broker_ips[count.index]]
}

# ============================================================================
# Kafka Bootstrap Server DNS Record (Round-robin)
# ============================================================================

resource "aws_route53_record" "kafka_bootstrap" {
  zone_id = var.create_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
  name    = "kafka-bootstrap.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = var.kafka_broker_ips
}

# ============================================================================
# Alternative: Individual service records for each namespace
# ============================================================================

resource "aws_route53_record" "kafka_service" {
  for_each = toset([
    "customer-service",
    "order-service",
    "catalog-service",
    "payment-service",
    "notification-service"
  ])

  zone_id = var.create_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
  name    = "kafka.${each.key}.${var.zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["kafka-bootstrap.${var.zone_name}"]
}

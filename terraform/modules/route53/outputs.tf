output "zone_id" {
  description = "Route53 zone ID"
  value       = var.create_zone ? aws_route53_zone.private[0].zone_id : var.existing_zone_id
}

output "zone_name" {
  description = "Route53 zone name"
  value       = var.zone_name
}

output "kafka_dns_records" {
  description = "Kafka DNS records"
  value = {
    brokers = [
      for i in range(var.kafka_broker_count) :
      "kafka-${i + 1}.${var.zone_name}"
    ]
    bootstrap = "kafka-bootstrap.${var.zone_name}"
  }
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers for application configuration"
  value       = "kafka-bootstrap.${var.zone_name}:9092"
}

output "service_dns_records" {
  description = "Service-specific Kafka DNS records"
  value = {
    for service in [
      "customer-service",
      "order-service",
      "catalog-service",
      "payment-service",
      "notification-service"
    ] : service => "kafka.${service}.${var.zone_name}:9092"
  }
}

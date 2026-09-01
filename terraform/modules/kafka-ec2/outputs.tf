output "kafka_instance_ids" {
  description = "List of Kafka instance IDs"
  value       = aws_instance.kafka[*].id
}

output "kafka_private_ips" {
  description = "List of Kafka private IPs"
  value       = aws_instance.kafka[*].private_ip
}

output "kafka_public_ips" {
  description = "List of Kafka public IPs"
  value       = var.enable_public_ips ? aws_eip.kafka[*].public_ip : []
}

output "kafka_broker_endpoints" {
  description = "Kafka broker endpoints"
  value = [
    for i, instance in aws_instance.kafka :
    "${instance.private_ip}:9092"
  ]
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = random_uuid.kafka_cluster.result
}

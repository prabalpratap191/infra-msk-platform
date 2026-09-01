output "kafka_sg_id" {
  description = "ID of Kafka security group"
  value       = aws_security_group.kafka.id
}

output "kafka_sg_name" {
  description = "Name of Kafka security group"
  value       = aws_security_group.kafka.name
}

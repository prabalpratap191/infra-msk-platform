output "ec2_instance_id" {
  description = "ID of the Kafka EC2 instance"
  value       = aws_instance.kafka_ec2.id
}

output "ec2_public_ip" {
  description = "Public IP address of the Kafka EC2 instance"
  value       = aws_instance.kafka_ec2.public_ip
}

output "ec2_private_ip" {
  description = "Private IP address of the Kafka EC2 instance"
  value       = aws_instance.kafka_ec2.private_ip
}

output "security_group_id" {
  description = "ID of the Kafka security group"
  value       = aws_security_group.kafka_sg.id
}

output "kafka_bootstrap_server_internal" {
  description = "Kafka bootstrap server for internal VPC access"
  value       = "${aws_instance.kafka_ec2.private_ip}:9092"
}

output "kafka_bootstrap_server_external" {
  description = "Kafka bootstrap server for external access"
  value       = "${aws_instance.kafka_ec2.public_ip}:9094"
}

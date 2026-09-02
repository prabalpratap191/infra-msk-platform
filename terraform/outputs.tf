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

output "ssh_private_key" {
  description = "SSH private key to access EC2 instance"
  value       = tls_private_key.kafka_ssh_key.private_key_pem
  sensitive   = true
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.kafka_key_pair.key_name
}

output "ssh_connection_command" {
  description = "SSH command to connect to EC2 instance"
  value       = "ssh -i kafka-ec2-private-key.pem ec2-user@${aws_instance.kafka_ec2.public_ip}"
}

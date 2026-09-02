output "instance_id" {
  value = aws_instance.kafka.id
}

output "public_ip" {
  value = aws_instance.kafka.public_ip
}

output "private_ip" {
  value = aws_instance.kafka.private_ip
}

output "vpc_id" {
  value = aws_vpc.kafka_vpc.id
}

output "subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "security_group_id" {
  value = aws_security_group.kafka_sg.id
}

output "ssh_command" {
  value = "ssh -i kafka.pem ec2-user@${aws_instance.kafka.public_ip}"
}
# Generate SSH Key Pair dynamically
resource "tls_private_key" "kafka_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair using the generated public key
resource "aws_key_pair" "kafka_key_pair" {
  key_name   = "kafka-ec2-key"
  public_key = tls_private_key.kafka_ssh_key.public_key_openssh

  tags = {
    Name        = "Kafka EC2 SSH Key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Store private key locally (for backup/manual access)
resource "local_file" "private_key" {
  content         = tls_private_key.kafka_ssh_key.private_key_pem
  filename        = "${path.module}/kafka-ec2-private-key.pem"
  file_permission = "0400"
}

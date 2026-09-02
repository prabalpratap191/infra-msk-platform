# Data source to get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Kafka EC2
resource "aws_security_group" "kafka_sg" {
  name        = "kafka-sg"
  description = "Security group for Kafka EC2 instance"
  vpc_id      = var.vpc_id

  # SSH access from admin IP
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip_address}/32"]
  }

  # Kafka internal port from VPC
  ingress {
    description = "Kafka internal from VPC"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.private_vpc_cidr]
  }

  # Kafka external port from VPC
  ingress {
    description = "Kafka external from VPC"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [var.private_vpc_cidr]
  }

  # Kafka internal port from EKS worker nodes
  dynamic "ingress" {
    for_each = var.eks_worker_security_group_id != "" ? [1] : []
    content {
      description     = "Kafka internal from EKS workers"
      from_port       = 9092
      to_port         = 9092
      protocol        = "tcp"
      security_groups = [var.eks_worker_security_group_id]
    }
  }

  # Kafka external port from EKS worker nodes
  dynamic "ingress" {
    for_each = var.eks_worker_security_group_id != "" ? [1] : []
    content {
      description     = "Kafka external from EKS workers"
      from_port       = 9094
      to_port         = 9094
      protocol        = "tcp"
      security_groups = [var.eks_worker_security_group_id]
    }
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kafka-sg"
  }
}

# EC2 Instance for Kafka
resource "aws_instance" "kafka_ec2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = aws_key_pair.kafka_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.kafka_sg.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "kafka-ec2-root-volume"
    }
  }

  user_data = templatefile("${path.module}/userdata.sh", {
    kafka_cluster_name = var.kafka_cluster_name
    kafka_broker_id    = var.kafka_broker_id
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "kafka-ec2-instance"
  }
}

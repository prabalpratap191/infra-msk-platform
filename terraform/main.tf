########################################
# AMI
########################################

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

########################################
# VPC
########################################

resource "aws_vpc" "kafka_vpc" {

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "kafka-vpc"
  }
}

########################################
# Internet Gateway
########################################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.kafka_vpc.id

  tags = {
    Name = "kafka-igw"
  }
}

########################################
# Public Subnet
########################################

resource "aws_subnet" "public_subnet" {

  vpc_id                  = aws_vpc.kafka_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  availability_zone = "us-east-1a"

  tags = {
    Name = "kafka-public-subnet"
  }
}

########################################
# Route Table
########################################

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.kafka_vpc.id

  tags = {
    Name = "kafka-public-rt"
  }
}

resource "aws_route" "internet_route" {

  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

########################################
# Security Group
########################################

resource "aws_security_group" "kafka_sg" {

  name        = "kafka-sg"
  description = "Kafka Security Group"

  vpc_id = aws_vpc.kafka_vpc.id

  ingress {
    description = "SSH"

    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      var.admin_ip_address
    ]
  }

  ingress {
    description = "Kafka"

    from_port = 9092
    to_port   = 9092
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    description = "Kafka Internal"

    from_port = 9093
    to_port   = 9093
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "kafka-sg"
  }
}

########################################
# Kafka EC2
########################################

resource "aws_instance" "kafka" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.public_subnet.id

  vpc_security_group_ids = [
    aws_security_group.kafka_sg.id
  ]

  key_name = var.key_name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  tags = {
    Name        = "kafka-ec2-instance"
    Environment = var.environment
  }
}
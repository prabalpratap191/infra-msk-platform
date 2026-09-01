# ============================================================================
# Data Sources
# ============================================================================

# Get latest Amazon Linux 2023 AMI
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

# ============================================================================
# IAM Role for Kafka EC2 Instances
# ============================================================================

resource "aws_iam_role" "kafka_ec2" {
  name = "${var.project_name}-${var.environment}-kafka-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "kafka_ec2" {
  name = "${var.project_name}-${var.environment}-kafka-ec2-policy"
  role = aws_iam_role.kafka_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeTags",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-kafka-backups",
          "arn:aws:s3:::${var.project_name}-${var.environment}-kafka-backups/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "kafka_ec2" {
  name = "${var.project_name}-${var.environment}-kafka-ec2-profile"
  role = aws_iam_role.kafka_ec2.name
}

# ============================================================================
# User Data Template
# ============================================================================

locals {
  user_data_template = templatefile("${path.module}/user-data.sh", {
    broker_id          = "BROKER_ID"
    kafka_version      = var.kafka_version
    cluster_id         = "CLUSTER_ID"
    kafka_heap_opts    = var.kafka_heap_opts
    project_name       = var.project_name
    environment        = var.environment
    kafka_public_dns   = var.kafka_public_dns
    broker_private_ip  = "BROKER_PRIVATE_IP"
    kafka_private_ips  = jsonencode(var.kafka_private_ips)
  })
}

# ============================================================================
# Kafka Cluster ID (shared across all brokers)
# ============================================================================

resource "random_uuid" "kafka_cluster" {
}

# ============================================================================
# Kafka EC2 Instances
# ============================================================================

resource "aws_instance" "kafka" {
  count                  = var.kafka_instance_count
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.kafka_instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [var.kafka_security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.kafka_ec2.name
  private_ip             = var.kafka_private_ips[count.index]

  user_data = replace(
    replace(
      replace(
        local.user_data_template,
        "BROKER_ID", tostring(count.index + 1)
      ),
      "CLUSTER_ID", random_uuid.kafka_cluster.result
    ),
    "BROKER_PRIVATE_IP", var.kafka_private_ips[count.index]
  )

  root_block_device {
    volume_type           = var.kafka_volume_type
    volume_size           = var.kafka_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-root"
      }
    )
  }

  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.project_name}-${var.environment}-kafka-${count.index + 1}"
      BrokerId  = count.index + 1
      Component = "Kafka-Broker"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}

# ============================================================================
# Elastic IPs (optional for public access)
# ============================================================================

resource "aws_eip" "kafka" {
  count    = var.enable_public_ips ? var.kafka_instance_count : 0
  instance = aws_instance.kafka[count.index].id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-eip"
    }
  )
}

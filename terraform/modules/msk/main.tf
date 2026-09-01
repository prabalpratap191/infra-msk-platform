# ============================================================================
# MSK Cluster Module
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# KMS Key for Encryption at Rest
# ============================================================================

resource "aws_kms_key" "msk" {
  count = var.enable_encryption_at_rest ? 1 : 0

  description             = "KMS key for MSK cluster encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-msk-kms-key"
    }
  )
}

resource "aws_kms_alias" "msk" {
  count = var.enable_encryption_at_rest ? 1 : 0

  name          = "alias/${local.name_prefix}-msk"
  target_key_id = aws_kms_key.msk[0].key_id
}

# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "msk" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-msk-logs"
    }
  )
}

# ============================================================================
# MSK Configuration
# ============================================================================

resource "aws_msk_configuration" "main" {
  name              = "${var.cluster_name}-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<PROPERTIES
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
num.io.threads=8
num.network.threads=5
num.replica.fetchers=2
replica.lag.time.max.ms=30000
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
socket.send.buffer.bytes=102400
unclean.leader.election.enable=false
zookeeper.session.timeout.ms=18000
log.retention.hours=168
log.segment.bytes=1073741824
compression.type=producer
message.max.bytes=1048576
PROPERTIES

  description = "MSK cluster configuration for ${var.environment} environment"
}

# ============================================================================
# MSK Cluster
# ============================================================================

resource "aws_msk_cluster" "main" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids

    storage_info {
      ebs_storage_info {
        volume_size            = var.broker_volume_size
        provisioned_throughput {
          enabled           = var.enable_provisioned_throughput
          volume_throughput = var.enable_provisioned_throughput ? var.provisioned_throughput_volume : null
        }
      }
    }

    connectivity_info {
      public_access {
        type = "DISABLED"
      }
    }
  }

  # Configuration
  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  # Encryption Settings
  encryption_info {
    encryption_at_rest_kms_key_arn = var.enable_encryption_at_rest ? aws_kms_key.msk[0].arn : null

    encryption_in_transit {
      client_broker = var.enable_tls ? "TLS" : "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  # Client Authentication
  client_authentication {
    dynamic "sasl" {
      for_each = var.enable_iam_auth ? [1] : []
      content {
        iam = true
      }
    }

    dynamic "tls" {
      for_each = var.enable_tls && !var.enable_iam_auth ? [1] : []
      content {
        certificate_authority_arns = []
      }
    }

    unauthenticated = var.enable_iam_auth || var.enable_tls ? false : true
  }

  # Logging
  dynamic "logging_info" {
    for_each = var.enable_cloudwatch_logs || var.enable_firehose_logs || var.enable_s3_logs ? [1] : []
    content {
      broker_logs {
        dynamic "cloudwatch_logs" {
          for_each = var.enable_cloudwatch_logs ? [1] : []
          content {
            enabled   = true
            log_group = aws_cloudwatch_log_group.msk[0].name
          }
        }

        dynamic "firehose" {
          for_each = var.enable_firehose_logs ? [1] : []
          content {
            enabled         = true
            delivery_stream = var.firehose_delivery_stream_name
          }
        }

        dynamic "s3" {
          for_each = var.enable_s3_logs ? [1] : []
          content {
            enabled = true
            bucket  = var.s3_logs_bucket
            prefix  = var.s3_logs_prefix
          }
        }
      }
    }
  }

  # Enhanced Monitoring
  enhanced_monitoring = var.enhanced_monitoring

  # Open Monitoring (Prometheus)
  dynamic "open_monitoring" {
    for_each = var.prometheus_jmx_exporter_enabled || var.prometheus_node_exporter_enabled ? [1] : []
    content {
      prometheus {
        jmx_exporter {
          enabled_in_broker = var.prometheus_jmx_exporter_enabled
        }
        node_exporter {
          enabled_in_broker = var.prometheus_node_exporter_enabled
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# ============================================================================
# Storage Autoscaling
# ============================================================================

resource "aws_appautoscaling_target" "msk_storage" {
  count = var.enable_storage_autoscaling ? 1 : 0

  max_capacity       = var.storage_autoscaling_max_capacity
  min_capacity       = var.broker_volume_size
  resource_id        = aws_msk_cluster.main.arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  service_namespace  = "kafka"
}

resource "aws_appautoscaling_policy" "msk_storage" {
  count = var.enable_storage_autoscaling ? 1 : 0

  name               = "${var.cluster_name}-storage-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.msk_storage[0].resource_id
  scalable_dimension = aws_appautoscaling_target.msk_storage[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.msk_storage[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }

    target_value = var.storage_autoscaling_target_percentage
  }
}

# ============================================================================
# IAM Policy for MSK Clients
# ============================================================================

resource "aws_iam_policy" "msk_client" {
  name        = "${local.name_prefix}-msk-client-policy"
  description = "IAM policy for MSK client access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "${aws_msk_cluster.main.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "${aws_msk_cluster.main.arn}/*"
      }
    ]
  })

  tags = var.tags
}

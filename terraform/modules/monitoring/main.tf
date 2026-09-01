# ============================================================================
# Monitoring Module for MSK Cluster
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# CloudWatch Log Group (if not created by MSK module)
# ============================================================================

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-msk-logs"
    }
  )
}

# ============================================================================
# CloudWatch Dashboard
# ============================================================================

resource "aws_cloudwatch_dashboard" "msk" {
  dashboard_name = "${local.name_prefix}-msk-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Cluster Overview
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "ActiveControllerCount", { stat = "Average" }],
            [".", "OfflinePartitionsCount", { stat = "Sum" }],
            [".", "UnderReplicatedPartitions", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Cluster Health Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Broker Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "CpuUser", { stat = "Average" }],
            [".", "CpuSystem", { stat = "Average" }],
            [".", "MemoryUsed", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Broker Resource Utilization"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Network Throughput
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "BytesInPerSec", { stat = "Sum" }],
            [".", "BytesOutPerSec", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Network Throughput (Bytes/Sec)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Message Rate
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "MessagesInPerSec", { stat = "Sum" }],
            [".", "FetchConsumerTotalTimeMs", { stat = "Average" }],
            [".", "ProduceTotalTimeMs", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Message Rate and Latency"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Storage Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "KafkaDataLogsDiskUsed", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Disk Usage (Percentage)"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # Consumer Lag
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "MaxOffsetLag", { stat = "Maximum" }],
            [".", "SumOffsetLag", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Consumer Lag"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

# Alarm: Offline Partitions
resource "aws_cloudwatch_metric_alarm" "offline_partitions" {
  alarm_name          = "${local.name_prefix}-offline-partitions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "OfflinePartitionsCount"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when there are offline partitions"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# Alarm: Under-Replicated Partitions
resource "aws_cloudwatch_metric_alarm" "under_replicated_partitions" {
  alarm_name          = "${local.name_prefix}-under-replicated-partitions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnderReplicatedPartitions"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when there are under-replicated partitions"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# Alarm: High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CpuUser"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CPU usage exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# Alarm: High Disk Usage
resource "aws_cloudwatch_metric_alarm" "high_disk_usage" {
  alarm_name          = "${local.name_prefix}-high-disk-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "KafkaDataLogsDiskUsed"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when disk usage exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# Alarm: High Memory Usage
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${local.name_prefix}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUsed"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Alert when memory usage exceeds 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# Alarm: Consumer Lag
resource "aws_cloudwatch_metric_alarm" "consumer_lag" {
  alarm_name          = "${local.name_prefix}-high-consumer-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MaxOffsetLag"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10000"
  alarm_description   = "Alert when consumer lag exceeds 10000 messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  tags = var.tags
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}

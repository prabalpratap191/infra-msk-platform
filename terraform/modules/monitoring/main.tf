# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "kafka" {
  count             = var.enable_cloudwatch_monitoring ? 1 : 0
  name              = "/aws/ec2/kafka/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-kafka-logs"
    }
  )
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "kafka_cpu" {
  count               = var.enable_cloudwatch_monitoring ? length(var.kafka_instance_ids) : 0
  alarm_name          = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Kafka broker CPU utilization"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = var.kafka_instance_ids[count.index]
  }

  tags = var.tags
}

# Disk Space Alarm
resource "aws_cloudwatch_metric_alarm" "kafka_disk" {
  count               = var.enable_cloudwatch_monitoring ? length(var.kafka_instance_ids) : 0
  alarm_name          = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-high-disk"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Kafka broker disk usage"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = var.kafka_instance_ids[count.index]
    path       = "/opt/kafka/data"
  }

  tags = var.tags
}

# Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "kafka_memory" {
  count               = var.enable_cloudwatch_monitoring ? length(var.kafka_instance_ids) : 0
  alarm_name          = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors Kafka broker memory usage"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = var.kafka_instance_ids[count.index]
  }

  tags = var.tags
}

# Instance Status Check Alarm
resource "aws_cloudwatch_metric_alarm" "kafka_status_check" {
  count               = var.enable_cloudwatch_monitoring ? length(var.kafka_instance_ids) : 0
  alarm_name          = "${var.project_name}-${var.environment}-kafka-${count.index + 1}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors Kafka broker instance status checks"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = var.kafka_instance_ids[count.index]
  }

  tags = var.tags
}

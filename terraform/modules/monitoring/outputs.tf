output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.msk.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.msk.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.msk.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN"
  value       = aws_cloudwatch_dashboard.msk.dashboard_arn
}

output "alarm_arns" {
  description = "List of CloudWatch alarm ARNs"
  value = [
    aws_cloudwatch_metric_alarm.offline_partitions.arn,
    aws_cloudwatch_metric_alarm.under_replicated_partitions.arn,
    aws_cloudwatch_metric_alarm.high_cpu.arn,
    aws_cloudwatch_metric_alarm.high_disk_usage.arn,
    aws_cloudwatch_metric_alarm.high_memory.arn,
    aws_cloudwatch_metric_alarm.consumer_lag.arn
  ]
}

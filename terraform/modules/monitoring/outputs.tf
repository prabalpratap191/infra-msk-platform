output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = var.enable_cloudwatch_monitoring ? aws_cloudwatch_log_group.kafka[0].name : ""
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = var.enable_cloudwatch_monitoring ? aws_cloudwatch_log_group.kafka[0].arn : ""
}

output "cpu_alarm_arns" {
  description = "CloudWatch CPU alarm ARNs"
  value       = var.enable_cloudwatch_monitoring ? aws_cloudwatch_metric_alarm.kafka_cpu[*].arn : []
}

output "disk_alarm_arns" {
  description = "CloudWatch disk alarm ARNs"
  value       = var.enable_cloudwatch_monitoring ? aws_cloudwatch_metric_alarm.kafka_disk[*].arn : []
}

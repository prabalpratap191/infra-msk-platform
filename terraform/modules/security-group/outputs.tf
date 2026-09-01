output "security_group_id" {
  description = "Security group ID for MSK cluster"
  value       = aws_security_group.msk.id
}

output "security_group_name" {
  description = "Security group name for MSK cluster"
  value       = aws_security_group.msk.name
}

output "security_group_arn" {
  description = "Security group ARN for MSK cluster"
  value       = aws_security_group.msk.arn
}

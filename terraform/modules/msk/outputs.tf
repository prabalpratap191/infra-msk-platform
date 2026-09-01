output "cluster_arn" {
  description = "MSK cluster ARN"
  value       = aws_msk_cluster.main.arn
}

output "cluster_name" {
  description = "MSK cluster name"
  value       = aws_msk_cluster.main.cluster_name
}

output "bootstrap_brokers" {
  description = "Plaintext bootstrap brokers"
  value       = aws_msk_cluster.main.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap brokers"
  value       = aws_msk_cluster.main.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM bootstrap brokers"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
}

output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.main.zookeeper_connect_string
}

output "cluster_version" {
  description = "Kafka version"
  value       = aws_msk_cluster.main.kafka_version
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = var.enable_encryption_at_rest ? aws_kms_key.msk[0].id : null
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = var.enable_encryption_at_rest ? aws_kms_key.msk[0].arn : null
}

output "configuration_arn" {
  description = "MSK configuration ARN"
  value       = aws_msk_configuration.main.arn
}

output "configuration_revision" {
  description = "MSK configuration revision"
  value       = aws_msk_configuration.main.latest_revision
}

output "client_iam_policy_arn" {
  description = "IAM policy ARN for MSK client access"
  value       = aws_iam_policy.msk_client.arn
}

output "client_iam_policy_name" {
  description = "IAM policy name for MSK client access"
  value       = aws_iam_policy.msk_client.name
}

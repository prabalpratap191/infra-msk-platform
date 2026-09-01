# ============================================================================
# Terraform Outputs
# ============================================================================

# ============================================================================
# Networking Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = module.networking.nat_gateway_ips
}

# ============================================================================
# Kafka EC2 Outputs
# ============================================================================

output "kafka_instance_ids" {
  description = "List of Kafka EC2 instance IDs"
  value       = module.kafka_ec2.kafka_instance_ids
}

output "kafka_private_ips" {
  description = "List of Kafka broker private IPs"
  value       = module.kafka_ec2.kafka_private_ips
}

output "kafka_public_ips" {
  description = "List of Kafka broker public IPs (if assigned)"
  value       = module.kafka_ec2.kafka_public_ips
}

output "kafka_broker_endpoints" {
  description = "Kafka broker endpoints for internal use"
  value       = module.kafka_ec2.kafka_broker_endpoints
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "kafka_security_group_id" {
  description = "ID of Kafka security group"
  value       = module.security_group.kafka_sg_id
}

# ============================================================================
# Route53 Outputs
# ============================================================================

output "route53_zone_id" {
  description = "ID of Route53 private hosted zone"
  value       = module.route53.zone_id
}

output "route53_zone_name" {
  description = "Name of Route53 private hosted zone"
  value       = module.route53.zone_name
}

output "kafka_dns_records" {
  description = "Kafka DNS records"
  value       = module.route53.kafka_dns_records
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (for application configuration)"
  value       = module.route53.kafka_bootstrap_servers
}

# ============================================================================
# Kafka Topics Outputs
# ============================================================================

output "kafka_topics" {
  description = "List of created Kafka topics"
  value       = var.kafka_topics[*].name
}

# ============================================================================
# SSH Key Outputs
# ============================================================================

output "ssh_key_name" {
  description = "Name of SSH key pair"
  value       = aws_key_pair.kafka_key.key_name
}

output "ssh_private_key_path" {
  description = "Path to SSH private key file"
  value       = local_file.private_key.filename
  sensitive   = true
}

# ============================================================================
# Monitoring Outputs
# ============================================================================

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = module.monitoring.cloudwatch_log_group
}

# ============================================================================
# Connection Information
# ============================================================================

output "kafka_connection_details" {
  description = "Kafka connection details for applications"
  value = {
    bootstrap_servers_internal = module.route53.kafka_bootstrap_servers
    bootstrap_servers_external = var.enable_public_access ? "${var.kafka_public_dns}:9094" : "Not enabled"
    security_protocol          = "PLAINTEXT"
    topics                     = var.kafka_topics[*].name
  }
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to Kafka brokers"
  value = [
    for i, ip in module.kafka_ec2.kafka_public_ips :
    "ssh -i ${local_file.private_key.filename} ec2-user@${ip}"
  ]
}

# ============================================================================
# Quick Start Commands
# ============================================================================

output "quick_start_commands" {
  description = "Quick start commands for Kafka operations"
  value = <<-EOT
    
    ========================================
    KAFKA CLUSTER QUICK START
    ========================================
    
    Bootstrap Servers (Internal): ${module.route53.kafka_bootstrap_servers}
    ${var.enable_public_access ? "Bootstrap Servers (External): ${var.kafka_public_dns}:9094" : ""}
    
    Test from EKS:
    kubectl run kafka-test --rm -i --tty --image confluentinc/cp-kafka:latest -- \
      kafka-broker-api-versions --bootstrap-server ${module.route53.kafka_bootstrap_servers}
    
    List Topics:
    kubectl run kafka-test --rm -i --tty --image confluentinc/cp-kafka:latest -- \
      kafka-topics --bootstrap-server ${module.route53.kafka_bootstrap_servers} --list
    
    Produce Test Message:
    kubectl run kafka-test --rm -i --tty --image confluentinc/cp-kafka:latest -- \
      kafka-console-producer --bootstrap-server ${module.route53.kafka_bootstrap_servers} --topic customer-events
    
    Consume Test Message:
    kubectl run kafka-test --rm -i --tty --image confluentinc/cp-kafka:latest -- \
      kafka-console-consumer --bootstrap-server ${module.route53.kafka_bootstrap_servers} --topic customer-events --from-beginning
    
    SSH to Kafka Broker:
    ${module.kafka_ec2.kafka_public_ips[0] != "" ? "ssh -i ${local_file.private_key.filename} ec2-user@${module.kafka_ec2.kafka_public_ips[0]}" : "Public IPs not assigned"}
    
    ========================================
  EOT
}

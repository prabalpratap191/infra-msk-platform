# Forward all outputs from root module

output "vpc_id" {
  value = module.kafka_infrastructure.vpc_id
}

output "kafka_instance_ids" {
  value = module.kafka_infrastructure.kafka_instance_ids
}

output "kafka_private_ips" {
  value = module.kafka_infrastructure.kafka_private_ips
}

output "kafka_public_ips" {
  value = module.kafka_infrastructure.kafka_public_ips
}

output "kafka_bootstrap_servers" {
  value = module.kafka_infrastructure.kafka_bootstrap_servers
}

output "kafka_connection_details" {
  value = module.kafka_infrastructure.kafka_connection_details
}

output "ssh_connection_commands" {
  value = module.kafka_infrastructure.ssh_connection_commands
}

output "quick_start_commands" {
  value = module.kafka_infrastructure.quick_start_commands
}

output "topics_config_file" {
  description = "Path to topics configuration file"
  value       = local_file.topics_config.filename
}

output "client_config_file" {
  description = "Path to Kafka client configuration file"
  value       = local_file.client_config.filename
}

output "create_topics_script" {
  description = "Path to topic creation script"
  value       = local_file.create_topics_script.filename
}

output "topics_list" {
  description = "List of topic names"
  value       = [for topic in var.kafka_topics : topic.name]
}

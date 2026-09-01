# ============================================================================
# Kafka Topics Configuration Module
# ============================================================================
# Note: This module generates configuration files for topic creation.
# Actual topics are created via scripts post-deployment.
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Generate topic configuration as JSON
  topics_config = {
    for topic in var.kafka_topics :
    topic.name => {
      name               = topic.name
      partitions         = topic.partitions
      replication_factor = topic.replication_factor
      config             = topic.config
    }
  }
}

# ============================================================================
# Generate Topic Configuration File
# ============================================================================

resource "local_file" "topics_config" {
  content = jsonencode({
    cluster_arn       = var.cluster_arn
    bootstrap_brokers = var.bootstrap_brokers
    topics            = local.topics_config
  })
  
  filename = "${path.root}/../scripts/topics-config.json"
}

# ============================================================================
# Generate Kafka Client Configuration
# ============================================================================

resource "local_file" "client_config" {
  content = <<-EOT
    security.protocol=SASL_SSL
    sasl.mechanism=AWS_MSK_IAM
    sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
    sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
  EOT
  
  filename = "${path.root}/../scripts/client.properties"
}

# ============================================================================
# Generate Topic Creation Script
# ============================================================================

resource "local_file" "create_topics_script" {
  content = <<-EOT
    #!/bin/bash
    # Auto-generated script for creating Kafka topics
    
    set -e
    
    BOOTSTRAP_BROKERS="${var.bootstrap_brokers}"
    CONFIG_FILE="client.properties"
    
    echo "Creating Kafka topics on MSK cluster..."
    echo "Bootstrap Servers: $BOOTSTRAP_BROKERS"
    echo ""
    
    %{for topic in var.kafka_topics~}
    echo "Creating topic: ${topic.name}"
    kafka-topics.sh --bootstrap-server $BOOTSTRAP_BROKERS \
      --command-config $CONFIG_FILE \
      --create \
      --topic ${topic.name} \
      --partitions ${topic.partitions} \
      --replication-factor ${topic.replication_factor} \
      --config min.insync.replicas=${lookup(topic.config, "min.insync.replicas", "2")} \
      --config retention.ms=${lookup(topic.config, "retention.ms", "604800000")} \
      --config cleanup.policy=${lookup(topic.config, "cleanup.policy", "delete")} \
      --if-not-exists
    
    echo "Topic ${topic.name} created successfully"
    echo ""
    %{endfor~}
    
    echo "All topics created successfully!"
    echo ""
    echo "Listing all topics:"
    kafka-topics.sh --bootstrap-server $BOOTSTRAP_BROKERS \
      --command-config $CONFIG_FILE \
      --list
  EOT
  
  filename        = "${path.root}/../scripts/create-kafka-topics.sh"
  file_permission = "0755"
}

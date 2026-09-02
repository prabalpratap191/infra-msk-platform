#!/bin/bash

################################################################################
# Kafka Setup Script for EC2
# This script creates Kafka configuration and starts Kafka using Docker Compose
################################################################################

set -e

# Accept parameters
PRIVATE_IP=$1
PUBLIC_IP=$2
KAFKA_BROKER_ID=${3:-1}
KAFKA_CLUSTER_NAME=${4:-kafka-cluster-dev}

LOG_FILE="/var/log/kafka-setup.log"

echo "====================================" | tee -a $LOG_FILE
echo "Kafka Setup Script" | tee -a $LOG_FILE
echo "Date: $(date)" | tee -a $LOG_FILE
echo "Private IP: $PRIVATE_IP" | tee -a $LOG_FILE
echo "Public IP: $PUBLIC_IP" | tee -a $LOG_FILE
echo "Broker ID: $KAFKA_BROKER_ID" | tee -a $LOG_FILE
echo "Cluster Name: $KAFKA_CLUSTER_NAME" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

# Create Kafka directory structure
echo "[1/3] Creating Kafka directory structure..." | tee -a $LOG_FILE
sudo mkdir -p /opt/kafka/data
sudo chown -R ec2-user:ec2-user /opt/kafka

# Create Docker Compose file
echo "[2/3] Creating docker-compose.yml..." | tee -a $LOG_FILE
cat > /opt/kafka/docker-compose.yml << EOF
version: '3.8'

services:
  kafka:
    image: bitnami/kafka:latest
    container_name: kafka-server
    restart: always
    ports:
      - "9092:9092"
      - "9094:9094"
    environment:
      # KRaft settings (without Zookeeper)
      - KAFKA_CFG_NODE_ID=$KAFKA_BROKER_ID
      - KAFKA_CFG_PROCESS_ROLES=broker,controller
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=$KAFKA_BROKER_ID@kafka:9093
      
      # Cluster configuration
      - KAFKA_KRAFT_CLUSTER_ID=$KAFKA_CLUSTER_NAME
      
      # Listeners
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://$PRIVATE_IP:9092,EXTERNAL://$PUBLIC_IP:9094
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,EXTERNAL:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      
      # Broker settings
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true
      - KAFKA_CFG_LOG_RETENTION_HOURS=168
      - KAFKA_CFG_LOG_SEGMENT_BYTES=1073741824
      - KAFKA_CFG_LOG_RETENTION_CHECK_INTERVAL_MS=300000
      - KAFKA_CFG_NUM_PARTITIONS=3
      - KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=1
      
      # Performance tuning
      - KAFKA_HEAP_OPTS=-Xmx2G -Xms2G
    volumes:
      - /opt/kafka/data:/bitnami/kafka
    networks:
      - kafka-network
    healthcheck:
      test: ["CMD-SHELL", "kafka-broker-api-versions.sh --bootstrap-server localhost:9092 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

networks:
  kafka-network:
    driver: bridge
EOF

# Start Kafka
echo "[3/3] Starting Kafka..." | tee -a $LOG_FILE
cd /opt/kafka
sudo docker compose up -d 2>&1 | tee -a $LOG_FILE

echo "====================================" | tee -a $LOG_FILE
echo "✓ Kafka setup completed successfully" | tee -a $LOG_FILE
echo "Kafka is starting..." | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

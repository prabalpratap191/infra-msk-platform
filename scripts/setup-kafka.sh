#!/bin/bash

################################################################################
# Kafka Setup Script for EC2
################################################################################

set -e

PRIVATE_IP=$1
PUBLIC_IP=$2
KAFKA_BROKER_ID=${3:-1}
KAFKA_CLUSTER_NAME=${4:-kafka-cluster-dev}

LOG_FILE="/home/ec2-user/kafka-setup.log"

echo "====================================" | tee -a $LOG_FILE
echo "Kafka Setup Script" | tee -a $LOG_FILE
echo "Date: $(date)" | tee -a $LOG_FILE
echo "Private IP: $PRIVATE_IP" | tee -a $LOG_FILE
echo "Public IP: $PUBLIC_IP" | tee -a $LOG_FILE
echo "Broker ID: $KAFKA_BROKER_ID" | tee -a $LOG_FILE
echo "Cluster Name: $KAFKA_CLUSTER_NAME" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE



echo "[1/5] Creating Kafka directories..." | tee -a $LOG_FILE

sudo mkdir -p /opt/kafka/data
sudo chown -R ec2-user:ec2-user /opt/kafka

echo "[2/5] Creating docker-compose.yml..." | tee -a $LOG_FILE

cat > /opt/kafka/docker-compose.yml <<EOF
services:
  kafka:
    image: apache/kafka:3.9.0
    container_name: kafka-server
    restart: unless-stopped

    ports:
      - "9092:9092"

    environment:
      KAFKA_NODE_ID: ${KAFKA_BROKER_ID}

      KAFKA_PROCESS_ROLES: broker,controller

      KAFKA_CONTROLLER_QUORUM_VOTERS: ${KAFKA_BROKER_ID}@localhost:9093

      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093

      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${PUBLIC_IP}:9092

      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT

      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER

      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT

      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk

    volumes:
      - /opt/kafka/data:/var/lib/kafka/data
EOF


echo "[3/5] Kafka already running. Skipping installation..." | tee -a $LOG_FILE
if docker ps --format '{{.Names}}' | grep -q '^kafka-server$'; then
    echo "Kafka already running. Skipping installation."
    exit 0
fi

echo "[4/5] Starting Kafka..." | tee -a $LOG_FILE

cd /opt/kafka

sudo docker compose down || true
sudo docker compose pull
sudo docker compose up -d

echo "Waiting for Kafka startup..." | tee -a $LOG_FILE

sleep 60

echo "[5/5] Verifying Kafka..." | tee -a $LOG_FILE

sudo docker ps

sudo docker ps | grep kafka-server

echo "====================================" | tee -a $LOG_FILE
echo "✓ Kafka Started Successfully" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

echo "Bootstrap Server:"
echo "${PUBLIC_IP}:9092"
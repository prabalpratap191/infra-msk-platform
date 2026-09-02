#!/bin/bash
set -e

# Log file for debugging
LOG_FILE="/var/log/kafka-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=================================="
echo "Starting Kafka EC2 Setup"
echo "Date: $(date)"
echo "=================================="

# Update system
echo "[1/7] Updating system packages..."
yum update -y

# Install Docker
echo "[2/7] Installing Docker..."
yum install -y docker

# Start and enable Docker
echo "[3/7] Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Verify Docker installation
echo "[4/7] Verifying Docker installation..."
docker --version

# Install Docker Compose
echo "[5/7] Installing Docker Compose..."
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# Verify Docker Compose installation
echo "[6/7] Verifying Docker Compose installation..."
docker compose version

# Create Kafka directory
echo "[7/7] Creating Kafka directory structure..."
mkdir -p /opt/kafka
mkdir -p /opt/kafka/data
chown -R ec2-user:ec2-user /opt/kafka

# Get instance private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Get instance public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Private IP: $PRIVATE_IP"
echo "Public IP: $PUBLIC_IP"

# Create Docker Compose file
echo "Creating docker-compose.yml..."
cat > /opt/kafka/docker-compose.yml << 'EOF'
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
      - KAFKA_CFG_NODE_ID=${kafka_broker_id}
      - KAFKA_CFG_PROCESS_ROLES=broker,controller
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=${kafka_broker_id}@kafka:9093
      
      # Cluster configuration
      - KAFKA_KRAFT_CLUSTER_ID=${kafka_cluster_name}
      
      # Listeners
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://PRIVATE_IP_PLACEHOLDER:9092,EXTERNAL://PUBLIC_IP_PLACEHOLDER:9094
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

# Replace IP placeholders in docker-compose.yml
sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /opt/kafka/docker-compose.yml
sed -i "s/PUBLIC_IP_PLACEHOLDER/$PUBLIC_IP/g" /opt/kafka/docker-compose.yml
sed -i "s/\${kafka_broker_id}/${kafka_broker_id}/g" /opt/kafka/docker-compose.yml
sed -i "s/\${kafka_cluster_name}/${kafka_cluster_name}/g" /opt/kafka/docker-compose.yml

# Set ownership
chown -R ec2-user:ec2-user /opt/kafka

echo "=================================="
echo "Kafka EC2 Setup Completed"
echo "Docker and Docker Compose installed"
echo "Kafka configuration created"
echo "Run 'docker compose up -d' in /opt/kafka to start Kafka"
echo "=================================="

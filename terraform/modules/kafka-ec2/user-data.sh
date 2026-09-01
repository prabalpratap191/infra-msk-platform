#!/bin/bash

# ============================================================================
# Kafka EC2 User Data Script
# Automated installation of Docker, Docker Compose, and Kafka
# ============================================================================

set -e

# ============================================================================
# Variables
# ============================================================================

BROKER_ID="${broker_id}"
KAFKA_VERSION="${kafka_version}"
CLUSTER_ID="${cluster_id}"
KAFKA_HEAP_OPTS="${kafka_heap_opts}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
KAFKA_PUBLIC_DNS="${kafka_public_dns}"
BROKER_PRIVATE_IP="${broker_private_ip}"
KAFKA_PRIVATE_IPS='${kafka_private_ips}'

LOG_FILE="/var/log/kafka-setup.log"

# ============================================================================
# Logging Function
# ============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "Starting Kafka Broker Setup"
log "Broker ID: $BROKER_ID"
log "Cluster ID: $CLUSTER_ID"
log "========================================"

# ============================================================================
# System Updates
# ============================================================================

log "Updating system packages..."
yum update -y >> "$LOG_FILE" 2>&1

log "Installing essential packages..."
yum install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    vim \
    htop \
    nc \
    telnet >> "$LOG_FILE" 2>&1

# ============================================================================
# Docker Installation
# ============================================================================

log "Installing Docker..."
yum install -y docker >> "$LOG_FILE" 2>&1

log "Starting Docker service..."
systemctl start docker
systemctl enable docker

log "Adding ec2-user to docker group..."
usermod -aG docker ec2-user

# ============================================================================
# Docker Compose Installation
# ============================================================================

log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.5"
curl -L "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ============================================================================
# CloudWatch Agent Installation
# ============================================================================

log "Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm -f ./amazon-cloudwatch-agent.rpm

# ============================================================================
# Create Kafka Directories
# ============================================================================

log "Creating Kafka directories..."
mkdir -p /opt/kafka
mkdir -p /opt/kafka/data
mkdir -p /opt/kafka/logs
mkdir -p /opt/kafka/config
mkdir -p /opt/monitoring

chown -R ec2-user:ec2-user /opt/kafka
chown -R ec2-user:ec2-user /opt/monitoring

# ============================================================================
# Generate Kafka Docker Compose
# ============================================================================

log "Generating Kafka Docker Compose configuration..."

cat > /opt/kafka/docker-compose.yml <<'COMPOSE_EOF'
version: '3.8'

services:
  kafka:
    image: bitnami/kafka:${KAFKA_VERSION}
    container_name: kafka-${BROKER_ID}
    hostname: kafka-${BROKER_ID}
    restart: unless-stopped
    ports:
      - "9092:9092"
      - "9093:9093"
      - "9094:9094"
    environment:
      # KRaft settings
      KAFKA_ENABLE_KRAFT: "yes"
      KAFKA_CFG_PROCESS_ROLES: "broker,controller"
      KAFKA_CFG_NODE_ID: "${BROKER_ID}"
      KAFKA_KRAFT_CLUSTER_ID: "${CLUSTER_ID}"
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: "1@KAFKA_IP_1:9093,2@KAFKA_IP_2:9093,3@KAFKA_IP_3:9093"
      
      # Listeners
      KAFKA_CFG_LISTENERS: "PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094"
      KAFKA_CFG_ADVERTISED_LISTENERS: "PLAINTEXT://${BROKER_PRIVATE_IP}:9092,EXTERNAL://${KAFKA_PUBLIC_DNS}:9094"
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT"
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_CFG_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      
      # Replication settings
      KAFKA_CFG_DEFAULT_REPLICATION_FACTOR: "3"
      KAFKA_CFG_MIN_INSYNC_REPLICAS: "2"
      KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR: "3"
      KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: "3"
      KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR: "2"
      
      # Performance settings
      KAFKA_CFG_NUM_NETWORK_THREADS: "8"
      KAFKA_CFG_NUM_IO_THREADS: "8"
      KAFKA_CFG_SOCKET_SEND_BUFFER_BYTES: "102400"
      KAFKA_CFG_SOCKET_RECEIVE_BUFFER_BYTES: "102400"
      KAFKA_CFG_SOCKET_REQUEST_MAX_BYTES: "104857600"
      KAFKA_CFG_NUM_PARTITIONS: "6"
      KAFKA_CFG_LOG_RETENTION_HOURS: "168"
      KAFKA_CFG_LOG_SEGMENT_BYTES: "1073741824"
      KAFKA_CFG_LOG_RETENTION_CHECK_INTERVAL_MS: "300000"
      
      # Auto topic creation
      KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE: "false"
      
      # JVM settings
      KAFKA_HEAP_OPTS: "${KAFKA_HEAP_OPTS}"
      KAFKA_JVM_PERFORMANCE_OPTS: "-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16M -XX:MinMetaspaceFreeRatio=50 -XX:MaxMetaspaceFreeRatio=80"
      
      # Logging
      KAFKA_CFG_LOG4J_ROOT_LOGLEVEL: "INFO"
      
      # Monitoring
      KAFKA_JMX_PORT: "9999"
      KAFKA_JMX_OPTS: "-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=${BROKER_PRIVATE_IP}"
      
    volumes:
      - /opt/kafka/data:/bitnami/kafka/data
      - /opt/kafka/logs:/opt/bitnami/kafka/logs
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
COMPOSE_EOF

# Replace IP placeholders
KAFKA_IPS=$(echo "$KAFKA_PRIVATE_IPS" | jq -r '.[]')
KAFKA_IP_ARRAY=($KAFKA_IPS)

sed -i "s/KAFKA_IP_1/${KAFKA_IP_ARRAY[0]}/g" /opt/kafka/docker-compose.yml
sed -i "s/KAFKA_IP_2/${KAFKA_IP_ARRAY[1]}/g" /opt/kafka/docker-compose.yml
sed -i "s/KAFKA_IP_3/${KAFKA_IP_ARRAY[2]}/g" /opt/kafka/docker-compose.yml
sed -i "s/\${BROKER_ID}/$BROKER_ID/g" /opt/kafka/docker-compose.yml
sed -i "s/\${CLUSTER_ID}/$CLUSTER_ID/g" /opt/kafka/docker-compose.yml
sed -i "s/\${BROKER_PRIVATE_IP}/$BROKER_PRIVATE_IP/g" /opt/kafka/docker-compose.yml
sed -i "s/\${KAFKA_PUBLIC_DNS}/$KAFKA_PUBLIC_DNS/g" /opt/kafka/docker-compose.yml
sed -i "s/\${KAFKA_HEAP_OPTS}/$KAFKA_HEAP_OPTS/g" /opt/kafka/docker-compose.yml
sed -i "s/\${KAFKA_VERSION}/$KAFKA_VERSION/g" /opt/kafka/docker-compose.yml

# ============================================================================
# Start Kafka
# ============================================================================

log "Starting Kafka broker..."
cd /opt/kafka
docker-compose up -d >> "$LOG_FILE" 2>&1

# ============================================================================
# Wait for Kafka to be ready
# ============================================================================

log "Waiting for Kafka to be ready..."
sleep 30

for i in {1..30}; do
    if docker exec kafka-$BROKER_ID kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        log "Kafka broker is ready!"
        break
    fi
    log "Waiting for Kafka... (attempt $i/30)"
    sleep 10
done

# ============================================================================
# Install Monitoring (Prometheus Exporters)
# ============================================================================

log "Setting up monitoring exporters..."

cat > /opt/monitoring/docker-compose.yml <<'MONITORING_EOF'
version: '3.8'

services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    networks:
      - monitoring

  kafka-exporter:
    image: danielqsj/kafka-exporter:latest
    container_name: kafka-exporter
    restart: unless-stopped
    ports:
      - "9308:9308"
    command:
      - '--kafka.server=BROKER_PRIVATE_IP:9092'
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
MONITORING_EOF

sed -i "s/BROKER_PRIVATE_IP/$BROKER_PRIVATE_IP/g" /opt/monitoring/docker-compose.yml

cd /opt/monitoring
docker-compose up -d >> "$LOG_FILE" 2>&1

# ============================================================================
# Create Systemd Service for Auto-restart
# ============================================================================

log "Creating systemd service for Kafka auto-restart..."

cat > /etc/systemd/system/kafka.service <<'SERVICE_EOF'
[Unit]
Description=Kafka Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/kafka
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable kafka.service

log "Creating systemd service for monitoring auto-restart..."

cat > /etc/systemd/system/kafka-monitoring.service <<'SERVICE_EOF'
[Unit]
Description=Kafka Monitoring Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/monitoring
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable kafka-monitoring.service

# ============================================================================
# Setup Complete
# ============================================================================

log "========================================"
log "Kafka Broker Setup Complete!"
log "Broker ID: $BROKER_ID"
log "Private IP: $BROKER_PRIVATE_IP"
log "Cluster ID: $CLUSTER_ID"
log "========================================"

# Create completion marker
touch /var/log/kafka-setup-complete

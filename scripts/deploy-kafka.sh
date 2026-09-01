#!/bin/bash

# ============================================================================
# Kafka Deployment Script
# Deploys Kafka cluster using Docker Compose
# ============================================================================

set -e

LOG_FILE="/var/log/kafka-deploy.log"
KAFKA_DIR="/opt/kafka"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "Starting Kafka Deployment"
log "========================================"

# Check if Docker is running
log "Checking Docker status..."
if ! systemctl is-active --quiet docker; then
    log "ERROR: Docker is not running"
    exit 1
fi

# Navigate to Kafka directory
if [ ! -d "$KAFKA_DIR" ]; then
    log "ERROR: Kafka directory does not exist: $KAFKA_DIR"
    exit 1
fi

cd "$KAFKA_DIR"

# Pull Kafka image
log "Pulling Kafka Docker image..."
docker-compose pull >> "$LOG_FILE" 2>&1

# Stop existing containers (if any)
log "Stopping existing Kafka containers..."
docker-compose down >> "$LOG_FILE" 2>&1 || true

# Start Kafka
log "Starting Kafka broker..."
docker-compose up -d >> "$LOG_FILE" 2>&1

# Wait for Kafka to be ready
log "Waiting for Kafka to be ready..."
sleep 30

BROKER_ID=$(grep "BROKER_ID=" docker-compose.yml | cut -d'=' -f2 | tr -d '"' || echo "1")

for i in {1..30}; do
    if docker exec kafka-$BROKER_ID kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        log "Kafka broker is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        log "ERROR: Kafka failed to start within timeout"
        docker-compose logs >> "$LOG_FILE" 2>&1
        exit 1
    fi
    log "Waiting for Kafka... (attempt $i/30)"
    sleep 10
done

# Show container status
log "Kafka container status:"
docker-compose ps >> "$LOG_FILE" 2>&1

log "========================================"
log "Kafka Deployment Complete"
log "========================================"

#!/bin/bash

# ============================================================================
# Kafka Topics Creation Script
# Creates all required Kafka topics with proper configuration
# ============================================================================

set -e

LOG_FILE="/var/log/kafka-topics.log"
BOOTSTRAP_SERVER="localhost:9092"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get broker ID from environment or default to 1
BROKER_ID=${BROKER_ID:-1}
CONTAINER_NAME="kafka-$BROKER_ID"

log "========================================"
log "Starting Kafka Topics Creation"
log "Container: $CONTAINER_NAME"
log "========================================"

# Wait for Kafka to be ready
log "Verifying Kafka is ready..."
for i in {1..30}; do
    if docker exec $CONTAINER_NAME kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_SERVER > /dev/null 2>&1; then
        log "Kafka is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        log "ERROR: Kafka is not ready"
        exit 1
    fi
    log "Waiting for Kafka... (attempt $i/30)"
    sleep 5
done

# Define topics
declare -A TOPICS
TOPICS["customer-events"]=6
TOPICS["order-events"]=6
TOPICS["catalog-events"]=6
TOPICS["payment-events"]=6
TOPICS["notification-events"]=6
TOPICS["dead-letter-events"]=6
TOPICS["audit-events"]=6

# Create topics
for TOPIC in "${!TOPICS[@]}"; do
    PARTITIONS=${TOPICS[$TOPIC]}
    
    log "Checking if topic '$TOPIC' exists..."
    if docker exec $CONTAINER_NAME kafka-topics.sh \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --list 2>/dev/null | grep -q "^${TOPIC}$"; then
        log "Topic '$TOPIC' already exists, skipping..."
        continue
    fi
    
    log "Creating topic: $TOPIC (partitions: $PARTITIONS)"
    docker exec $CONTAINER_NAME kafka-topics.sh \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --create \
        --topic $TOPIC \
        --partitions $PARTITIONS \
        --replication-factor 3 \
        --config min.insync.replicas=2 \
        --config retention.ms=604800000 \
        --config segment.ms=86400000 \
        --config compression.type=producer >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Successfully created topic: $TOPIC"
    else
        log "ERROR: Failed to create topic: $TOPIC"
    fi
done

# List all topics
log "Listing all topics:"
docker exec $CONTAINER_NAME kafka-topics.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --list 2>&1 | tee -a "$LOG_FILE"

# Describe topics
log "Topic configurations:"
for TOPIC in "${!TOPICS[@]}"; do
    log "--- Topic: $TOPIC ---"
    docker exec $CONTAINER_NAME kafka-topics.sh \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --describe \
        --topic $TOPIC 2>&1 | tee -a "$LOG_FILE"
done

log "========================================"
log "Topics Creation Complete"
log "========================================"

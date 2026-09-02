#!/bin/bash
set -e

echo "=================================="
echo "Creating Kafka Topics"
echo "=================================="

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
sleep 30

# Topic configuration
PARTITIONS=3
REPLICATION_FACTOR=1
BOOTSTRAP_SERVER="localhost:9092"

# List of topics to create
TOPICS=(
    "customer-events"
    "order-events"
    "catalog-events"
    "payment-events"
    "inventory-events"
    "notification-events"
    "dead-letter-events"
)

# Create topics
for TOPIC in "${TOPICS[@]}"; do
    echo "Creating topic: $TOPIC"
    docker exec kafka-server kafka-topics.sh \
        --create \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $TOPIC \
        --partitions $PARTITIONS \
        --replication-factor $REPLICATION_FACTOR \
        --if-not-exists \
        --config retention.ms=604800000 \
        --config segment.ms=86400000 \
        --config compression.type=lz4
    
    echo "✓ Topic '$TOPIC' created successfully"
done

echo ""
echo "=================================="
echo "Listing all topics:"
echo "=================================="
docker exec kafka-server kafka-topics.sh \
    --list \
    --bootstrap-server $BOOTSTRAP_SERVER

echo ""
echo "=================================="
echo "Topic Details:"
echo "=================================="
for TOPIC in "${TOPICS[@]}"; do
    echo ""
    echo "Topic: $TOPIC"
    docker exec kafka-server kafka-topics.sh \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $TOPIC
done

echo ""
echo "=================================="
echo "All topics created successfully!"
echo "=================================="

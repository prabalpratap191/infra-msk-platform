#!/bin/bash
set -e

echo "=================================="
echo "Kafka Verification Test"
echo "=================================="

BOOTSTRAP_SERVER="localhost:9092"
TEST_TOPIC="customer-events"
TEST_MESSAGE="Hello Kafka"

# Check if Kafka container is running
echo "[1/4] Checking Kafka container status..."
if docker ps | grep -q kafka-server; then
    echo "✓ Kafka container is running"
else
    echo "✗ Kafka container is not running"
    exit 1
fi

# Wait for Kafka to be ready
echo "[2/4] Waiting for Kafka to be ready..."
sleep 10

# Produce a test message
echo "[3/4] Producing test message to topic '$TEST_TOPIC'..."
echo "$TEST_MESSAGE" | docker exec -i kafka-server kafka-console-producer.sh \
    --broker-list $BOOTSTRAP_SERVER \
    --topic $TEST_TOPIC

echo "✓ Message produced successfully"

# Consume the test message
echo "[4/4] Consuming test message from topic '$TEST_TOPIC'..."
CONSUMED_MESSAGE=$(docker exec kafka-server kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --topic $TEST_TOPIC \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 10000 2>/dev/null)

echo ""
echo "=================================="
echo "Verification Results:"
echo "=================================="
echo "Produced Message: $TEST_MESSAGE"
echo "Consumed Message: $CONSUMED_MESSAGE"

if [ "$CONSUMED_MESSAGE" = "$TEST_MESSAGE" ]; then
    echo ""
    echo "✓ VERIFICATION SUCCESSFUL"
    echo "Kafka is working correctly!"
    echo "=================================="
    exit 0
else
    echo ""
    echo "✗ VERIFICATION FAILED"
    echo "Messages do not match!"
    echo "=================================="
    exit 1
fi

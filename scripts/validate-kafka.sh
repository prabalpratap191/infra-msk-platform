#!/bin/bash

# ============================================================================
# Kafka Validation Script
# Validates Kafka cluster health and connectivity
# ============================================================================

set -e

BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-localhost:9092}"
BROKER_ID="${BROKER_ID:-1}"
CONTAINER_NAME="kafka-$BROKER_ID"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo "[INFO] $1"
}

echo "=========================================="
echo "Kafka Cluster Validation"
echo "=========================================="

# 1. Check Docker
info "Checking Docker service..."
if systemctl is-active --quiet docker; then
    pass "Docker service is running"
else
    fail "Docker service is not running"
fi

# 2. Check Kafka container
info "Checking Kafka container..."
if docker ps | grep -q "$CONTAINER_NAME"; then
    pass "Kafka container is running"
else
    fail "Kafka container is not running"
fi

# 3. Check Kafka connectivity
info "Checking Kafka broker connectivity..."
if docker exec $CONTAINER_NAME kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_SERVER > /dev/null 2>&1; then
    pass "Kafka broker is accessible"
else
    fail "Cannot connect to Kafka broker"
fi

# 4. Check cluster metadata
info "Fetching cluster metadata..."
METADATA=$(docker exec $CONTAINER_NAME kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)
if [ $? -eq 0 ]; then
    pass "Cluster metadata retrieved successfully"
else
    fail "Failed to retrieve cluster metadata"
fi

# 5. List topics
info "Listing Kafka topics..."
TOPICS=$(docker exec $CONTAINER_NAME kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list 2>/dev/null)
if [ $? -eq 0 ]; then
    TOPIC_COUNT=$(echo "$TOPICS" | wc -l)
    pass "Found $TOPIC_COUNT topics"
    echo "$TOPICS"
else
    fail "Failed to list topics"
fi

# 6. Check topic configuration
info "Validating required topics..."
REQUIRED_TOPICS=("customer-events" "order-events" "catalog-events" "payment-events" "notification-events" "dead-letter-events" "audit-events")
for topic in "${REQUIRED_TOPICS[@]}"; do
    if echo "$TOPICS" | grep -q "^$topic$"; then
        pass "Topic exists: $topic"
    else
        warn "Topic missing: $topic"
    fi
done

# 7. Test producer/consumer
info "Testing producer/consumer..."
TEST_TOPIC="test-topic-$(date +%s)"
TEST_MESSAGE="test-message-$(date +%s)"

# Create test topic
docker exec $CONTAINER_NAME kafka-topics.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --create --topic $TEST_TOPIC \
    --partitions 1 --replication-factor 1 > /dev/null 2>&1

# Produce message
echo "$TEST_MESSAGE" | docker exec -i $CONTAINER_NAME kafka-console-producer.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --topic $TEST_TOPIC > /dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "Producer test successful"
else
    fail "Producer test failed"
fi

# Consume message
CONSUMED=$(docker exec $CONTAINER_NAME kafka-console-consumer.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --topic $TEST_TOPIC \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 5000 2>/dev/null)

if echo "$CONSUMED" | grep -q "$TEST_MESSAGE"; then
    pass "Consumer test successful"
else
    fail "Consumer test failed"
fi

# Cleanup test topic
docker exec $CONTAINER_NAME kafka-topics.sh \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --delete --topic $TEST_TOPIC > /dev/null 2>&1

# 8. Check monitoring exporters
info "Checking monitoring exporters..."
if docker ps | grep -q "node-exporter"; then
    pass "Node Exporter is running"
else
    warn "Node Exporter is not running"
fi

if docker ps | grep -q "kafka-exporter"; then
    pass "Kafka Exporter is running"
else
    warn "Kafka Exporter is not running"
fi

echo "=========================================="
echo -e "${GREEN}Validation Complete - All Checks Passed${NC}"
echo "=========================================="

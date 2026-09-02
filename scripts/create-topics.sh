#!/bin/bash

set -e

echo "=================================="
echo "Kafka Topic Creation Script"
echo "=================================="

CONTAINER_NAME="kafka-server"
BOOTSTRAP_SERVER="localhost:9092"

PARTITIONS=3
REPLICATION_FACTOR=1

TOPICS=(
  "customer-events"
  "order-events"
  "catalog-events"
  "payment-events"
  "inventory-events"
  "notification-events"
  "dead-letter-events"
)

echo ""
echo "Waiting for Kafka broker..."

for i in {1..30}
do
    if sudo docker exec ${CONTAINER_NAME} \
       /opt/kafka/bin/kafka-topics.sh \
       --bootstrap-server ${BOOTSTRAP_SERVER} \
       --list >/dev/null 2>&1
    then
        echo "✓ Kafka is ready"
        break
    fi

    echo "Attempt $i/30 - Kafka not ready yet..."
    sleep 10
done

echo ""
echo "=================================="
echo "Creating Topics"
echo "=================================="

for TOPIC in "${TOPICS[@]}"
do

    if sudo docker exec ${CONTAINER_NAME} \
       /opt/kafka/bin/kafka-topics.sh \
       --bootstrap-server ${BOOTSTRAP_SERVER} \
       --list | grep -w "${TOPIC}" >/dev/null
    then
        echo "✓ Topic already exists: ${TOPIC}"
        continue
    fi

    echo "Creating topic: ${TOPIC}"

    sudo docker exec ${CONTAINER_NAME} \
       /opt/kafka/bin/kafka-topics.sh \
       --create \
       --bootstrap-server ${BOOTSTRAP_SERVER} \
       --topic ${TOPIC} \
       --partitions ${PARTITIONS} \
       --replication-factor ${REPLICATION_FACTOR}

    echo "✓ Created: ${TOPIC}"

done

echo ""
echo "=================================="
echo "Available Topics"
echo "=================================="

sudo docker exec ${CONTAINER_NAME} \
   /opt/kafka/bin/kafka-topics.sh \
   --bootstrap-server ${BOOTSTRAP_SERVER} \
   --list

echo ""
echo "=================================="
echo "Topic Details"
echo "=================================="

for TOPIC in "${TOPICS[@]}"
do
    echo ""
    echo "Topic: ${TOPIC}"

    sudo docker exec ${CONTAINER_NAME} \
       /opt/kafka/bin/kafka-topics.sh \
       --bootstrap-server ${BOOTSTRAP_SERVER} \
       --describe \
       --topic ${TOPIC}
done

echo ""
echo "=================================="
echo "Kafka Topic Creation Complete"
echo "=================================="
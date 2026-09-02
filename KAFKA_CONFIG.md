# Kafka Configuration Reference

Comprehensive guide to Kafka configuration for the EC2 deployment.

## Table of Contents

- [Broker Configuration](#broker-configuration)
- [Topic Configuration](#topic-configuration)
- [Performance Tuning](#performance-tuning)
- [Producer Configuration](#producer-configuration)
- [Consumer Configuration](#consumer-configuration)
- [Security Configuration](#security-configuration)
- [Monitoring Configuration](#monitoring-configuration)

---

## Broker Configuration

### KRaft Mode Settings

```properties
# Node Configuration
KAFKA_CFG_NODE_ID=1
KAFKA_CFG_PROCESS_ROLES=broker,controller
KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka:9093

# Cluster ID
KAFKA_KRAFT_CLUSTER_ID=kafka-cluster-dev
```

**Explanation**:
- `NODE_ID`: Unique identifier for this broker (1-1000)
- `PROCESS_ROLES`: Combined broker and controller (KRaft mode)
- `CONTROLLER_QUORUM_VOTERS`: List of controller nodes
- `CLUSTER_ID`: Unique cluster identifier

### Listener Configuration

```properties
# Listeners
KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094

# Advertised Listeners (updated with actual IPs)
KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://<PRIVATE_IP>:9092,EXTERNAL://<PUBLIC_IP>:9094

# Security Protocol Map
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,EXTERNAL:PLAINTEXT,PLAINTEXT:PLAINTEXT

# Controller Listener
KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
```

**Listener Types**:
- **PLAINTEXT (9092)**: Internal VPC communication
- **CONTROLLER (9093)**: Controller communication (KRaft)
- **EXTERNAL (9094)**: External/public access

**Use Cases**:
- Use `PLAINTEXT` for Spring Boot apps in same VPC
- Use `EXTERNAL` for development/testing from outside VPC
- `CONTROLLER` is for internal Kafka cluster coordination

### Storage Configuration

```properties
# Log Directory
KAFKA_CFG_LOG_DIRS=/bitnami/kafka/data

# Log Retention
KAFKA_CFG_LOG_RETENTION_HOURS=168  # 7 days
KAFKA_CFG_LOG_RETENTION_BYTES=-1   # No size limit

# Log Segment
KAFKA_CFG_LOG_SEGMENT_BYTES=1073741824  # 1GB
KAFKA_CFG_LOG_RETENTION_CHECK_INTERVAL_MS=300000  # 5 minutes
```

**Recommendations**:
- **Dev/Test**: 24-168 hours retention
- **Production**: 168-720 hours (7-30 days)
- **High Volume**: Set `LOG_RETENTION_BYTES` to limit disk usage

### Topic Defaults

```properties
# Default Partitions
KAFKA_CFG_NUM_PARTITIONS=3

# Default Replication Factor
KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=1

# Auto Create Topics
KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true

# Min In-Sync Replicas
KAFKA_CFG_MIN_INSYNC_REPLICAS=1
```

**Production Settings**:
- `NUM_PARTITIONS`: 3-12 (based on throughput)
- `REPLICATION_FACTOR`: 3 (for production clusters)
- `AUTO_CREATE_TOPICS_ENABLE`: false (explicitly create topics)
- `MIN_INSYNC_REPLICAS`: 2 (for durability)

---

## Topic Configuration

### Created Topics

| Topic | Partitions | Replication | Retention | Use Case |
|-------|-----------|-------------|-----------|----------|
| customer-events | 3 | 1 | 7 days | Customer lifecycle events |
| order-events | 3 | 1 | 7 days | Order processing events |
| catalog-events | 3 | 1 | 7 days | Product catalog changes |
| payment-events | 3 | 1 | 7 days | Payment transactions |
| inventory-events | 3 | 1 | 7 days | Inventory updates |
| notification-events | 3 | 1 | 7 days | User notifications |
| dead-letter-events | 3 | 1 | 30 days | Failed message processing |

### Topic Configuration Parameters

```bash
# Compression
--config compression.type=lz4

# Retention
--config retention.ms=604800000  # 7 days
--config segment.ms=86400000     # 1 day

# Cleanup Policy
--config cleanup.policy=delete   # or "compact" for log compaction

# Max Message Size
--config max.message.bytes=1048576  # 1MB

# Min In-Sync Replicas
--config min.insync.replicas=1
```

### Creating Custom Topics

```bash
# High-throughput topic
docker exec kafka-server kafka-topics.sh \
  --create \
  --bootstrap-server localhost:9092 \
  --topic high-volume-events \
  --partitions 12 \
  --replication-factor 1 \
  --config retention.ms=86400000 \
  --config compression.type=snappy \
  --config segment.ms=3600000

# Compacted topic (for state store)
docker exec kafka-server kafka-topics.sh \
  --create \
  --bootstrap-server localhost:9092 \
  --topic user-state \
  --partitions 6 \
  --replication-factor 1 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.5 \
  --config delete.retention.ms=86400000
```

---

## Performance Tuning

### Memory Configuration

```properties
# Heap Size (docker-compose.yml)
KAFKA_HEAP_OPTS=-Xmx2G -Xms2G
```

**Recommendations by Instance Type**:

| Instance Type | Heap Size | Available RAM |
|---------------|-----------|---------------|
| t3.small | 1G | 2 GB |
| t3.medium | 2G | 4 GB |
| t3.large | 4G | 8 GB |
| m5.xlarge | 8G | 16 GB |
| m5.2xlarge | 12G | 32 GB |

**Formula**: Heap = 50-70% of available RAM, leave rest for OS page cache

### Network Configuration

```properties
# Socket Settings
KAFKA_CFG_SOCKET_SEND_BUFFER_BYTES=102400
KAFKA_CFG_SOCKET_RECEIVE_BUFFER_BYTES=102400
KAFKA_CFG_SOCKET_REQUEST_MAX_BYTES=104857600  # 100MB

# Network Threads
KAFKA_CFG_NUM_NETWORK_THREADS=3
KAFKA_CFG_NUM_IO_THREADS=8
```

### Disk Optimization

```properties
# Background Threads
KAFKA_CFG_BACKGROUND_THREADS=10

# Log Flush Settings (use OS page cache)
KAFKA_CFG_LOG_FLUSH_INTERVAL_MESSAGES=10000
KAFKA_CFG_LOG_FLUSH_INTERVAL_MS=1000
```

**Best Practice**: Let OS handle flushing for better performance

### Compression

```properties
# Broker-side compression
KAFKA_CFG_COMPRESSION_TYPE=producer  # Honor producer compression
```

**Compression Types**:
- **lz4**: Best balance (recommended)
- **snappy**: Fast, good compression
- **gzip**: High compression, slower
- **zstd**: Best compression, moderate speed
- **none**: No compression

---

## Producer Configuration

### Spring Boot Producer

```yaml
spring:
  kafka:
    producer:
      # Serialization
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      
      # Durability
      acks: all  # 0, 1, or all
      
      # Retries
      retries: 3
      
      # Batching
      batch-size: 16384  # 16KB
      linger-ms: 10      # Wait 10ms to batch
      buffer-memory: 33554432  # 32MB
      
      # Compression
      compression-type: lz4
      
      # Idempotence
      enable-idempotence: true
      
      # Additional properties
      properties:
        max.in.flight.requests.per.connection: 5
        max.request.size: 1048576  # 1MB
        request.timeout.ms: 30000
```

### Producer Settings Explained

**acks** (Acknowledgment Mode):
- `0`: Fire and forget (fastest, no durability)
- `1`: Leader acknowledgment (balanced)
- `all`: All replicas acknowledge (slowest, most durable)

**batch-size**: Bytes to batch before sending
- Larger = better throughput, higher latency
- Smaller = lower latency, lower throughput
- Recommended: 16-64KB

**linger-ms**: Time to wait for batching
- `0`: Send immediately
- `10-100ms`: Good for batching
- Higher = better compression/batching

**compression-type**:
- `lz4`: Recommended for most cases
- `snappy`: Low CPU overhead
- `gzip`: High compression ratio

---

## Consumer Configuration

### Spring Boot Consumer

```yaml
spring:
  kafka:
    consumer:
      # Group Management
      group-id: ${spring.application.name}
      
      # Deserialization
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      
      # Offset Management
      auto-offset-reset: earliest  # earliest, latest, none
      enable-auto-commit: false    # Use manual commit
      
      # Polling
      max-poll-records: 500
      max-poll-interval-ms: 300000  # 5 minutes
      
      # Fetch Settings
      fetch-min-size: 1
      fetch-max-wait: 500
      
      # Session Management
      heartbeat-interval: 3000      # 3 seconds
      session-timeout: 30000        # 30 seconds
      
      # Properties
      properties:
        spring.json.trusted.packages: "*"
        isolation.level: read_committed
```

### Consumer Settings Explained

**auto-offset-reset**:
- `earliest`: Start from beginning
- `latest`: Only new messages
- `none`: Throw exception if no offset

**enable-auto-commit**:
- `true`: Auto commit (at-most-once)
- `false`: Manual commit (at-least-once or exactly-once)

**max-poll-records**: Messages per poll
- Lower = better latency, more polls
- Higher = better throughput, risk timeout
- Recommended: 100-500

**Session Timeout**:
- How long before consumer is considered dead
- Increase for slow processing
- Default: 10-30 seconds

### Consumer Groups

```yaml
# Different consumer groups for same topic
spring:
  kafka:
    consumer:
      # Analytics service
      group-id: analytics-service
      
      # Notification service
      group-id: notification-service
      
      # Audit service
      group-id: audit-service
```

**Use Case**: Multiple services consuming same events independently

---

## Security Configuration

### SSL/TLS Configuration

```yaml
# docker-compose.yml
environment:
  # SSL Settings
  - KAFKA_CFG_SSL_KEYSTORE_LOCATION=/certs/kafka.keystore.jks
  - KAFKA_CFG_SSL_KEYSTORE_PASSWORD=changeit
  - KAFKA_CFG_SSL_KEY_PASSWORD=changeit
  - KAFKA_CFG_SSL_TRUSTSTORE_LOCATION=/certs/kafka.truststore.jks
  - KAFKA_CFG_SSL_TRUSTSTORE_PASSWORD=changeit
  
  # Listener Security
  - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:SSL,EXTERNAL:SSL
  
volumes:
  - ./certs:/certs
```

### SASL Authentication

```yaml
environment:
  # SASL/PLAIN
  - KAFKA_CFG_SASL_ENABLED_MECHANISMS=PLAIN
  - KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL=PLAIN
  - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:SASL_PLAINTEXT
  
  # Users
  - KAFKA_CLIENT_USERS=user1,user2
  - KAFKA_CLIENT_PASSWORDS=password1,password2
```

### ACL (Access Control Lists)

```bash
# Enable ACLs
KAFKA_CFG_AUTHORIZER_CLASS_NAME=kafka.security.authorizer.AclAuthorizer
KAFKA_CFG_ALLOW_EVERYONE_IF_NO_ACL_FOUND=false

# Create ACL
docker exec kafka-server kafka-acls.sh \
  --bootstrap-server localhost:9092 \
  --add \
  --allow-principal User:app-user \
  --operation Read \
  --operation Write \
  --topic customer-events
```

---

## Monitoring Configuration

### JMX Metrics

```yaml
# docker-compose.yml
environment:
  - KAFKA_JMX_PORT=9999
  - KAFKA_JMX_HOSTNAME=localhost
  - KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote \
                   -Dcom.sun.management.jmxremote.authenticate=false \
                   -Dcom.sun.management.jmxremote.ssl=false

ports:
  - "9999:9999"
```

### Key Metrics to Monitor

**Broker Metrics**:
- `MessagesInPerSec`: Incoming message rate
- `BytesInPerSec`: Incoming bytes rate
- `BytesOutPerSec`: Outgoing bytes rate
- `UnderReplicatedPartitions`: Replication lag
- `ActiveControllerCount`: Controller status

**Topic Metrics**:
- `PartitionCount`: Number of partitions
- `LogEndOffset`: Latest offset
- `LogStartOffset`: Oldest offset

**Consumer Metrics**:
- `ConsumerLag`: Messages behind
- `RecordsConsumedRate`: Consumption rate
- `CommitLatency`: Offset commit time

### Prometheus + Grafana

```yaml
# Add JMX exporter
services:
  kafka-exporter:
    image: danielqsj/kafka-exporter
    ports:
      - "9308:9308"
    command:
      - '--kafka.server=kafka:9092'
```

---

## Best Practices Summary

### Development
- Single broker OK
- `acks=1` for producers
- Auto-create topics enabled
- Short retention (1-7 days)
- Public IP access for testing

### Production
- Multi-broker cluster (3+ brokers)
- `acks=all` for producers
- Explicit topic creation
- Longer retention (7-30 days)
- VPC-only access
- SSL/TLS enabled
- SASL authentication
- Monitoring enabled
- Regular backups
- Multi-AZ deployment

---

For more information, refer to:
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Bitnami Kafka Image](https://github.com/bitnami/containers/tree/main/bitnami/kafka)
- [Spring Kafka Documentation](https://spring.io/projects/spring-kafka)

# Kafka EC2 Platform - Quick Reference Guide

Quick commands and configurations for daily operations.

## 🚀 Quick Start Commands

### Deploy with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Connect to EC2

```bash
# Get IP from Terraform output
EC2_IP=$(cd terraform && terraform output -raw ec2_public_ip)

# SSH to instance
ssh -i kafka-ec2-key.pem ec2-user@$EC2_IP
```

### Start Kafka

```bash
cd /opt/kafka
docker compose up -d

# Check status
docker compose ps
docker logs -f kafka-server
```

---

## 📝 Essential Configuration

### Terraform Variables (terraform.tfvars)

```hcl
aws_region       = "us-east-1"
vpc_id           = "vpc-xxxxx"     # Required
subnet_id        = "subnet-xxxxx"  # Required
private_vpc_cidr = "10.0.0.0/16"  # Required
admin_ip_address = "YOUR.IP.HERE" # Required
key_name         = "your-key-name" # Required
```

### Spring Boot Configuration

```yaml
spring:
  kafka:
    bootstrap-servers: <EC2_PRIVATE_IP>:9092
    consumer:
      group-id: ${spring.application.name}
    producer:
      acks: all
```

### Docker Compose Kafka Ports

- **9092**: Internal VPC (use this for Spring Boot)
- **9094**: External/Public (for dev/testing)
- **9093**: Controller (internal only)

---

## 🔧 Common Operations

### Topic Management

```bash
# List topics
docker exec kafka-server kafka-topics.sh \
  --list --bootstrap-server localhost:9092

# Create topic
docker exec kafka-server kafka-topics.sh \
  --create --bootstrap-server localhost:9092 \
  --topic my-topic --partitions 3 --replication-factor 1

# Describe topic
docker exec kafka-server kafka-topics.sh \
  --describe --bootstrap-server localhost:9092 --topic my-topic

# Delete topic
docker exec kafka-server kafka-topics.sh \
  --delete --bootstrap-server localhost:9092 --topic my-topic
```

### Producer/Consumer Testing

```bash
# Produce messages
echo "test message" | docker exec -i kafka-server \
  kafka-console-producer.sh \
  --broker-list localhost:9092 --topic customer-events

# Consume messages
docker exec kafka-server kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic customer-events \
  --from-beginning

# Consume latest messages only
docker exec kafka-server kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic customer-events
```

### Container Management

```bash
# Start Kafka
cd /opt/kafka && docker compose up -d

# Stop Kafka
cd /opt/kafka && docker compose down

# Restart Kafka
cd /opt/kafka && docker compose restart

# View logs
docker logs -f kafka-server

# View last 100 lines
docker logs --tail 100 kafka-server

# Check container status
docker ps | grep kafka

# Container stats
docker stats kafka-server
```

---

## 👀 Monitoring & Health Checks

### Check Kafka Health

```bash
# Broker API versions (health check)
docker exec kafka-server kafka-broker-api-versions.sh \
  --bootstrap-server localhost:9092

# List consumer groups
docker exec kafka-server kafka-consumer-groups.sh \
  --list --bootstrap-server localhost:9092

# Describe consumer group
docker exec kafka-server kafka-consumer-groups.sh \
  --describe --bootstrap-server localhost:9092 \
  --group my-consumer-group

# Check consumer lag
docker exec kafka-server kafka-consumer-groups.sh \
  --describe --bootstrap-server localhost:9092 \
  --group my-consumer-group --verbose
```

### System Resources

```bash
# Disk usage
df -h /opt/kafka

# Memory usage
free -h

# CPU usage
top

# Docker resource usage
docker stats

# Network connections
netstat -tuln | grep 9092
```

---

## 🔍 Troubleshooting

### Kafka Won't Start

```bash
# Check logs
docker logs kafka-server

# Check disk space
df -h

# Check memory
free -h

# Restart Docker
sudo systemctl restart docker

# Remove and recreate container
cd /opt/kafka
docker compose down
docker compose up -d
```

### Connection Issues

```bash
# Test port connectivity
telnet <EC2_IP> 9092
nc -zv <EC2_IP> 9092

# Check security group
aws ec2 describe-security-groups --group-ids <SG_ID>

# Check Kafka listeners
docker exec kafka-server cat /opt/bitnami/kafka/config/server.properties | grep advertised

# Check network
ping <EC2_IP>
```

### High Memory Usage

```bash
# Reduce heap size in docker-compose.yml
KAFKA_HEAP_OPTS=-Xmx1G -Xms1G

# Restart Kafka
cd /opt/kafka && docker compose restart
```

### Topic Not Found

```bash
# List all topics
docker exec kafka-server kafka-topics.sh \
  --list --bootstrap-server localhost:9092

# Create missing topic
./scripts/create-topics.sh
```

---

## 📊 Performance Tuning

### Quick Wins

```yaml
# Producer (application.yml)
spring.kafka.producer:
  compression-type: lz4        # Enable compression
  batch-size: 32768           # Increase batch size
  linger-ms: 20               # Wait longer for batching
  enable-idempotence: true    # Prevent duplicates

# Consumer (application.yml)
spring.kafka.consumer:
  max-poll-records: 500       # Process more records per poll
  fetch-min-size: 1048576     # 1MB minimum fetch
  enable-auto-commit: false   # Manual commit for control
```

### Heap Size Recommendations

| Instance Type | Heap Size |
|---------------|----------|
| t3.medium | 2G |
| t3.large | 4G |
| m5.xlarge | 8G |

---

## 🔒 Security Checklist

- [ ] Change default passwords
- [ ] Enable SSL/TLS
- [ ] Implement SASL authentication
- [ ] Restrict security group to VPC only
- [ ] Use private subnet for production
- [ ] Enable CloudWatch logging
- [ ] Regular security patches
- [ ] Backup Kafka data regularly
- [ ] Monitor consumer lag
- [ ] Set up alerts

---

## 💾 Backup & Recovery

### Backup Kafka Data

```bash
# Create backup
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf kafka-backup-$DATE.tar.gz /opt/kafka/data

# Upload to S3
aws s3 cp kafka-backup-$DATE.tar.gz s3://your-bucket/kafka-backups/
```

### Restore Kafka Data

```bash
# Stop Kafka
cd /opt/kafka && docker compose down

# Restore data
tar -xzf kafka-backup-YYYYMMDD_HHMMSS.tar.gz -C /

# Start Kafka
cd /opt/kafka && docker compose up -d
```

---

## 🗑️ Cleanup

### Stop Everything

```bash
# Stop Kafka
cd /opt/kafka && docker compose down

# Remove volumes (CAUTION: Deletes all data)
cd /opt/kafka && docker compose down -v
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

### Remove Docker Images

```bash
# Remove Kafka image
docker rmi bitnami/kafka:latest

# Remove all unused images
docker image prune -a
```

---

## 📞 Support Contacts

| Issue Type | Contact |
|------------|----------|
| Infrastructure | Platform Team |
| Kafka Configuration | DevOps Team |
| Application Integration | Development Team |
| Security | Security Team |

---

## 🔗 Useful Links

- [Full README](README.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Kafka Configuration](KAFKA_CONFIG.md)
- [Apache Kafka Docs](https://kafka.apache.org/documentation/)
- [Spring Kafka Docs](https://spring.io/projects/spring-kafka)
- [Bitnami Kafka](https://github.com/bitnami/containers/tree/main/bitnami/kafka)

---

## 📝 Pre-configured Topics

1. **customer-events** - Customer lifecycle events
2. **order-events** - Order processing events
3. **catalog-events** - Product catalog changes
4. **payment-events** - Payment transactions
5. **inventory-events** - Inventory updates
6. **notification-events** - User notifications
7. **dead-letter-events** - Failed messages (30-day retention)

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| Initial Terraform Deploy | 5-7 minutes |
| EC2 User Data Execution | 2-3 minutes |
| Kafka Container Start | 1-2 minutes |
| Total First Deployment | 8-12 minutes |
| Subsequent Deployments | 3-5 minutes |
| Topic Creation | < 1 minute |
| Destroy Infrastructure | 2-3 minutes |

---

**Last Updated**: 2026-09-02

**Version**: 1.0.0

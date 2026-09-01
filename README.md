# infra-kafka-platform

**Production-Ready Apache Kafka Infrastructure on AWS EC2**

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20VPC-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Kafka](https://img.shields.io/badge/Kafka-KRaft%20Mode-231F20?logo=apache-kafka)](https://kafka.apache.org/)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?logo=jenkins)](https://www.jenkins.io/)

## Overview

This repository provisions a highly available Apache Kafka cluster on AWS EC2 instances using Terraform and deploys Kafka using Docker Compose. The entire infrastructure is automated through Jenkins CI/CD pipelines.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS VPC (10.0.0.0/16)                  │
│                                                                 │
│  ┌──────────────────┐                  ┌──────────────────┐   │
│  │  Public Subnet   │                  │  Private Subnet  │   │
│  │  10.0.1.0/24     │                  │  10.0.101.0/24   │   │
│  │                  │                  │                  │   │
│  │  - NAT Gateway   │                  │  - Kafka-1       │   │
│  │  - IGW           │                  │  - Kafka-2       │   │
│  └──────────────────┘                  │  - Kafka-3       │   │
│                                        └──────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │            EKS Cluster (meracommerce-dev-cluster)         │ │
│  │      Connects to Kafka via Private DNS (9092)             │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

        External Access (Optional)
             ↓ :9094
      Public DNS (Route53)
```

## Features

✅ **Automated Infrastructure Provisioning** - Complete AWS infrastructure via Terraform
✅ **High Availability** - 3-broker Kafka cluster with replication factor 3
✅ **KRaft Mode** - No Zookeeper dependency
✅ **EKS Integration** - Seamless connectivity from Kubernetes workloads
✅ **Auto-Scaling Ready** - Configurable instance types and storage
✅ **Monitoring & Observability** - Prometheus, Grafana, CloudWatch integration
✅ **Security Hardened** - Security groups, private subnets, IAM roles
✅ **CI/CD Automated** - Jenkins pipeline for end-to-end deployment
✅ **DNS Management** - Route53 private hosted zones
✅ **Docker-based Deployment** - Consistent runtime environment

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- Jenkins with AWS credentials configured
- Existing EKS cluster: `meracommerce-dev-cluster`
- AWS CLI configured

### 1. Clone Repository

```bash
git clone https://github.com/your-org/infra-kafka-platform.git
cd infra-kafka-platform
```

### 2. Configure Variables

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
project_name     = "meracommerce"
environment      = "dev"
aws_region       = "us-east-1"
kafka_version    = "3.6.1"
instance_type    = "t3.medium"
```

### 3. Deploy via Jenkins

1. Create a new Jenkins pipeline job
2. Point to this repository
3. Run the pipeline
4. Approve the Terraform plan
5. Wait for automated deployment

### 4. Verify Deployment

```bash
# SSH to Kafka broker
ssh -i your-key.pem ec2-user@<broker-ip>

# Check Kafka containers
docker ps

# List topics
docker exec kafka-1 kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Repository Structure

```
infra-kafka-platform/
├── terraform/
│   ├── modules/
│   │   ├── networking/          # VPC, Subnets, IGW, NAT, Routes
│   │   ├── kafka-ec2/           # EC2 instances for Kafka brokers
│   │   ├── security-group/      # Security groups and rules
│   │   ├── monitoring/          # CloudWatch, Prometheus, Grafana
│   │   └── route53/             # DNS private hosted zones
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── docker/
│   ├── kafka/
│   │   └── docker-compose.yml   # Kafka cluster Docker Compose
│   └── monitoring/
│       └── docker-compose.yml   # Prometheus, Grafana, Exporters
├── scripts/
│   ├── install-docker.sh        # Docker installation automation
│   ├── deploy-kafka.sh          # Kafka deployment automation
│   ├── create-topics.sh         # Topic creation automation
│   ├── validate-kafka.sh        # Health check validation
│   └── rollback.sh              # Disaster recovery rollback
├── jenkins/
│   └── Jenkinsfile              # Complete CI/CD pipeline
├── kubernetes/
│   ├── configmap.yaml           # Kafka bootstrap servers
│   ├── secret.yaml              # Kafka credentials
│   └── spring-boot-example/
│       ├── values.yaml
│       └── application.yml
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   └── dashboards/
│   │       ├── kafka-overview.json
│   │       ├── broker-metrics.json
│   │       └── consumer-lag.json
│   └── cloudwatch/
│       └── alarms.tf
├── docs/
│   ├── DEPLOYMENT.md            # Detailed deployment guide
│   ├── SPRING_BOOT_INTEGRATION.md
│   ├── ROLLBACK_STRATEGY.md
│   ├── COST_ESTIMATION.md
│   └── TROUBLESHOOTING.md
└── README.md
```

## Infrastructure Components

### Networking

| Component | CIDR/Config | Purpose |
|-----------|-------------|----------|
| VPC | 10.0.0.0/16 | Isolated network |
| Public Subnet 1 | 10.0.1.0/24 | NAT Gateway, Bastion |
| Public Subnet 2 | 10.0.2.0/24 | High availability |
| Private Subnet 1 | 10.0.101.0/24 | Kafka Broker 1 |
| Private Subnet 2 | 10.0.102.0/24 | Kafka Broker 2 |
| Private Subnet 3 | 10.0.103.0/24 | Kafka Broker 3 |

### Kafka Cluster

| Broker | Private IP | DNS | Port |
|--------|-----------|-----|------|
| Kafka-1 | 10.0.101.10 | kafka-1.internal | 9092 |
| Kafka-2 | 10.0.102.10 | kafka-2.internal | 9092 |
| Kafka-3 | 10.0.103.10 | kafka-3.internal | 9092 |
| Bootstrap | - | kafka-bootstrap.internal | 9092 |

### Topics

| Topic | Partitions | Replication | Min ISR |
|-------|-----------|-------------|----------|
| customer-events | 6 | 3 | 2 |
| order-events | 6 | 3 | 2 |
| catalog-events | 6 | 3 | 2 |
| payment-events | 6 | 3 | 2 |
| notification-events | 6 | 3 | 2 |
| dead-letter-events | 6 | 3 | 2 |
| audit-events | 6 | 3 | 2 |

## Spring Boot Integration

### Add to `application.yml`:

```yaml
spring:
  kafka:
    bootstrap-servers: kafka-bootstrap.internal:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
      retries: 3
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      group-id: ${spring.application.name}
      auto-offset-reset: earliest
      enable-auto-commit: false
    properties:
      security.protocol: PLAINTEXT
      max.poll.records: 500
      session.timeout.ms: 30000
```

### Add to `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

## Monitoring

### Access Grafana

```bash
http://<kafka-broker-public-ip>:3000
Username: admin
Password: <from terraform output>
```

### Pre-configured Dashboards

1. **Kafka Overview** - Cluster health, throughput, active controllers
2. **Broker Metrics** - CPU, memory, disk I/O per broker
3. **Consumer Lag** - Consumer group lag monitoring
4. **Topic Throughput** - Messages/sec per topic
5. **Network Traffic** - Bytes in/out per broker

## Security

### Security Groups

**kafka-sg**:
- Port 9092: EKS Node Security Group
- Port 9093: Kafka Broker Communication
- Port 22: Admin CIDR only
- Port 9094: Internet (optional, for external access)

### IAM Roles

- **kafka-ec2-role**: CloudWatch logs, SSM access, S3 backups
- **eks-kafka-access-role**: EKS pods accessing Kafka

## Cost Estimation

### Monthly Costs (us-east-1)

| Resource | Quantity | Unit Cost | Total |
|----------|----------|-----------|-------|
| EC2 t3.medium | 3 | $30.37 | $91.11 |
| EBS gp3 100GB | 3 | $8.00 | $24.00 |
| NAT Gateway | 1 | $32.85 | $32.85 |
| Data Transfer | ~500GB | $0.09/GB | $45.00 |
| Route53 Hosted Zone | 1 | $0.50 | $0.50 |
| CloudWatch Logs | ~50GB | $0.50/GB | $25.00 |
| **Total** | | | **~$218.46/month** |

*Costs may vary based on actual usage and data transfer*

## Troubleshooting

### Kafka Broker Not Starting

```bash
# Check Docker logs
docker logs kafka-1 --tail 100

# Verify cluster ID
docker exec kafka-1 cat /bitnami/kafka/data/meta.properties

# Check disk space
df -h
```

### EKS Cannot Connect to Kafka

```bash
# Test DNS resolution from EKS pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kafka-bootstrap.internal

# Test connectivity
kubectl run -it --rm debug --image=confluentinc/cp-kafka:latest --restart=Never -- kafka-broker-api-versions --bootstrap-server kafka-bootstrap.internal:9092
```

### Topic Creation Failed

```bash
# Manually create topic
docker exec kafka-1 kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic test-topic \
  --partitions 6 \
  --replication-factor 3 \
  --config min.insync.replicas=2
```

## Rollback Strategy

```bash
# Quick rollback
cd terraform/environments/dev
terraform destroy -auto-approve

# Or use rollback script
bash scripts/rollback.sh --environment dev
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

## Support

For issues and questions:
- Create an issue in this repository
- Contact DevOps team: devops@meracommerce.com

## License

MIT License - see LICENSE file for details

---

**Maintained by**: DevOps Team @ MeraCommerce  
**Last Updated**: 2026-09-01  
**Version**: 1.0.0

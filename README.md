# Kafka EC2 Platform Infrastructure

![Kafka](https://img.shields.io/badge/Apache%20Kafka-231F20?style=for-the-badge&logo=apache-kafka&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)

A production-ready, automated Kafka infrastructure on AWS EC2 using Terraform, Docker, and Jenkins.

## 📚 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Terraform Configuration](#terraform-configuration)
- [Kafka Configuration](#kafka-configuration)
- [Spring Boot Integration](#spring-boot-integration)
- [Jenkins Pipeline](#jenkins-pipeline)
- [Operations](#operations)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [License](#license)

## 📝 Overview

This project provides a complete infrastructure-as-code solution to deploy Apache Kafka on AWS EC2 using:

- **Terraform** for infrastructure provisioning
- **Docker** for containerized Kafka deployment
- **KRaft Mode** (Kafka without Zookeeper)
- **Jenkins** for automated CI/CD pipeline
- **Spring Boot** ready-to-use configuration

## 🏛 Architecture

```
┌────────────────────────┐
│   Jenkins Pipeline      │
│   (CI/CD Automation)    │
└───────┬────────────────┘
        │
        │ Terraform Apply
        │
        │
┌───────┴────────────────────────────────┐
│          AWS Cloud (us-east-1)           │
│  ┌────────────────────────────────┐  │
│  │    VPC (Private Network)      │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  EC2: kafka-ec2-instance │  │  │
│  │  │  Type: t3.medium         │  │  │
│  │  │  OS: Amazon Linux 2023   │  │  │
│  │  │  Storage: 40GB gp3       │  │  │
│  │  │                         │  │  │
│  │  │  ┌───────────────────┐  │  │  │
│  │  │  │  Docker Engine     │  │  │  │
│  │  │  │  ┌──────────────┐  │  │  │  │
│  │  │  │  │ Kafka (KRaft) │  │  │  │  │
│  │  │  │  │ Port: 9092    │  │  │  │  │
│  │  │  │  │ Port: 9094    │  │  │  │  │
│  │  │  │  └──────────────┘  │  │  │  │
│  │  │  └───────────────────┘  │  │  │
│  │  └─────────────────────────┘  │  │
│  │                                │  │
│  │  Security Group: kafka-sg       │  │
│  │  - SSH (22)                     │  │
│  │  - Kafka Internal (9092)        │  │
│  │  - Kafka External (9094)        │  │
│  └────────────────────────────────┘  │
└────────────────────────────────────────┘
        │
        │ Kafka Client Connection
        │ (port 9092 - internal)
        │
┌───────┴──────────────────────────┐
│   Spring Boot Microservices     │
│   (Producer/Consumer Apps)      │
└──────────────────────────────────┘
```

## ✨ Features

✅ **Dynamic SSH Key Generation** 🆕
- Automatic SSH key pair creation by Terraform
- No manual key management required
- Unique key per deployment for enhanced security
- No Jenkins SSH credential configuration needed

✅ **Automated Infrastructure Provisioning**
- Terraform manages all AWS resources
- Version-controlled infrastructure
- Idempotent and repeatable deployments

✅ **Production-Ready Kafka**
- KRaft mode (no Zookeeper dependency)
- High-performance configuration
- Persistent data storage
- Auto-restart capabilities

✅ **Security Hardened**
- Security group with minimal required ports
- IMDSv2 enforced on EC2
- Encrypted EBS volumes
- VPC isolation

✅ **Pre-configured Topics**
- customer-events
- order-events
- catalog-events
- payment-events
- inventory-events
- notification-events
- dead-letter-events

✅ **Spring Boot Ready**
- Complete application.yml configuration
- Producer and Consumer examples
- JSON serialization/deserialization
- Manual acknowledgment support

✅ **CI/CD Pipeline**
- Fully automated Jenkins pipeline
- Infrastructure validation
- Deployment verification
- Health checks

## 📦 Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **AWS CLI** configured with credentials
- **Jenkins** with required plugins
- **Git**

### AWS Requirements
- AWS Account with appropriate permissions
- VPC with subnets
- EC2 key pair for SSH access
- Security group for EKS workers (optional)

### Jenkins Requirements
- **AWS credentials only** (`jenkins-user` credential ID)
- Git repository access
- ~~SSH credentials~~ - ❌ Not needed (auto-generated!)

## 📁 Project Structure

```
infra-kafka-ec2-platform/
├── terraform/
│   ├── main.tf                    # Main infrastructure resources
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── providers.tf               # Terraform providers
│   ├── userdata.sh                # EC2 initialization script
│   └── terraform.tfvars.example   # Example variables
│
├── scripts/
│   ├── create-topics.sh           # Topic creation script
│   └── verify-kafka.sh            # Kafka verification script
│
├── spring-boot-config/
│   ├── application.yml            # Spring Boot Kafka config
│   ├── KafkaProducerExample.java  # Producer example
│   └── KafkaConsumerExample.java  # Consumer example
│
├── Jenkinsfile                    # CI/CD pipeline
├── README.md                      # This file
└── DEPLOYMENT_GUIDE.md            # Detailed deployment guide
```

## 🚀 Quick Start

### **NEW: Dynamic SSH Key Generation** 🔑

No manual SSH key management required! The pipeline automatically generates SSH keys.

**See**: [DYNAMIC_SSH_QUICKSTART.md](DYNAMIC_SSH_QUICKSTART.md) for detailed guide.

### 1. Clone Repository

```bash
git clone <repository-url>
cd infra-kafka-ec2-platform
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
# Note: key_name is NOT needed - auto-generated!
```

### 3. Deploy with Jenkins (Recommended)

1. Create Jenkins pipeline job
2. Point to this repository
3. Configure **only AWS credentials** (`jenkins-user`)
4. Run the pipeline - SSH keys auto-generated!

### 4. Deploy with Terraform (Manual)

```bash
terraform init
terraform validate
terraform plan
terraform apply
# SSH key saved to: kafka-ec2-private-key.pem
```

## 🔧 Terraform Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|----------|
| `vpc_id` | VPC ID | `vpc-0123456789` |
| `subnet_id` | Subnet ID | `subnet-0123456789` |
| `private_vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `admin_ip_address` | Your IP for SSH | `203.0.113.1` |
| `key_name` | EC2 key pair name | `my-key-pair` |

### Outputs

```bash
# Get EC2 details
terraform output ec2_public_ip
terraform output ec2_private_ip
terraform output kafka_bootstrap_server_internal
```

## ⚙️ Kafka Configuration

### Broker Settings

- **Broker ID**: 1
- **Cluster Name**: kafka-cluster-dev
- **Internal Port**: 9092 (VPC)
- **External Port**: 9094 (Public)
- **Partitions**: 3 per topic
- **Replication Factor**: 1
- **Retention**: 7 days

### Performance Tuning

- **Heap Size**: 2GB (Xmx2G, Xms2G)
- **Compression**: LZ4
- **Log Segment**: 1GB
- **Auto-create Topics**: Enabled

## 🌱 Spring Boot Integration

### 1. Add Dependencies

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

### 2. Configure Application

Copy `spring-boot-config/application.yml` to your project and update:

```yaml
spring:
  kafka:
    bootstrap-servers: <EC2_PRIVATE_IP>:9092
```

### 3. Use Producer/Consumer Examples

- Copy `KafkaProducerExample.java` for producing messages
- Copy `KafkaConsumerExample.java` for consuming messages

## 🔄 Jenkins Pipeline

### Pipeline Stages

1. **Checkout** - Clone repository
2. **Terraform Init** - Initialize Terraform
3. **Terraform Validate** - Validate configuration
4. **Terraform Plan** - Plan infrastructure changes
5. **Terraform Apply** - Provision infrastructure + **Generate SSH key** 🆕
6. **Get EC2 Details** - Extract instance info + SSH key
7. **Wait for Initialization** - Wait for EC2 ready + Test SSH
8. **Install Docker** - Install Docker via SSH (visible logs) 🆕
9. **Verify Docker** - Check Docker installation
10. **Setup Kafka** - Deploy Kafka via SSH (visible logs) 🆕
11. **Wait for Kafka Startup** - Wait for Kafka container
12. **Create Topics** - Create all Kafka topics
13. **Verify Kafka** - Test producer/consumer
14. **Print Details** - Display SSH command & connection info
15. **Success** - Deployment summary

### Required Jenkins Credentials

- `jenkins-user`: AWS access key and secret
- ~~`kafka-ec2-key`~~: ❌ Not needed (auto-generated!)

### Key Differences from Old Approach

✅ **SSH keys auto-generated** by Terraform (no manual setup)  
✅ **Docker installed via SSH** (visible in Jenkins console)  
✅ **Kafka deployed via SSH** (real-time feedback)  
✅ **Better debugging** (all installation logs visible)  
✅ **One less credential** to manage in Jenkins

## 🛠️ Operations

### Connect to EC2

```bash
ssh -i <your-key.pem> ec2-user@<EC2_PUBLIC_IP>
```

### Check Kafka Status

```bash
cd /opt/kafka
docker compose ps
docker logs kafka-server
```

### List Topics

```bash
docker exec kafka-server kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092
```

### Produce Test Message

```bash
echo "test message" | docker exec -i kafka-server \
  kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic customer-events
```

### Consume Messages

```bash
docker exec kafka-server kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic customer-events \
  --from-beginning
```

### Restart Kafka

```bash
cd /opt/kafka
docker compose restart
```

### View Logs

```bash
docker logs -f kafka-server
```

## 🔍 Troubleshooting

### Jenkins Pipeline Failure: "ERROR: kafka-ec2-key"

**Problem**: Pipeline fails immediately with credential error

**Solution**: Missing Jenkins credentials - follow the quick fix guide

```bash
# Quick verification
./verify-jenkins-setup.sh
```

📚 **See**:
- [QUICK_FIX_GUIDE.md](QUICK_FIX_GUIDE.md) - 5-minute fix
- [JENKINS_CREDENTIALS_SETUP.md](JENKINS_CREDENTIALS_SETUP.md) - Detailed setup

**Required Jenkins Credentials**:
- `kafka-ec2-key` - SSH private key for EC2 (username: ec2-user)
- `jenkins-user` - AWS access credentials

### Kafka Not Starting

```bash
# Check Docker logs
docker logs kafka-server

# Check system resources
free -h
df -h

# Verify network
netstat -tuln | grep 9092
```

### Connection Issues

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>

# Test connectivity
telnet <EC2_IP> 9092

# Verify advertised listeners
docker exec kafka-server cat /opt/bitnami/kafka/config/server.properties | grep advertised
```

### Topic Creation Fails

```bash
# Check Kafka is ready
docker exec kafka-server kafka-broker-api-versions.sh \
  --bootstrap-server localhost:9092

# Manually create topic
docker exec kafka-server kafka-topics.sh \
  --create \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --partitions 3 \
  --replication-factor 1
```

## 🔒 Security Considerations

⚠️ **Production Security Checklist**:

- [ ] Enable SSL/TLS for Kafka
- [ ] Implement SASL authentication
- [ ] Use private subnets for EC2
- [ ] Restrict security group to specific IPs
- [ ] Enable CloudWatch logging
- [ ] Implement backup strategy
- [ ] Use IAM roles instead of access keys
- [ ] Enable VPC Flow Logs
- [ ] Implement network ACLs
- [ ] Regular security patching

## 📊 Monitoring

### CloudWatch Metrics

- EC2 CPU/Memory/Disk
- Network In/Out
- Custom Kafka metrics (via JMX exporter)

### Kafka Metrics

```bash
# View broker metrics
docker exec kafka-server kafka-run-class.sh \
  kafka.tools.JmxTool \
  --object-name kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec
```

## 🗑️ Cleanup

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

### Manual Cleanup

```bash
# Stop Kafka
cd /opt/kafka
docker compose down -v

# Remove data
sudo rm -rf /opt/kafka/data/*
```

## 📝 License

This project is licensed under the MIT License.

## 👥 Support

For issues and questions:
- Open GitHub issue
- Contact platform team
- Check documentation

---

**Built with ❤️ by Platform Team**

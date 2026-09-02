# Project Overview: Kafka EC2 Platform Infrastructure

## Executive Summary

This project delivers a **complete production-ready Apache Kafka infrastructure** deployed on AWS EC2 using Infrastructure as Code (Terraform) with full CI/CD automation through Jenkins. The solution enables Spring Boot microservices to leverage event-driven architecture with minimal setup.

---

## 🎯 Project Objectives

✅ **Automated Infrastructure**: Provision AWS EC2 infrastructure using Terraform

✅ **Containerized Kafka**: Deploy Kafka using Docker in KRaft mode (Zookeeper-free)

✅ **CI/CD Integration**: Complete Jenkins pipeline for end-to-end automation

✅ **Production Ready**: Security, monitoring, and operational best practices

✅ **Developer Friendly**: Spring Boot integration examples and comprehensive documentation

---

## 🏗️ Architecture Components

### Infrastructure Layer (AWS)

| Component | Specification | Purpose |
|-----------|---------------|----------|
| **EC2 Instance** | t3.medium | Kafka broker hosting |
| **Operating System** | Amazon Linux 2023 | Latest stable Linux |
| **Storage** | 40GB gp3 EBS | Kafka data persistence |
| **Security Group** | kafka-sg | Network access control |
| **Region** | us-east-1 | AWS region |

### Application Layer

| Component | Technology | Version |
|-----------|-----------|----------|
| **Container Runtime** | Docker | Latest |
| **Container Orchestration** | Docker Compose | Latest |
| **Message Broker** | Apache Kafka | Latest (Bitnami) |
| **Kafka Mode** | KRaft | No Zookeeper |

### Automation Layer

| Component | Technology | Purpose |
|-----------|-----------|----------|
| **IaC** | Terraform | Infrastructure provisioning |
| **CI/CD** | Jenkins | Deployment automation |
| **Scripts** | Bash | Topic management & verification |

---

## 📦 Deliverables

### 1. Terraform Infrastructure Code

```
terraform/
├── providers.tf               # AWS provider configuration
├── variables.tf               # Input variables
├── main.tf                    # EC2, Security Group, Resources
├── outputs.tf                 # Output values (IPs, IDs)
├── userdata.sh                # EC2 initialization script
└── terraform.tfvars.example   # Configuration template
```

**Features**:
- VPC-aware deployment
- Encrypted EBS volumes
- IMDSv2 enforcement
- Automatic Docker installation
- User data script for bootstrap

### 2. Kafka Deployment Configuration

**Docker Compose Setup**:
- Bitnami Kafka official image
- KRaft mode (no Zookeeper)
- Persistent volume mapping
- Health checks
- Auto-restart policy

**Network Configuration**:
- Port 9092: Internal VPC communication
- Port 9094: External access
- Port 9093: Controller (internal)

### 3. Automation Scripts

| Script | Purpose |
|--------|----------|
| `create-topics.sh` | Create all pre-defined topics |
| `verify-kafka.sh` | Test producer/consumer functionality |

### 4. Jenkins Pipeline

**12-Stage Automated Deployment**:
1. Checkout code from Git
2. Initialize Terraform
3. Validate Terraform configuration
4. Plan infrastructure changes
5. Apply infrastructure (create EC2)
6. Retrieve EC2 instance details
7. Verify Docker installation
8. Deploy Kafka containers
9. Create Kafka topics
10. Verify Kafka functionality
11. Display connection details
12. Deployment success confirmation

### 5. Spring Boot Integration

**Complete Integration Package**:
- `application.yml`: Kafka configuration
- `KafkaConfig.java`: Spring beans configuration
- `KafkaProducerExample.java`: Producer implementation
- `KafkaConsumerExample.java`: Consumer implementation
- `pom.xml`: Maven dependencies

### 6. Documentation

| Document | Content |
|----------|----------|
| `README.md` | Complete project documentation |
| `DEPLOYMENT_GUIDE.md` | Step-by-step deployment instructions |
| `KAFKA_CONFIG.md` | Kafka configuration reference |
| `QUICK_REFERENCE.md` | Quick commands and operations |
| `PROJECT_OVERVIEW.md` | This document |

---

## 🚀 Deployment Workflow

### Automated Deployment (Jenkins)

```
Jenkins Trigger
      ↓
Git Checkout
      ↓
Terraform Init/Validate/Plan
      ↓
Terraform Apply
      ↓
EC2 Instance Created
      ↓
User Data Execution (Docker Install)
      ↓
Docker Compose Deploy Kafka
      ↓
Topics Creation
      ↓
Verification Tests
      ↓
Deployment Complete ✓
```

**Total Time**: 10-15 minutes

### Manual Deployment (Terraform)

```bash
# 1. Configure
cd terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Deploy
terraform init
terraform apply

# 3. Wait for EC2 initialization (3-5 minutes)

# 4. SSH and start Kafka
ssh -i key.pem ec2-user@<EC2_IP>
cd /opt/kafka && docker compose up -d

# 5. Create topics
./create-topics.sh

# 6. Verify
./verify-kafka.sh
```

**Total Time**: 15-20 minutes

---

## 📋 Pre-configured Topics

Seven production-ready topics created automatically:

| # | Topic Name | Partitions | Retention | Use Case |
|---|-----------|-----------|-----------|----------|
| 1 | customer-events | 3 | 7 days | Customer lifecycle |
| 2 | order-events | 3 | 7 days | Order processing |
| 3 | catalog-events | 3 | 7 days | Catalog changes |
| 4 | payment-events | 3 | 7 days | Payment transactions |
| 5 | inventory-events | 3 | 7 days | Inventory updates |
| 6 | notification-events | 3 | 7 days | Notifications |
| 7 | dead-letter-events | 3 | 30 days | Failed messages |

**Topic Configuration**:
- Compression: LZ4
- Partitions: 3 (parallelism)
- Replication: 1 (single broker)
- Min ISR: 1

---

## 🔒 Security Features

### Network Security

**Security Group Rules**:
- SSH (22): Admin IP only
- Kafka Internal (9092): VPC CIDR + EKS workers
- Kafka External (9094): VPC CIDR + EKS workers
- All outbound: Allowed

### Instance Security

✓ IMDSv2 enforced

✓ Encrypted EBS volumes

✓ No public ingress (VPC only)

✓ SSH key-based authentication

### Future Security Enhancements

- [ ] SSL/TLS encryption
- [ ] SASL authentication
- [ ] ACL-based authorization
- [ ] VPC endpoints
- [ ] Private subnets

---

## 📊 Monitoring & Operations

### Health Checks

```bash
# Container health
docker ps | grep kafka

# Kafka broker health
kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# Topic verification
kafka-topics.sh --list --bootstrap-server localhost:9092

# Consumer group health
kafka-consumer-groups.sh --describe --bootstrap-server localhost:9092 --group my-group
```

### Metrics (Available via JMX)

- Messages per second
- Bytes in/out per second
- Consumer lag
- Partition count
- Active connections

### Logging

- Docker container logs: `docker logs kafka-server`
- EC2 user data logs: `/var/log/kafka-setup.log`
- Application logs: Spring Boot logging

---

## 👥 Target Audience

| Role | Use Case |
|------|----------|
| **DevOps Engineers** | Infrastructure provisioning and automation |
| **Backend Developers** | Kafka integration in microservices |
| **Platform Engineers** | Kafka cluster management |
| **SRE Teams** | Monitoring and operations |
| **Architects** | Event-driven architecture design |

---

## 💼 Business Benefits

### Cost Efficiency
- **Single EC2 instance**: Minimal infrastructure cost
- **On-demand scaling**: Add brokers as needed
- **Resource optimization**: Right-sized t3.medium instance

### Time Savings
- **Automated deployment**: 10-15 minutes vs hours of manual setup
- **Pre-configured topics**: Ready for immediate use
- **Jenkins integration**: One-click deployment

### Developer Productivity
- **Spring Boot examples**: Copy-paste integration
- **Comprehensive documentation**: Reduced learning curve
- **Operational scripts**: Simplified management

### Operational Excellence
- **Infrastructure as Code**: Version-controlled, repeatable
- **Automated testing**: Verification included
- **Best practices**: Production-ready configuration

---

## 🔧 Technology Stack

### Infrastructure
- AWS EC2
- AWS VPC
- AWS EBS
- Terraform 1.0+

### Runtime
- Amazon Linux 2023
- Docker Engine
- Docker Compose
- Apache Kafka (KRaft)

### Automation
- Jenkins
- Bash scripting
- Git

### Application
- Spring Boot 3.x
- Spring Kafka
- Java 17
- Maven

---

## 📚 Usage Example

### Spring Boot Producer

```java
@Service
public class OrderService {
    
    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    public void createOrder(Order order) {
        // Save order to database
        orderRepository.save(order);
        
        // Publish event to Kafka
        kafkaTemplate.send("order-events", order.getId(), order);
    }
}
```

### Spring Boot Consumer

```java
@Service
public class NotificationService {
    
    @KafkaListener(topics = "order-events", groupId = "notification-service")
    public void handleOrderEvent(Order order) {
        // Send notification to customer
        emailService.sendOrderConfirmation(order);
    }
}
```

---

## 🔄 Scaling Strategy

### Vertical Scaling

Upgrade instance type:
- t3.medium → t3.large (2x resources)
- t3.large → m5.xlarge (production)
- Increase EBS volume size

### Horizontal Scaling

Add more brokers:
1. Deploy additional EC2 instances
2. Update Kafka cluster configuration
3. Increase topic replication factor
4. Rebalance partitions

### Multi-AZ Deployment

- Deploy brokers in multiple availability zones
- Increase replication factor to 3
- Configure rack awareness
- Use Application Load Balancer

---

## ⚠️ Production Considerations

### Before Going to Production

1. **Enable SSL/TLS encryption**
2. **Implement SASL authentication**
3. **Set up monitoring (CloudWatch/Prometheus)**
4. **Configure automated backups**
5. **Implement disaster recovery plan**
6. **Multi-broker cluster (3+ brokers)**
7. **Multi-AZ deployment**
8. **Increase replication factor to 3**
9. **Use private subnets**
10. **Set up alerting**

### Recommended Production Changes

```hcl
# Terraform
instance_type = "m5.xlarge"  # More powerful
volume_size   = 100          # Larger storage

# Kafka
REPLICATION_FACTOR = 3       # High availability
MIN_INSYNC_REPLICAS = 2      # Durability
AUTO_CREATE_TOPICS = false   # Explicit control

# Spring Boot
acks = all                   # Full durability
enable-idempotence = true    # Exactly-once
```

---

## 📝 Success Criteria

✅ **Infrastructure**: EC2 instance created successfully

✅ **Kafka**: Container running and healthy

✅ **Topics**: All 7 topics created

✅ **Connectivity**: Spring Boot can connect

✅ **Functionality**: Producer/consumer verified

✅ **Automation**: Jenkins pipeline executes successfully

✅ **Documentation**: Complete and accurate

---

## 🔗 Related Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Bitnami Kafka Container](https://github.com/bitnami/containers/tree/main/bitnami/kafka)
- [Spring for Apache Kafka](https://spring.io/projects/spring-kafka)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

---

## 👍 Conclusion

This project provides a **complete, production-ready Kafka infrastructure solution** that:

✓ Reduces deployment time from hours to minutes

✓ Eliminates manual configuration errors

✓ Provides battle-tested best practices

✓ Enables rapid Spring Boot integration

✓ Includes comprehensive documentation

✓ Supports CI/CD workflows

The solution is **immediately usable** for development, testing, and can be enhanced for production deployments.

---

**Project Status**: ✅ Complete and Ready for Use

**Version**: 1.0.0

**Last Updated**: 2026-09-02

**Maintained By**: Platform Team

# infra-msk-platform

> Production-ready Amazon MSK (Managed Streaming for Apache Kafka) infrastructure for Java microservices on AWS EKS

## 📋 Overview

This repository provisions and manages a complete Apache Kafka infrastructure using Amazon MSK for microservices running on AWS EKS. The infrastructure is designed for production workloads with multi-AZ deployment, TLS encryption, IAM authentication, and comprehensive monitoring.

## 🏗️ Architecture

- **Cloud Provider**: AWS
- **Region**: us-east-1
- **Kafka Platform**: Amazon MSK (Managed Streaming for Kafka)
- **Kafka Version**: 3.6.0 (Latest Stable)
- **Cluster Size**: 3 Brokers (Multi-AZ)
- **IaC Tool**: Terraform
- **CI/CD**: Jenkins
- **Environment**: Dev

## 🔐 Security Features

- ✅ IAM Authentication (SASL/IAM)
- ✅ TLS 1.2+ Encryption (In-transit)
- ✅ Encryption at Rest (AWS KMS)
- ✅ Private Subnet Deployment
- ✅ Security Group Restricted to EKS Nodes
- ✅ No Public Access

## 📊 Monitoring & Observability

- CloudWatch Dashboards
- Broker-level Metrics
- Topic-level Metrics
- Consumer Lag Monitoring
- Enhanced Monitoring (Prometheus JMX Exporter)
- Automated Alerting

## 🎯 Kafka Topics

| Topic Name | Partitions | Replication Factor | Min ISR | Retention |
|------------|------------|-------------------|---------|----------|
| customer-orderstatus-events | 6 | 3 | 2 | 7 days |
| order-create-events | 6 | 3 | 2 | 7 days |
| catalog-updation-events | 6 | 3 | 2 | 7 days |
| payment-confirm-events | 6 | 3 | 2 | 7 days |
| notification-events | 6 | 3 | 2 | 7 days |
| dead-letter-events | 6 | 3 | 2 | 7 days |

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.6.0
- AWS CLI configured
- kubectl configured for EKS cluster
- Jenkins setup (for CI/CD)

### Local Deployment

```bash
# Clone the repository
cd infra-msk-platform/terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply

# Create Kafka topics
cd ../../../scripts
./create-kafka-topics.sh
```

### Jenkins Deployment

```bash
# Trigger Jenkins pipeline
# Pipeline will handle: init → validate → plan → approval → apply
```

## 📁 Repository Structure

```
infra-msk-platform/
├── terraform/
│   ├── modules/
│   │   ├── networking/          # VPC, Subnets, Route Tables
│   │   ├── msk/                 # MSK Cluster Configuration
│   │   ├── kafka-topics/        # Topic Management
│   │   ├── monitoring/          # CloudWatch Dashboards & Alarms
│   │   └── security-group/      # Security Group Rules
│   ├── environments/
│   │   └── dev/                 # Dev environment configuration
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   └── providers.tf
├── kubernetes/
│   ├── configmaps/              # Kafka connection configs
│   ├── external-secrets/        # AWS Secrets integration
│   └── service-accounts/        # IRSA roles
├── scripts/
│   ├── create-kafka-topics.sh   # Topic creation automation
│   ├── verify-msk-cluster.sh    # Cluster health checks
│   ├── verify-connectivity.sh   # EKS connectivity validation
│   └── rollback.sh              # Rollback automation
├── spring-boot-examples/
│   ├── producer-config.yaml     # Producer configuration
│   ├── consumer-config.yaml     # Consumer configuration
│   └── application.properties   # Complete Spring Boot config
├── docs/
│   ├── DEPLOYMENT.md            # Deployment guide
│   ├── ROLLBACK.md              # Rollback procedures
│   ├── COST_ESTIMATION.md       # Cost breakdown
│   └── TROUBLESHOOTING.md       # Common issues
├── Jenkinsfile                  # CI/CD Pipeline
└── README.md
```

## 💰 Cost Estimation (Dev Environment)

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| MSK Cluster (kafka.t3.small x 3) | ~$140 |
| Storage (100GB per broker) | ~$30 |
| Data Transfer | ~$10 |
| CloudWatch Logs | ~$5 |
| **Total** | **~$185/month** |

> **Cost Optimization**: Using t3.small instances and minimal storage for dev. See [COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for details.

## 🔄 CI/CD Pipeline

The Jenkins pipeline automates:

1. **Checkout** - Clone repository
2. **Init** - Terraform initialization
3. **Validate** - Syntax and configuration validation
4. **Plan** - Generate execution plan
5. **Approval** - Manual approval gate
6. **Apply** - Provision infrastructure
7. **Topic Creation** - Create Kafka topics
8. **Verification** - Health checks
9. **Output Publishing** - Export connection details

## 🔗 Spring Boot Integration

### Producer Configuration

```yaml
spring:
  kafka:
    bootstrap-servers: ${MSK_BOOTSTRAP_SERVERS}
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: AWS_MSK_IAM
      sasl.jaas.config: software.amazon.msk.auth.iam.IAMLoginModule required;
      sasl.client.callback.handler.class: software.amazon.msk.auth.iam.IAMClientCallbackHandler
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
      retries: 3
```

### Consumer Configuration

```yaml
spring:
  kafka:
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      group-id: ${SERVICE_NAME}-consumer-group
      auto-offset-reset: earliest
      enable-auto-commit: false
```

See [spring-boot-examples/](spring-boot-examples/) for complete examples.

## 🧪 Verification

```bash
# Verify MSK cluster health
./scripts/verify-msk-cluster.sh

# Verify connectivity from EKS
./scripts/verify-connectivity.sh

# Test topic creation
kafka-topics.sh --bootstrap-server $MSK_BOOTSTRAP_SERVERS --list \
  --command-config config.properties
```

## 🔧 Kubernetes Integration

### Namespaces

- `customer-service-ns`
- `order-service-ns`
- `catalog-service-ns`
- `order-history-service-ns`
- `notification-service-ns`
- `payments-service-ns`

### IRSA (IAM Roles for Service Accounts)

Each namespace gets a dedicated service account with MSK access permissions.

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Rollback Strategy](docs/ROLLBACK.md) - Disaster recovery procedures
- [Cost Estimation](docs/COST_ESTIMATION.md) - Detailed cost breakdown
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🛡️ Best Practices Implemented

- ✅ Multi-AZ deployment for high availability
- ✅ Auto-scaling storage
- ✅ Encryption in-transit and at-rest
- ✅ IAM-based authentication (no passwords)
- ✅ Private subnet deployment
- ✅ Least privilege security groups
- ✅ CloudWatch monitoring and alerting
- ✅ Terraform state locking (DynamoDB)
- ✅ Infrastructure versioning
- ✅ Automated validation scripts

## 🤝 Contributing

For changes:
1. Create feature branch
2. Update Terraform code
3. Run `terraform fmt` and `terraform validate`
4. Submit PR with plan output
5. Get approval
6. Merge and deploy via Jenkins

## 📞 Support

For issues or questions:
- Create GitHub issue
- Contact DevOps team
- Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 📄 License

Proprietary - Internal Use Only

---

**Built with ❤️ by DevOps Team**
"# infra-msk-platform" 

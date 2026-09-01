# Kafka Infrastructure Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Deployment Methods](#deployment-methods)
5. [Post-Deployment](#post-deployment)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **AWS CLI** >= 2.0
- **Jenkins** (for CI/CD deployment)
- **kubectl** (for EKS integration)
- **Git**

### AWS Requirements

- AWS Account with appropriate permissions
- Existing EKS Cluster: `meracommerce-dev-cluster`
- IAM permissions for:
  - VPC creation and management
  - EC2 instance management
  - Route53 hosted zone management
  - CloudWatch logs and metrics
  - S3 (for Terraform state)

### Network Requirements

- VPC CIDR that doesn't conflict with existing networks
- Available Elastic IPs (for NAT Gateway)
- DNS resolution configured

---

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/infra-kafka-platform.git
cd infra-kafka-platform
```

### 2. AWS Credentials

Configure AWS credentials:

```bash
aws configure
# Or use environment variables:
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Terraform Backend Setup

Create S3 bucket and DynamoDB table for Terraform state:

```bash
aws s3 mb s3://meracommerce-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket meracommerce-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name meracommerce-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Configuration

### 1. Environment Variables

Copy and customize the example configuration:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

**Critical settings to review:**

```hcl
# Security - UPDATE THIS!
admin_cidr_blocks = ["YOUR_IP/32"]  # Replace with your IP

# Kafka Configuration
kafka_instance_type = "t3.medium"  # Adjust based on load
kafka_volume_size   = 100          # GB per broker

# Public Access
enable_public_access = false       # Set true for external consumers

# Public DNS (if enable_public_access = true)
kafka_public_dns = "kafka-public.meracommerce.dev"
```

### 3. Review Module Configuration

Verify module paths and versions in `main.tf`:

```bash
cd ../../
terraform init
terraform validate
```

---

## Deployment Methods

### Method 1: Jenkins CI/CD (Recommended)

#### Setup Jenkins Job

1. Create new Pipeline job in Jenkins
2. Configure Git repository URL
3. Set Pipeline script path: `jenkins/Jenkinsfile`
4. Add AWS credentials to Jenkins

#### Run Deployment

1. **Trigger Build** with parameters:
   - Environment: `dev`
   - Action: `apply`
   - Auto-Approve: `false` (for first deployment)

2. **Review Terraform Plan** at Approval Gate

3. **Approve** to proceed with infrastructure creation

4. **Monitor Progress**:
   - Terraform Apply: ~5-10 minutes
   - EC2 Initialization: ~5 minutes
   - Kafka Deployment: ~2-3 minutes

#### Expected Timeline

```
Total Deployment Time: ~15-20 minutes

└─ Terraform Init & Validate:  1-2 min
└─ Terraform Plan:             1-2 min
└─ Approval Gate:              Manual
└─ Terraform Apply:            5-10 min
└─ EC2 User Data Execution:    5 min
└─ Kafka Container Start:      2-3 min
└─ Validation:                 1-2 min
```

### Method 2: Manual Terraform Deployment

#### Step 1: Initialize

```bash
cd terraform/environments/dev
terraform init
```

#### Step 2: Plan

```bash
terraform plan -out=tfplan
terraform show tfplan | tee plan-output.txt
# Review plan-output.txt carefully
```

#### Step 3: Apply

```bash
terraform apply tfplan
```

#### Step 4: Capture Outputs

```bash
terraform output -json > outputs.json
cat outputs.json | jq '.kafka_bootstrap_servers.value'
```

---

## Post-Deployment

### 1. Wait for Initialization

```bash
# The user-data script takes ~5-7 minutes to complete
# You can monitor progress by SSHing to instances

ssh -i secrets/meracommerce-dev-kafka-key.pem ec2-user@<BROKER_PUBLIC_IP>
sudo tail -f /var/log/kafka-setup.log
```

### 2. Verify Kafka is Running

```bash
# On Kafka EC2 instance
docker ps
# Should show: kafka-1, node-exporter, kafka-exporter

docker logs kafka-1 --tail 100
```

### 3. Create Topics (if not auto-created)

```bash
# SSH to any Kafka broker
bash /opt/kafka/create-topics.sh
```

### 4. Configure EKS Access

#### Apply Kubernetes ConfigMap

```bash
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secret.yaml
```

#### Verify ConfigMap

```bash
kubectl get configmap kafka-config -o yaml
```

---

## Verification

### 1. Run Validation Script

```bash
ssh -i secrets/meracommerce-dev-kafka-key.pem ec2-user@<BROKER_IP>
bash /opt/kafka/validate-kafka.sh
```

### 2. Test from EKS

```bash
# Run test pod
kubectl run kafka-test --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- bash

# Inside pod:
kafka-broker-api-versions --bootstrap-server kafka-bootstrap.internal:9092
kafka-topics --bootstrap-server kafka-bootstrap.internal:9092 --list
```

### 3. Producer Test

```bash
kubectl run kafka-producer --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- \
  kafka-console-producer \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --topic customer-events

# Type messages and press Enter
```

### 4. Consumer Test

```bash
kubectl run kafka-consumer --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- \
  kafka-console-consumer \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --topic customer-events \
  --from-beginning
```

### 5. Monitoring Access

```bash
# Grafana
http://<BROKER_PUBLIC_IP>:3000
Username: admin
Password: admin123

# Prometheus
http://<BROKER_PUBLIC_IP>:9090
```

---

## Troubleshooting

### Issue: Terraform Apply Fails

**Symptoms:**
- Error creating resources
- Permission denied errors

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user

# Check Terraform state
terraform state list
```

### Issue: Kafka Container Not Starting

**Symptoms:**
- Container exits immediately
- Port conflicts

**Solution:**
```bash
# Check logs
docker logs kafka-1 --tail 200

# Check ports
sudo netstat -tulpn | grep -E '9092|9093|9094'

# Restart container
cd /opt/kafka
docker-compose restart
```

### Issue: Topics Not Created

**Symptoms:**
- `kafka-topics --list` shows no topics

**Solution:**
```bash
# Manually create topics
bash /opt/kafka/create-topics.sh

# Or create individually
docker exec kafka-1 kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic customer-events \
  --partitions 6 --replication-factor 3
```

### Issue: EKS Cannot Connect

**Symptoms:**
- Connection timeout from EKS pods
- DNS resolution failures

**Solution:**
```bash
# Verify Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id <ZONE_ID>

# Test DNS from EKS
kubectl run dns-test --rm -i --tty \
  --image busybox --restart=Never -- \
  nslookup kafka-bootstrap.internal

# Check security groups
aws ec2 describe-security-groups \
  --group-ids <KAFKA_SG_ID>
```

### Issue: High Latency

**Symptoms:**
- Slow producer/consumer performance

**Solution:**
```bash
# Check broker metrics
http://<BROKER_IP>:9308/metrics

# Increase instance size
# Edit terraform.tfvars:
kafka_instance_type = "t3.large"  # or m5.large

# Adjust JVM heap
kafka_heap_opts = "-Xms4G -Xmx4G"

# Re-apply Terraform
terraform apply
```

---

## Next Steps

1. **Configure Application**: See [Spring Boot Integration Guide](SPRING_BOOT_INTEGRATION.md)
2. **Setup Monitoring**: Configure Grafana dashboards
3. **Implement Security**: Enable SASL/SSL authentication
4. **Backup Strategy**: Configure S3 backups for Kafka data
5. **Disaster Recovery**: Review [Rollback Strategy](ROLLBACK_STRATEGY.md)

---

## Support

For issues or questions:
- Create GitHub issue
- Contact DevOps team: devops@meracommerce.com
- Slack: #kafka-infrastructure

# Quick Start Guide

**Get your Kafka cluster running in 20 minutes!**

---

## Prerequisites Check

```bash
# Verify tools
terraform version  # Should be >= 1.5.0
aws --version      # Should be >= 2.0
kubectl version    # For EKS integration

# Verify AWS credentials
aws sts get-caller-identity
```

---

## Step 1: Initial Setup (5 minutes)

### 1.1 Clone Repository

```bash
git clone <your-repo-url>
cd infra-kafka-platform
```

### 1.2 Create Terraform Backend

```bash
# Create S3 bucket for state
aws s3 mb s3://meracommerce-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket meracommerce-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locks
aws dynamodb create-table \
  --table-name meracommerce-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 1.3 Configure Variables

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars

# IMPORTANT: Update this line with your IP!
admin_cidr_blocks = ["YOUR_IP_ADDRESS/32"]
```

---

## Step 2: Deploy via Jenkins (Recommended)

### 2.1 Create Jenkins Job

1. Open Jenkins: `http://your-jenkins-url`
2. Click **New Item**
3. Enter name: `kafka-infrastructure`
4. Select **Pipeline**
5. Under **Pipeline**, choose **Pipeline script from SCM**
6. Set **SCM** to `Git`
7. Enter **Repository URL**
8. Set **Script Path** to `jenkins/Jenkinsfile`
9. Save

### 2.2 Run Deployment

1. Click **Build with Parameters**
2. Select:
   - Environment: `dev`
   - Action: `apply`
   - Auto-Approve: `false` (for first run)
3. Click **Build**

### 2.3 Approve Terraform Plan

1. Wait for "Approval Gate" stage
2. Review Terraform plan
3. Click **Approve**

### 2.4 Wait for Completion (~15 minutes)

Pipeline will:
- Create VPC and networking (≈7 min)
- Launch EC2 instances (≈2 min)
- Install Docker (≈2 min)
- Deploy Kafka (≈2 min)
- Create topics (≈1 min)
- Validate deployment (≈1 min)

---

## Step 3: Manual Deployment (Alternative)

```bash
cd terraform/environments/dev

# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Get outputs
terraform output -json > outputs.json
cat outputs.json | jq '.kafka_bootstrap_servers.value'
```

---

## Step 4: Verify Deployment (5 minutes)

### 4.1 Check Infrastructure

```bash
# From Terraform output
terraform output kafka_private_ips
terraform output kafka_bootstrap_servers
```

### 4.2 SSH to Kafka Broker

```bash
# Get SSH command from output
terraform output ssh_connection_commands

# Example:
ssh -i ../../../secrets/meracommerce-dev-kafka-key.pem ec2-user@<BROKER_PUBLIC_IP>
```

### 4.3 Verify Kafka is Running

```bash
# On Kafka broker
docker ps
# Should show: kafka-1, node-exporter, kafka-exporter

# Check logs
docker logs kafka-1 --tail 50

# Run validation
bash /opt/kafka/validate-kafka.sh
```

### 4.4 List Topics

```bash
docker exec kafka-1 kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list

# Should show:
# customer-events
# order-events
# catalog-events
# payment-events
# notification-events
# dead-letter-events
# audit-events
```

---

## Step 5: Configure EKS Integration (5 minutes)

### 5.1 Apply Kubernetes ConfigMaps

```bash
# From repository root
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secret.yaml
```

### 5.2 Verify ConfigMap

```bash
kubectl get configmap kafka-config -o yaml
```

### 5.3 Test from EKS

```bash
# Run test pod
kubectl run kafka-test --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- bash

# Inside pod:
kafka-broker-api-versions \
  --bootstrap-server kafka-bootstrap.internal:9092

kafka-topics \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --list
```

---

## Step 6: Producer/Consumer Test

### 6.1 Start Producer

```bash
kubectl run kafka-producer --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- \
  kafka-console-producer \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --topic customer-events

# Type messages:
{"customerId": "CUST-001", "action": "created"}
{"customerId": "CUST-002", "action": "updated"}
```

### 6.2 Start Consumer (in another terminal)

```bash
kubectl run kafka-consumer --rm -i --tty \
  --image confluentinc/cp-kafka:latest \
  --restart=Never -- \
  kafka-console-consumer \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --topic customer-events \
  --from-beginning

# Should see messages from producer
```

---

## Step 7: Access Monitoring

### 7.1 Grafana Dashboard

```bash
# Get broker public IP
terraform output kafka_public_ips

# Open in browser:
http://<BROKER_PUBLIC_IP>:3000

# Login:
Username: admin
Password: admin123

# Import dashboard:
# Upload monitoring/grafana/dashboards/kafka-overview.json
```

### 7.2 Prometheus

```bash
# Open in browser:
http://<BROKER_PUBLIC_IP>:9090

# Try query:
kafka_server_brokertopicmetrics_messagesin_total
```

---

## Step 8: Configure Spring Boot Application

### 8.1 Add Dependencies

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

### 8.2 Update application.yml

```yaml
spring:
  kafka:
    bootstrap-servers: kafka-bootstrap.internal:9092
```

See `kubernetes/spring-boot-example/application.yml` for complete configuration.

---

## Troubleshooting

### Issue: Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify permissions
aws iam get-user

# Check Terraform logs
export TF_LOG=DEBUG
terraform apply
```

### Issue: Kafka Not Starting

```bash
# SSH to broker
ssh -i secrets/*.pem ec2-user@<BROKER_IP>

# Check user-data logs
sudo tail -f /var/log/kafka-setup.log

# Check Docker
sudo systemctl status docker
docker ps -a

# Restart Kafka
cd /opt/kafka
docker-compose restart
```

### Issue: EKS Cannot Connect

```bash
# Test DNS from EKS
kubectl run dns-test --rm -i --tty \
  --image busybox --restart=Never -- \
  nslookup kafka-bootstrap.internal

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*kafka*"
```

---

## Next Steps

1. ✅ Infrastructure deployed
2. ✅ Kafka cluster running
3. ✅ Topics created
4. ✅ EKS integration configured
5. ✅ Monitoring accessible

**Now you can:**
- Integrate with Spring Boot microservices
- Configure producers and consumers
- Set up alerts in Grafana
- Implement backup strategy
- Review [SPRING_BOOT_INTEGRATION.md](docs/SPRING_BOOT_INTEGRATION.md)
- Review [COST_ESTIMATION.md](docs/COST_ESTIMATION.md)

---

## Cleanup (When Done Testing)

```bash
# Via Jenkins
# Run pipeline with Action: destroy

# Or manually
cd terraform/environments/dev
terraform destroy -auto-approve

# Or use script
bash scripts/rollback.sh dev
```

---

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** Create GitHub issue
- **Email:** devops@meracommerce.com
- **Slack:** #kafka-infrastructure

---

**Congratulations! Your Kafka cluster is ready for production! 🎉**

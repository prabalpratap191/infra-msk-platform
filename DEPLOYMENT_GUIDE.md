# Kafka EC2 Platform - Deployment Guide

This guide provides step-by-step instructions for deploying the Kafka infrastructure on AWS EC2.

## Table of Contents

1. [Prerequisites Setup](#prerequisites-setup)
2. [AWS Account Configuration](#aws-account-configuration)
3. [Terraform Deployment](#terraform-deployment)
4. [Jenkins Pipeline Setup](#jenkins-pipeline-setup)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Spring Boot Integration](#spring-boot-integration)
7. [Production Considerations](#production-considerations)

---

## 1. Prerequisites Setup

### 1.1 Install Required Tools

#### Terraform

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

#### AWS CLI

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

#### Git

```bash
# macOS
brew install git

# Linux
sudo yum install git -y  # Amazon Linux/RHEL
sudo apt-get install git -y  # Ubuntu/Debian

# Verify installation
git --version
```

### 1.2 Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# You will be prompted for:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (us-east-1)
# - Default output format (json)

# Verify configuration
aws sts get-caller-identity
```

---

## 2. AWS Account Configuration

### 2.1 Create EC2 Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name kafka-ec2-key \
  --query 'KeyMaterial' \
  --output text > kafka-ec2-key.pem

# Set permissions
chmod 400 kafka-ec2-key.pem

# Verify
ls -l kafka-ec2-key.pem
```

### 2.2 Identify VPC and Subnet

```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# List Subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<YOUR_VPC_ID>" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' \
  --output table

# Note down:
# - VPC ID
# - Subnet ID
# - VPC CIDR
```

### 2.3 Get Your Public IP Address

```bash
# Get your public IP
curl -s https://checkip.amazonaws.com

# Note this IP for admin access
```

### 2.4 Identify EKS Worker Security Group (Optional)

```bash
# If you have EKS cluster
aws eks describe-cluster --name <your-cluster-name> \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'

# Or list security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*eks*worker*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table
```

---

## 3. Terraform Deployment

### 3.1 Clone Repository

```bash
git clone <repository-url>
cd infra-kafka-ec2-platform
```

### 3.2 Configure Variables

```bash
cd terraform

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**terraform.tfvars** (update with your values):

```hcl
# AWS Configuration
aws_region  = "us-east-1"
environment = "dev"

# EC2 Configuration
instance_type = "t3.medium"
volume_size   = 40

# Network Configuration
vpc_id            = "vpc-0123456789abcdef0"  # YOUR VPC ID
subnet_id         = "subnet-0123456789abcdef0"  # YOUR SUBNET ID
private_vpc_cidr  = "10.0.0.0/16"  # YOUR VPC CIDR

# Security Configuration
eks_worker_security_group_id = "sg-0123456789abcdef0"  # YOUR EKS SG (optional)
admin_ip_address             = "203.0.113.1"  # YOUR PUBLIC IP
key_name                     = "kafka-ec2-key"  # YOUR KEY PAIR NAME

# Kafka Configuration
kafka_cluster_name = "kafka-cluster-dev"
kafka_broker_id    = 1
```

### 3.3 Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

### 3.4 Validate Configuration

```bash
# Validate syntax
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### 3.5 Plan Infrastructure

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan carefully
# You should see:
# - aws_security_group.kafka_sg will be created
# - aws_instance.kafka_ec2 will be created
```

### 3.6 Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Wait for completion (3-5 minutes)
# Note the outputs:
# - ec2_instance_id
# - ec2_public_ip
# - ec2_private_ip
# - kafka_bootstrap_server_internal
```

### 3.7 Save Outputs

```bash
# Save important values
echo "EC2_PUBLIC_IP=$(terraform output -raw ec2_public_ip)" > ../deployment.env
echo "EC2_PRIVATE_IP=$(terraform output -raw ec2_private_ip)" >> ../deployment.env
echo "EC2_INSTANCE_ID=$(terraform output -raw ec2_instance_id)" >> ../deployment.env

# View outputs anytime
terraform output
```

---

## 4. Jenkins Pipeline Setup

### 4.1 Install Jenkins Plugins

Required plugins:
- Pipeline
- Git
- AWS Steps
- SSH Agent
- Credentials Binding

```groovy
// Install via Jenkins UI: Manage Jenkins > Manage Plugins
// Or use Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin pipeline-aws git ssh-agent credentials-binding
```

### 4.2 Configure Jenkins Credentials

#### AWS Credentials

1. Navigate to: **Manage Jenkins** > **Manage Credentials**
2. Click: **Add Credentials**
3. Kind: **AWS Credentials**
4. ID: `aws-credentials`
5. Access Key ID: `<your-access-key>`
6. Secret Access Key: `<your-secret-key>`
7. Save

#### SSH Key for EC2

1. Navigate to: **Manage Jenkins** > **Manage Credentials**
2. Click: **Add Credentials**
3. Kind: **SSH Username with private key**
4. ID: `kafka-ec2-key`
5. Username: `ec2-user`
6. Private Key: **Enter directly** > Paste contents of `kafka-ec2-key.pem`
7. Save

### 4.3 Create Pipeline Job

1. Click: **New Item**
2. Name: `kafka-deployment-pipeline`
3. Type: **Pipeline**
4. OK

#### Pipeline Configuration

**Definition**: Pipeline script from SCM

**SCM**: Git

**Repository URL**: `<your-git-repository-url>`

**Branch**: `*/main` (or your branch)

**Script Path**: `Jenkinsfile`

**Save**

### 4.4 Run Pipeline

1. Click: **Build Now**
2. Monitor progress in **Console Output**
3. Wait for all stages to complete (10-15 minutes)

#### Expected Pipeline Output

```
Stage 1: Checkout - SUCCESS
Stage 2: Terraform Init - SUCCESS
Stage 3: Terraform Validate - SUCCESS
Stage 4: Terraform Plan - SUCCESS
Stage 5: Terraform Apply - SUCCESS
Stage 6: Get EC2 Instance Details - SUCCESS
Stage 7: Verify Docker Installation - SUCCESS
Stage 8: Deploy Kafka - SUCCESS
Stage 9: Create Kafka Topics - SUCCESS
Stage 10: Kafka Verification - SUCCESS
Stage 11: Print Connection Details - SUCCESS
Stage 12: Deployment Success - SUCCESS

==================================
KAFKA DEPLOYMENT SUCCESSFUL
==================================
```

---

## 5. Post-Deployment Verification

### 5.1 Connect to EC2 Instance

```bash
# Source environment variables
source deployment.env

# SSH to EC2
ssh -i kafka-ec2-key.pem ec2-user@$EC2_PUBLIC_IP
```

### 5.2 Verify Docker

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Check Docker service status
sudo systemctl status docker
```

### 5.3 Verify Kafka Container

```bash
# Check running containers
docker ps

# Should show:
# CONTAINER ID   IMAGE                    STATUS
# <id>           bitnami/kafka:latest     Up X minutes

# Check Kafka logs
docker logs kafka-server --tail 50

# Check Kafka health
docker exec kafka-server kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### 5.4 Verify Topics

```bash
# List all topics
docker exec kafka-server kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092

# Expected output:
# customer-events
# order-events
# catalog-events
# payment-events
# inventory-events
# notification-events
# dead-letter-events

# Describe a topic
docker exec kafka-server kafka-topics.sh \
  --describe \
  --bootstrap-server localhost:9092 \
  --topic customer-events
```

### 5.5 Test Producer/Consumer

```bash
# Open two terminal windows

# Terminal 1: Start consumer
docker exec -it kafka-server kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic customer-events \
  --from-beginning

# Terminal 2: Produce messages
echo "Test message 1" | docker exec -i kafka-server kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic customer-events

echo "Test message 2" | docker exec -i kafka-server kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic customer-events

# Verify messages appear in Terminal 1
```

---

## 6. Spring Boot Integration

### 6.1 Add Dependencies

Add to your `pom.xml`:

```xml
<dependencies>
    <!-- Spring Kafka -->
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka</artifactId>
    </dependency>
    
    <!-- JSON Support -->
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
    </dependency>
</dependencies>
```

### 6.2 Configure Application

Update `application.yml`:

```yaml
spring:
  kafka:
    bootstrap-servers: <EC2_PRIVATE_IP>:9092  # Use private IP from Terraform output
    consumer:
      group-id: ${spring.application.name}
      auto-offset-reset: earliest
    producer:
      acks: all
```

### 6.3 Test Connection

Create a simple test:

```java
@SpringBootTest
class KafkaConnectionTest {
    
    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;
    
    @Test
    void testKafkaConnection() throws Exception {
        // Send test message
        kafkaTemplate.send("customer-events", "test-key", "test-message")
            .get(10, TimeUnit.SECONDS);
        
        // If no exception, connection is successful
        assertTrue(true);
    }
}
```

---

## 7. Production Considerations

### 7.1 Security Enhancements

✅ **Enable SSL/TLS**

```bash
# Generate certificates
keytool -keystore kafka.server.keystore.jks -alias localhost -keyalg RSA -validity 365 -genkey

# Update docker-compose.yml with SSL configuration
```

✅ **Implement SASL Authentication**

```yaml
# Add to docker-compose.yml
environment:
  - KAFKA_CFG_SASL_ENABLED_MECHANISMS=PLAIN
  - KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL=PLAIN
```

### 7.2 Monitoring Setup

✅ **CloudWatch Agent**

```bash
# Install CloudWatch agent on EC2
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

# Configure metrics collection
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

✅ **JMX Exporter for Kafka**

```yaml
# Add to docker-compose.yml
environment:
  - KAFKA_JMX_PORT=9999
  - KAFKA_JMX_HOSTNAME=localhost
ports:
  - "9999:9999"
```

### 7.3 Backup Strategy

```bash
# Create backup script
cat > /home/ec2-user/backup-kafka.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/kafka-backups/$DATE"
mkdir -p $BACKUP_DIR

# Backup Kafka data
tar -czf $BACKUP_DIR/kafka-data.tar.gz /opt/kafka/data

# Upload to S3
aws s3 cp $BACKUP_DIR/kafka-data.tar.gz s3://your-backup-bucket/kafka/$DATE/

# Cleanup old backups (keep last 7 days)
find /opt/kafka-backups -type d -mtime +7 -exec rm -rf {} \;
EOF

chmod +x /home/ec2-user/backup-kafka.sh

# Add to crontab (daily at 2 AM)
0 2 * * * /home/ec2-user/backup-kafka.sh
```

### 7.4 High Availability

For production, consider:

- Multi-broker Kafka cluster (3+ brokers)
- Multi-AZ deployment
- Auto Scaling Groups
- Application Load Balancer
- Route 53 for DNS
- Replication factor > 1

### 7.5 Cost Optimization

```bash
# Use Spot instances for non-prod
# Add to main.tf:
instance_market_options {
  market_type = "spot"
  spot_options {
    max_price = "0.05"
  }
}

# Schedule EC2 start/stop for dev environments
# Stop at 6 PM
0 18 * * * aws ec2 stop-instances --instance-ids $EC2_INSTANCE_ID

# Start at 8 AM
0 8 * * 1-5 aws ec2 start-instances --instance-ids $EC2_INSTANCE_ID
```

---

## Troubleshooting Common Issues

### Issue 1: Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify VPC/Subnet IDs exist
aws ec2 describe-vpcs --vpc-ids <VPC_ID>
aws ec2 describe-subnets --subnet-ids <SUBNET_ID>

# Check Terraform state
terraform state list
```

### Issue 2: Cannot SSH to EC2

```bash
# Verify security group
aws ec2 describe-security-groups --group-ids <SG_ID>

# Check key permissions
ls -l kafka-ec2-key.pem  # Should be 400

# Test connection
ssh -v -i kafka-ec2-key.pem ec2-user@<EC2_IP>
```

### Issue 3: Kafka Container Not Starting

```bash
# Check logs
docker logs kafka-server

# Check resources
free -h
df -h

# Restart container
cd /opt/kafka
docker compose restart
```

### Issue 4: Cannot Connect from Spring Boot

```bash
# Verify security group allows port 9092 from your IP/VPC
aws ec2 describe-security-groups --group-ids <SG_ID>

# Test connectivity
telnet <EC2_PRIVATE_IP> 9092

# Check Kafka listeners
docker exec kafka-server grep advertised.listeners /opt/bitnami/kafka/config/server.properties
```

---

## Next Steps

✅ Deployment completed successfully

🔴 **Recommended Actions**:

1. Configure monitoring and alerting
2. Implement backup strategy
3. Enable SSL/TLS for production
4. Set up log aggregation (ELK/CloudWatch)
5. Create disaster recovery plan
6. Document operational procedures
7. Train team on Kafka operations

---

**Deployment completed! Your Kafka cluster is ready for use.**

For support, contact the platform team or refer to the [README.md](README.md).

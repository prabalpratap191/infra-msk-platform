# Quick Start Guide - Dynamic SSH Keys

## 🎯 Overview

This guide helps you deploy Kafka on EC2 with **dynamically generated SSH keys** - no manual key management required!

---

## ⚡ Prerequisites

✅ AWS account with appropriate permissions  
✅ Jenkins installed with **AWS credentials** configured  
✅ Terraform >= 1.0 installed  
✅ Git repository access

**Required Jenkins Credentials**:
- `jenkins-user` - AWS credentials (Access Key + Secret Key)

❌ **NOT Required** (previously needed):
- ~~SSH key credential~~ - Auto-generated now!
- ~~Manual EC2 key pair~~ - Created by Terraform!

---

## 🚀 Quick Start (5 Steps)

### Step 1: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Update with your values**:

```hcl
# Network Configuration
vpc_id            = "vpc-0123456789abcdef"     # Your VPC ID
subnet_id         = "subnet-0123456789abcdef"  # Your Subnet ID
private_vpc_cidr  = "10.0.0.0/16"              # Your VPC CIDR

# Security Configuration
admin_ip_address  = "203.0.113.1"              # Your public IP
# key_name - NOT NEEDED (auto-generated!)

# Optional: EKS Integration
eks_worker_security_group_id = ""              # Leave empty if no EKS

# Kafka Configuration
kafka_cluster_name = "kafka-cluster-dev"
kafka_broker_id    = 1
```

**Get your public IP**:
```bash
curl https://checkip.amazonaws.com
```

### Step 2: Apply Migration Changes

```bash
# Replace old Jenkinsfile with new one
mv Jenkinsfile Jenkinsfile.backup
mv Jenkinsfile.new Jenkinsfile

# Verify new files exist
ls -l terraform/ssh-key.tf
ls -l install-docker.sh
ls -l setup-kafka.sh
```

### Step 3: Configure Jenkins

**Only AWS credentials needed!**

1. Navigate to: **Manage Jenkins** → **Manage Credentials**
2. Verify credential exists:
   - **ID**: `jenkins-user`
   - **Type**: AWS Credentials
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key

If missing, create it:
- **Kind**: AWS Credentials
- **ID**: `jenkins-user` (⚠️ must be exact)
- **Description**: AWS credentials for Jenkins pipeline
- Add your AWS keys

### Step 4: Commit and Push

```bash
git add .
git commit -m "Implement dynamic SSH key generation"
git push origin main
```

### Step 5: Run Pipeline

1. Navigate to Jenkins pipeline job
2. Click **Build Now**
3. Monitor console output
4. Wait ~10-15 minutes for completion

---

## 📋 Pipeline Stages

The new pipeline automatically:

```
✅ 1. Checkout code from Git
✅ 2. Initialize Terraform
✅ 3. Validate Terraform configuration
✅ 4. Plan infrastructure changes
✅ 5. Apply infrastructure + Generate SSH key
✅ 6. Retrieve EC2 details + SSH key
✅ 7. Wait for EC2 + Test SSH connectivity
✅ 8. Install Docker via SSH
✅ 9. Verify Docker installation
✅ 10. Setup Kafka via SSH
✅ 11. Wait for Kafka startup
✅ 12. Create Kafka topics
✅ 13. Verify Kafka installation
✅ 14. Print connection details
✅ 15. Deployment success summary
```

---

## 🔑 How It Works

### Automatic SSH Key Generation

```
Jenkins Pipeline Starts
        ↓
Terraform Apply
        ↓
    ┌──────────────────┐
    │ 1. Generate RSA key  │
    │ 2. Create AWS key   │
    │ 3. Save private key │
    │ 4. Attach to EC2    │
    └──────────────────┘
        ↓
SSH Key Available
        ↓
Jenkins Uses Key
        ↓
Install Docker & Kafka
        ↓
Deployment Complete
```

**Key File Location**: `terraform/kafka-ec2-private-key.pem`

---

## ✅ Success Indicators

### Pipeline Output

```
==================================
   KAFKA DEPLOYMENT SUCCESSFUL
==================================

Kafka Status: ✓ RUNNING
EC2 Status: ✓ RUNNING
SSH Key: ✓ DYNAMICALLY GENERATED

Topics Created:
  • customer-events
  • order-events
  • catalog-events
  • payment-events
  • inventory-events
  • notification-events
  • dead-letter-events

✓ Ready for Spring Boot Integration
==================================
```

### SSH Access

```bash
# Connect to EC2
cd terraform
ssh -i kafka-ec2-private-key.pem ec2-user@<EC2_PUBLIC_IP>

# Verify Docker
sudo docker ps

# Verify Kafka
sudo docker logs kafka-server

# List topics
sudo docker exec kafka-server kafka-topics.sh \
  --list --bootstrap-server localhost:9092
```

---

## 🔧 Post-Deployment

### Get Connection Details

```bash
cd terraform

# EC2 Public IP
terraform output ec2_public_ip

# EC2 Private IP
terraform output ec2_private_ip

# Kafka Bootstrap Server (Internal)
terraform output kafka_bootstrap_server_internal

# SSH Command
terraform output ssh_connection_command
```

### Spring Boot Configuration

```yaml
spring:
  kafka:
    bootstrap-servers: <EC2_PRIVATE_IP>:9092
    consumer:
      group-id: my-consumer-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
```

### Test Kafka

```bash
# SSH to EC2
cd terraform
ssh -i kafka-ec2-private-key.pem ec2-user@$(terraform output -raw ec2_public_ip)

# Produce test message
echo "test message" | sudo docker exec -i kafka-server \
  kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic customer-events

# Consume messages
sudo docker exec kafka-server kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic customer-events \
  --from-beginning
```

---

## 🔍 Troubleshooting

### Issue: Private key file not found

**Symptom**: `kafka-ec2-private-key.pem: No such file`

**Solution**:
```bash
cd terraform
terraform output -raw ssh_private_key > kafka-ec2-private-key.pem
chmod 400 kafka-ec2-private-key.pem
```

### Issue: Permission denied (publickey)

**Symptom**: SSH connection fails

**Solution**:
```bash
chmod 400 terraform/kafka-ec2-private-key.pem
```

### Issue: Connection timeout

**Symptom**: Cannot connect to EC2

**Solutions**:
1. Wait longer (EC2 might still be initializing)
2. Check security group allows SSH from your IP
3. Verify EC2 is running: `terraform output ec2_instance_id`

### Issue: Docker installation fails

**Symptom**: Docker install stage fails in pipeline

**Solution**:
```bash
# SSH to EC2 and install manually
ssh -i terraform/kafka-ec2-private-key.pem ec2-user@<EC2_IP>
sudo yum install -y docker
sudo systemctl start docker
sudo docker --version
```

---

## 📚 Additional Resources

- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Detailed migration explanation
- **[README.md](README.md)** - Complete project documentation
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Full deployment guide
- **[KAFKA_CONFIG.md](KAFKA_CONFIG.md)** - Kafka configuration details

---

## 🪣 Clean Up

### Destroy Infrastructure

```bash
cd terraform
terraform destroy

# Confirm: yes
```

This will:
- ❌ Destroy EC2 instance
- ❌ Delete SSH key pair from AWS
- ❌ Remove security group
- ❌ Delete local private key file

---

## 🎉 What's Different?

### Before
```
1. Create EC2 key pair manually in AWS Console
2. Download .pem file
3. Add to Jenkins as credential
4. Configure terraform.tfvars with key name
5. Run pipeline
6. Hope userdata completes successfully
7. No visibility into installation process
```

### Now
```
1. Configure terraform.tfvars (no key name!)
2. Run pipeline
3. SSH key auto-generated by Terraform
4. Docker installed via SSH (visible logs)
5. Kafka deployed via SSH (visible logs)
6. Complete visibility and control
```

---

## ✅ Benefits Summary

| Feature | Benefit |
|---------|--------|
| **Auto SSH Key** | No manual key management |
| **Unique Keys** | Each deployment gets new key |
| **SSH Install** | Real-time logs in Jenkins |
| **Easy Debug** | Installation visible in console |
| **Less Config** | One less Jenkins credential |
| **Security** | Keys auto-rotate per deployment |
| **Cleanup** | Keys destroyed with infrastructure |

---

**You're ready to deploy!** 🚀

Run the pipeline and watch as it automatically generates SSH keys, provisions EC2, and deploys Kafka - all without manual intervention!

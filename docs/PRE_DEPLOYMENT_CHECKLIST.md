# Pre-Deployment Checklist

**Complete this checklist before running the Jenkins pipeline or Terraform deployment.**

---

## ☑️ AWS Account Setup

- [ ] AWS Account has sufficient permissions
  - EC2 (create instances, volumes, security groups)
  - VPC (create VPC, subnets, route tables, NAT gateways)
  - Route53 (create hosted zones, DNS records)
  - CloudWatch (create log groups, alarms)
  - IAM (create roles, policies)
  - S3 (for Terraform state)
  - DynamoDB (for Terraform state locking)

- [ ] AWS CLI configured with correct credentials
  ```bash
  aws sts get-caller-identity
  # Should show your account ID and user ARN
  ```

- [ ] AWS region is `us-east-1` (or update `terraform.tfvars`)
  ```bash
  aws configure get region
  # Should show: us-east-1
  ```

---

## ☑️ SSH Key Pair

- [ ] SSH key pair `kafka-key` exists in AWS EC2 (us-east-1)
  ```bash
  aws ec2 describe-key-pairs --key-names kafka-key --region us-east-1
  ```

- [ ] If not, create it:
  ```bash
  aws ec2 create-key-pair \
    --key-name kafka-key \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > kafka-key.pem
  
  chmod 400 kafka-key.pem
  ```

- [ ] Private key file saved securely
- [ ] **OR** Update `ssh_key_name` in `terraform.tfvars` with your existing key name

**See:** [SSH_KEY_SETUP.md](SSH_KEY_SETUP.md) for detailed instructions

---

## ☑️ EKS Cluster

- [ ] EKS cluster `meracommerce-dev-cluster` exists in `us-east-1`
  ```bash
  aws eks describe-cluster \
    --name meracommerce-dev-cluster \
    --region us-east-1
  ```

- [ ] **OR** Update `eks_cluster_name` in `terraform.tfvars` with your cluster name
- [ ] EKS cluster is in the same region as Kafka infrastructure
- [ ] Note the EKS security group ID (will be needed for Kafka security group rules)

---

## ☑️ Terraform Backend (Optional but Recommended)

- [ ] S3 bucket for Terraform state exists
  ```bash
  aws s3 ls s3://meracommerce-terraform-state
  ```

- [ ] If not, create it:
  ```bash
  aws s3 mb s3://meracommerce-terraform-state --region us-east-1
  aws s3api put-bucket-versioning \
    --bucket meracommerce-terraform-state \
    --versioning-configuration Status=Enabled
  ```

- [ ] DynamoDB table for state locking exists
  ```bash
  aws dynamodb describe-table \
    --table-name meracommerce-terraform-locks \
    --region us-east-1
  ```

- [ ] If not, create it:
  ```bash
  aws dynamodb create-table \
    --table-name meracommerce-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
  ```

**Note:** `setup.sh` script can create these automatically

---

## ☑️ Terraform Configuration

- [ ] File `terraform/environments/dev/terraform.tfvars` exists
  - If not, copy from `terraform.tfvars.example`
  ```bash
  cd terraform/environments/dev
  cp terraform.tfvars.example terraform.tfvars
  ```

- [ ] Update critical values in `terraform.tfvars`:

### 🔴 **REQUIRED** - Update these values:

```hcl
# Your public IP for SSH access (security!)
admin_cidr_blocks = ["YOUR_IP_HERE/32"]

# Your SSH key name
ssh_key_name = "kafka-key"  # or your key name

# Your EKS cluster name
eks_cluster_name = "meracommerce-dev-cluster"  # or your cluster name
```

**Get your public IP:**
```bash
curl https://api.ipify.org
# Use the returned IP with /32 suffix
# Example: admin_cidr_blocks = ["203.0.113.50/32"]
```

### 🟡 **OPTIONAL** - Review and adjust if needed:

```hcl
project_name     = "meracommerce"
environment      = "dev"
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
kafka_version    = "3.6.1"
instance_type    = "t3.medium"
volume_size      = 100
```

---

## ☑️ Jenkins Setup (If using CI/CD)

- [ ] Jenkins server is running
- [ ] Required Jenkins plugins installed:
  - Pipeline
  - AWS Steps Plugin
  - Terraform Plugin
  - Git Plugin

- [ ] AWS credentials configured in Jenkins:
  - Credential ID: `aws-credentials`
  - Type: AWS Credentials
  - Access Key ID: `AWS_ACCESS_KEY_ID`
  - Secret Access Key: `AWS_SECRET_ACCESS_KEY`

- [ ] Jenkins environment variables set:
  ```groovy
  AWS_REGION = "us-east-1"
  ENVIRONMENT = "dev"
  ```

- [ ] Jenkins has network access to GitHub repository
- [ ] Jenkins has Terraform installed (>= 1.5.0)
  ```bash
  terraform --version
  ```

---

## ☑️ Network & Security

- [ ] VPC CIDR `10.0.0.0/16` doesn't conflict with existing VPCs
  ```bash
  aws ec2 describe-vpcs --region us-east-1
  ```

- [ ] Private IPs for Kafka brokers are available:
  - `10.0.101.10` (Broker 1)
  - `10.0.102.10` (Broker 2)
  - `10.0.103.10` (Broker 3)

- [ ] Admin CIDR blocks updated with your actual IP (security!)
- [ ] Understand the difference:
  - **Internal access**: Port 9092 (from EKS only)
  - **External access**: Port 9094 (controlled by `enable_public_access`)

---

## ☑️ Cost Awareness

- [ ] Reviewed [COST_ESTIMATION.md](COST_ESTIMATION.md)
- [ ] Understand monthly costs: **~$189 - $248/month**
  - 3x t3.medium instances
  - 300GB EBS storage (gp3)
  - NAT Gateway
  - Data transfer

- [ ] Budget alerts configured (optional):
  ```bash
  aws budgets create-budget \
    --account-id YOUR_ACCOUNT_ID \
    --budget file://budget.json
  ```

---

## ☑️ Documentation Review

- [ ] Read [QUICK_START.md](../QUICK_START.md) for step-by-step guide
- [ ] Read [DEPLOYMENT.md](DEPLOYMENT.md) for detailed procedures
- [ ] Read [ROLLBACK_STRATEGY.md](ROLLBACK_STRATEGY.md) for disaster recovery
- [ ] Read [SSH_KEY_SETUP.md](SSH_KEY_SETUP.md) for SSH access

---

## ☑️ Final Checks

- [ ] All team members aware of deployment
- [ ] Maintenance window scheduled (if production)
- [ ] Rollback plan understood
- [ ] Monitoring dashboards ready
- [ ] Support contacts available

---

## ✅ Ready to Deploy!

Once all items are checked, proceed with deployment:

### Option 1: Jenkins Pipeline

```bash
# Trigger Jenkins pipeline
# - Navigate to Jenkins job
# - Click "Build with Parameters"
# - Select ACTION: apply
# - Select ENVIRONMENT: dev
# - Click "Build"
```

### Option 2: Manual Deployment

```bash
# Run setup script (optional)
bash setup.sh

# Navigate to environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review plan
terraform plan

# Apply (with approval)
terraform apply

# Wait ~20 minutes for complete deployment
```

---

## Post-Deployment Verification

After successful deployment:

- [ ] Verify Terraform outputs
  ```bash
  terraform output
  ```

- [ ] SSH to Kafka brokers
  ```bash
  ssh -i kafka-key.pem ec2-user@$(terraform output -raw kafka_private_ips | jq -r '.[0]')
  ```

- [ ] Check Kafka containers
  ```bash
  docker ps
  docker logs kafka-1
  ```

- [ ] List topics
  ```bash
  docker exec -it kafka-1 kafka-topics.sh \
    --bootstrap-server localhost:9092 --list
  ```

- [ ] Test from EKS
  ```bash
  kubectl run kafka-test --rm -it --restart=Never \
    --image=bitnami/kafka:3.6.1 -- \
    kafka-topics.sh --bootstrap-server kafka-bootstrap.internal:9092 --list
  ```

- [ ] Access monitoring dashboards
  - Grafana: `http://<broker-public-ip>:3000`
  - Prometheus: `http://<broker-public-ip>:9090`

---

## Troubleshooting Resources

**If deployment fails:**

1. Check Terraform logs
2. Check Jenkins console output
3. Review CloudWatch logs: `/aws/ec2/kafka-setup`
4. SSH to EC2 and check: `/var/log/kafka-setup.log`
5. Review [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section

**Common Issues:**

- **SSH key not found**: Create key pair (see SSH_KEY_SETUP.md)
- **VPC CIDR conflict**: Change `vpc_cidr` in terraform.tfvars
- **Permission denied**: Check AWS credentials and IAM permissions
- **Timeout**: Check security groups and network connectivity

---

## Support

- **Documentation**: See [docs/](.) folder
- **Issues**: Create GitHub issue
- **Team**: Contact DevOps team
- **Emergency**: Follow rollback procedures

---

**🚀 Happy Deploying!**

# MSK Platform Deployment Guide

This guide provides step-by-step instructions for deploying the MSK platform infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Deployment Steps](#pre-deployment-steps)
- [Deployment Options](#deployment-options)
- [Post-Deployment Steps](#post-deployment-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Software Requirements

- **Terraform**: >= 1.6.0
- **AWS CLI**: >= 2.0
- **kubectl**: >= 1.28 (for EKS integration)
- **jq**: For JSON parsing
- **Git**: For version control

### AWS Requirements

- AWS Account with appropriate permissions
- IAM user/role with the following permissions:
  - MSK: Full access
  - VPC: Create/modify VPCs, subnets, security groups
  - KMS: Create/manage keys
  - CloudWatch: Create log groups, dashboards, alarms
  - IAM: Create policies and roles
  - EC2: Manage network interfaces

### Access Requirements

- AWS credentials configured (`aws configure`)
- S3 bucket for Terraform state (created separately)
- DynamoDB table for state locking (created separately)

## Pre-Deployment Steps

### 1. Create Backend Resources

Create S3 bucket and DynamoDB table for Terraform state management:

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket terraform-state-msk-platform-dev \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-msk-platform-dev \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-msk-platform-dev \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock-msk-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Clone Repository

```bash
git clone <repository-url>
cd infra-msk-platform
```

### 3. Configure Variables

Update `terraform/environments/dev/terraform.tfvars`:

```hcl
# Update with your specific values
project_name = "msk-platform"
environment  = "dev"
owner        = "YourTeam"

# Update EKS security group ID if available
# eks_cluster_security_group_id = "sg-xxxxxxxxx"
```

## Deployment Options

### Option 1: Local Deployment (Recommended for testing)

#### Step 1: Initialize Terraform

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Verify initialization
terraform --version
```

#### Step 2: Review Plan

```bash
# Generate execution plan
terraform plan -out=tfplan

# Review the plan carefully
# Expected resources: ~30-40 resources
```

#### Step 3: Apply Configuration

```bash
# Apply the configuration
terraform apply tfplan

# Wait for completion (~15-20 minutes)
```

#### Step 4: Create Kafka Topics

```bash
# Navigate to scripts directory
cd ../../../scripts

# Make scripts executable
chmod +x create-kafka-topics.sh

# Run topic creation
./create-kafka-topics.sh
```

### Option 2: Jenkins Deployment (Recommended for production)

#### Step 1: Configure Jenkins

1. Create new pipeline job
2. Configure repository URL
3. Set pipeline script path: `Jenkinsfile`

#### Step 2: Run Pipeline

1. Click "Build with Parameters"
2. Select:
   - **Environment**: dev
   - **Action**: apply
   - **AUTO_APPROVE**: false (for safety)
   - **CREATE_TOPICS**: true
3. Click "Build"
4. Approve at the approval gate

#### Step 3: Monitor Progress

- View console output
- Check each stage completion
- Review outputs at the end

## Post-Deployment Steps

### 1. Retrieve Connection Details

```bash
cd terraform/environments/dev

# Get bootstrap servers
terraform output bootstrap_brokers_sasl_iam

# Get cluster ARN
terraform output msk_cluster_arn

# Get all outputs
terraform output -json > outputs.json
```

### 2. Update Kubernetes ConfigMaps

Replace placeholders in `kubernetes/configmaps/kafka-configmap.yaml`:

```bash
# Get bootstrap servers
BOOTSTRAP_SERVERS=$(terraform output -raw bootstrap_brokers_sasl_iam)

# Update ConfigMaps
sed -i "s|<BOOTSTRAP_SERVERS_PLACEHOLDER>|$BOOTSTRAP_SERVERS|g" \
  ../../../kubernetes/configmaps/kafka-configmap.yaml

# Apply ConfigMaps
kubectl apply -f ../../../kubernetes/configmaps/kafka-configmap.yaml
```

### 3. Create Namespaces

```bash
# Create all microservice namespaces
kubectl create namespace customer-service-ns
kubectl create namespace order-service-ns
kubectl create namespace catalog-service-ns
kubectl create namespace order-history-service-ns
kubectl create namespace notification-service-ns
kubectl create namespace payments-service-ns
```

### 4. Apply Service Accounts

Update AWS account ID in `kubernetes/service-accounts/service-account.yaml`:

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Update service accounts
sed -i "s|<AWS_ACCOUNT_ID>|$AWS_ACCOUNT_ID|g" \
  ../../../kubernetes/service-accounts/service-account.yaml

# Apply service accounts
kubectl apply -f ../../../kubernetes/service-accounts/service-account.yaml
```

### 5. Configure IAM Roles for Service Accounts (IRSA)

Create IAM roles for each namespace:

```bash
# Example for customer-service-ns
aws iam create-role \
  --role-name msk-dev-customer-service-ns-role \
  --assume-role-policy-document file://trust-policy.json

# Attach MSK client policy
MSK_POLICY_ARN=$(terraform output -raw msk_client_iam_policy_arn)

aws iam attach-role-policy \
  --role-name msk-dev-customer-service-ns-role \
  --policy-arn $MSK_POLICY_ARN

# Repeat for all namespaces
```

## Verification

### 1. Run Verification Scripts

```bash
cd scripts

# Verify cluster health
./verify-msk-cluster.sh

# Verify connectivity
./verify-connectivity.sh
```

### 2. Test Kafka Connection

```bash
# From an EC2 instance or EKS pod
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --list
```

### 3. Verify Topics

```bash
# List all topics
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --list

# Describe a specific topic
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --describe \
  --topic order-create-events
```

### 4. Check CloudWatch

- Navigate to CloudWatch Console
- Check dashboards under `msk-platform-dev-msk-dashboard`
- Verify metrics are being published
- Check logs in `/aws/msk/msk-cluster-dev`

## Troubleshooting

### Issue: Terraform Init Fails

**Cause**: Backend S3 bucket doesn't exist

**Solution**:
```bash
# Create the backend bucket first
aws s3api create-bucket --bucket terraform-state-msk-platform-dev --region us-east-1
```

### Issue: MSK Cluster Creation Timeout

**Cause**: Cluster takes 15-20 minutes to create

**Solution**: Wait patiently. Check AWS Console for progress.

### Issue: Topic Creation Fails

**Cause**: Cluster not fully ready or IAM permissions missing

**Solution**:
```bash
# Wait for cluster to be ACTIVE
aws kafka describe-cluster --cluster-arn $CLUSTER_ARN --query 'ClusterInfo.State'

# Verify IAM credentials
aws sts get-caller-identity
```

### Issue: Cannot Connect from EKS

**Cause**: Security group rules not configured

**Solution**:
```bash
# Update security group to allow EKS traffic
aws ec2 authorize-security-group-ingress \
  --group-id $MSK_SG_ID \
  --protocol tcp \
  --port 9098 \
  --source-group $EKS_SG_ID
```

## Next Steps

1. Configure monitoring alerts
2. Set up backup and disaster recovery
3. Implement topic access controls
4. Configure consumer lag monitoring
5. Set up automated topic management

## Support

For issues or questions:
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Review CloudWatch logs
- Contact DevOps team

# MSK Platform Quick Start Guide

Get your MSK cluster up and running in 30 minutes!

## 🚀 Quick Setup

### Step 1: Prerequisites (5 minutes)

```bash
# Install required tools
brew install terraform awscli jq  # macOS
# or
sudo apt-get install terraform awscli jq  # Linux

# Verify installations
terraform --version  # Should be >= 1.6.0
aws --version        # Should be >= 2.0

# Configure AWS credentials
aws configure
```

### Step 2: Create Backend (5 minutes)

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-msk-platform-dev \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-msk-platform-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-msk-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Deploy Infrastructure (15 minutes)

```bash
# Clone or navigate to repository
cd infra-msk-platform/terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (will take ~15-20 minutes)
terraform apply
```

**☕ Coffee break! MSK cluster creation takes 15-20 minutes.**

### Step 4: Create Kafka Topics (2 minutes)

```bash
# Navigate to scripts
cd ../../../scripts

# Make scripts executable
chmod +x *.sh

# Create topics
./create-kafka-topics.sh
```

### Step 5: Verify Installation (3 minutes)

```bash
# Verify cluster health
./verify-msk-cluster.sh

# Verify connectivity
./verify-connectivity.sh

# Get bootstrap servers
cd ../terraform/environments/dev
terraform output bootstrap_brokers_sasl_iam
```

## ✅ Success!

Your MSK cluster is now ready! Here's what you have:

- ✅ MSK Cluster with 3 brokers across 3 AZs
- ✅ TLS encryption in-transit
- ✅ IAM authentication enabled
- ✅ 6 Kafka topics created and ready
- ✅ CloudWatch monitoring and dashboards
- ✅ Auto-scaling storage
- ✅ Production-ready configuration

## 📝 Next Steps

### 1. Update Kubernetes ConfigMaps

```bash
# Get bootstrap servers
BOOTSTRAP=$(terraform output -raw bootstrap_brokers_sasl_iam)

# Update ConfigMaps
cd ../../../kubernetes/configmaps
sed -i "s|<BOOTSTRAP_SERVERS_PLACEHOLDER>|$BOOTSTRAP" kafka-configmap.yaml

# Apply to Kubernetes
kubectl apply -f kafka-configmap.yaml
```

### 2. Create Namespaces

```bash
kubectl create namespace customer-service-ns
kubectl create namespace order-service-ns
kubectl create namespace catalog-service-ns
kubectl create namespace notification-service-ns
kubectl create namespace payments-service-ns
```

### 3. Set Up Service Accounts (IRSA)

```bash
# Get AWS account ID
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# Update service accounts
cd ../service-accounts
sed -i "s|<AWS_ACCOUNT_ID>|$AWS_ACCOUNT|g" service-account.yaml

# Apply service accounts
kubectl apply -f service-account.yaml
```

### 4. Deploy Your First Application

```bash
cd ../../spring-boot-examples

# Update application.properties with bootstrap servers
sed -i "s|spring.kafka.bootstrap-servers=.*|spring.kafka.bootstrap-servers=$BOOTSTRAP|" application.properties

# Build and run
mvn clean install
mvn spring-boot:run
```

## 🧪 Test Your Setup

### Test 1: Produce Messages

```bash
# Create test producer config
cat > /tmp/client.properties << EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

# Produce test message
echo "Hello MSK!" | kafka-console-producer.sh \
  --bootstrap-server $BOOTSTRAP \
  --producer.config /tmp/client.properties \
  --topic order-create-events
```

### Test 2: Consume Messages

```bash
# Consume messages
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP \
  --consumer.config /tmp/client.properties \
  --topic order-create-events \
  --from-beginning
```

### Test 3: List Topics

```bash
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP \
  --command-config /tmp/client.properties \
  --list
```

Expected output:
```
catalog-updation-events
customer-orderstatus-events
dead-letter-events
notification-events
order-create-events
payment-confirm-events
```

## 📊 View Monitoring

### CloudWatch Dashboard

1. Go to AWS Console → CloudWatch → Dashboards
2. Find: `msk-platform-dev-msk-dashboard`
3. View real-time metrics

### Metrics to Watch

- **Broker CPU**: Should be < 70%
- **Disk Usage**: Should be < 70%
- **Under-Replicated Partitions**: Should be 0
- **Offline Partitions**: Should be 0

### Logs

```bash
# View CloudWatch logs
aws logs tail /aws/msk/msk-cluster-dev --follow
```

## 💰 Cost Overview

Your current setup costs approximately:

- **Monthly**: ~$229 USD
- **Daily**: ~$7.50 USD
- **Hourly**: ~$0.31 USD

> See [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for detailed breakdown

## 🛑 Cleanup (When Done Testing)

```bash
# Delete topics (optional)
kafka-topics.sh --bootstrap-server $BOOTSTRAP \
  --command-config /tmp/client.properties \
  --delete --topic order-create-events

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Delete backend resources (optional)
aws s3 rm s3://terraform-state-msk-platform-dev --recursive
aws s3api delete-bucket --bucket terraform-state-msk-platform-dev
aws dynamodb delete-table --table-name terraform-state-lock-msk-platform
```

## 🐛 Troubleshooting

### Issue: Terraform Init Fails

```bash
# Ensure backend bucket exists
aws s3 ls s3://terraform-state-msk-platform-dev

# If not, create it (see Step 2)
```

### Issue: Cannot Connect to MSK

```bash
# Check cluster state
aws kafka list-clusters --region us-east-1

# Verify security groups
aws ec2 describe-security-groups --group-ids <MSK_SG_ID>
```

### Issue: Topics Not Created

```bash
# Wait for cluster to be ACTIVE
CLUSTER_ARN=$(terraform output -raw msk_cluster_arn)
aws kafka describe-cluster --cluster-arn $CLUSTER_ARN --query 'ClusterInfo.State'

# Retry topic creation
./scripts/create-kafka-topics.sh
```

## 📚 Resources

- [Full Deployment Guide](docs/DEPLOYMENT.md)
- [Cost Estimation](docs/COST_ESTIMATION.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Rollback Strategy](docs/ROLLBACK.md)
- [Spring Boot Examples](spring-boot-examples/README-SpringBoot.md)

## ❓ Getting Help

If you encounter issues:

1. Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Review CloudWatch logs
3. Run verification scripts
4. Contact DevOps team

## 🎉 Congratulations!

You now have a production-ready MSK cluster running on AWS!

**What's Next?**

- Deploy your microservices
- Set up monitoring alerts
- Configure backup strategies
- Implement topic access controls
- Scale based on traffic patterns

Happy streaming! 🚀

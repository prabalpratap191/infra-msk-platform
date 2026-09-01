# MeraCommerce MSK Integration - Quick Reference

## 🚀 Quick Start for meracommerce-dev-cluster

This MSK cluster is specifically configured to work with your existing **meracommerce-dev-cluster** EKS cluster.

### 📝 Prerequisites Checklist

- [ ] EKS cluster `meracommerce-dev-cluster` is running
- [ ] Namespaces exist (already created - no action needed):
  - customer-service-ns
  - order-service-ns
  - catalog-service-ns
  - order-history-service-ns
  - notification-service-ns
  - payments-service-ns
- [ ] kubectl configured: `aws eks update-kubeconfig --name meracommerce-dev-cluster --region us-east-1`
- [ ] AWS CLI configured with admin permissions

## 🛠️ Deployment Steps

### 1. Get EKS Security Group (Once EKS is available)

```bash
EKS_SG=$(aws eks describe-cluster \
  --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

echo "EKS Security Group: $EKS_SG"
```

### 2. Update Terraform Configuration

```bash
cd terraform/environments/dev

# Edit terraform.tfvars and update:
# eks_cluster_security_group_id = "<EKS_SG from step 1>"
```

### 3. Deploy MSK Infrastructure

```bash
# Backend setup (one-time)
aws s3api create-bucket --bucket terraform-state-msk-platform-dev --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-lock-msk-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

# Deploy infrastructure
terraform init
terraform plan
terraform apply  # Takes ~15-20 minutes
```

### 4. Configure EKS Integration

```bash
cd ../../../scripts
chmod +x *.sh

# Run integration
./configure-eks-integration.sh

# Setup IRSA
./setup-eks-irsa.sh
```

### 5. Verify

```bash
# Check ConfigMaps
kubectl get configmap kafka-config -n customer-service-ns

# Check ServiceAccounts
kubectl get sa kafka-service-account -n customer-service-ns -o yaml

# Test connectivity
kubectl run kafka-test \
  --image=confluentinc/cp-kafka:latest \
  --serviceaccount=kafka-service-account \
  -n customer-service-ns --rm -it --restart=Never -- bash
```

## 📊 Kafka Topics

All topics are pre-configured with:
- **Partitions**: 6
- **Replication Factor**: 3
- **Min ISR**: 2
- **Retention**: 7 days

| Topic | Purpose |
|-------|----------|
| customer-orderstatus-events | Customer order status updates |
| order-create-events | New order creation events |
| catalog-updation-events | Product catalog updates |
| payment-confirm-events | Payment confirmations |
| notification-events | Notification messages |
| dead-letter-events | Failed message handling |

## ⚙️ Microservice Configuration

### Spring Boot Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customer-service
  namespace: customer-service-ns
spec:
  template:
    spec:
      serviceAccountName: kafka-service-account  # ⭐ Required!
      containers:
      - name: customer-service
        image: your-registry/customer-service:latest
        envFrom:
        - configMapRef:
            name: kafka-config  # ⭐ Auto-configured by scripts
```

### Spring Boot application.yaml

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    properties:
      security.protocol: ${KAFKA_SECURITY_PROTOCOL}
      sasl.mechanism: ${KAFKA_SASL_MECHANISM}
      sasl.jaas.config: ${KAFKA_SASL_JAAS_CONFIG}
      sasl.client.callback.handler.class: ${KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS}
```

### Required Dependencies (pom.xml)

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
<dependency>
    <groupId>software.amazon.msk</groupId>
    <artifactId>aws-msk-iam-auth</artifactId>
    <version>1.1.9</version>
</dependency>
```

## 🔧 Automated Scripts

All scripts are in `scripts/` directory:

| Script | Purpose |
|--------|----------|
| `configure-eks-integration.sh` | Configure MSK-EKS connectivity |
| `setup-eks-irsa.sh` | Setup IAM roles for service accounts |
| `create-kafka-topics.sh` | Create all Kafka topics |
| `verify-msk-cluster.sh` | Verify MSK cluster health |
| `verify-connectivity.sh` | Test network connectivity |
| `rollback.sh` | Rollback infrastructure changes |

## 🐛 Common Issues

### Issue: Connection Timeout from Pods

**Cause**: Security group not configured

**Fix**:
```bash
./scripts/configure-eks-integration.sh
```

### Issue: Authentication Failed

**Cause**: IRSA not configured

**Fix**:
```bash
./scripts/setup-eks-irsa.sh
```

### Issue: ConfigMap Not Found

**Cause**: Integration script not run

**Fix**:
```bash
./scripts/configure-eks-integration.sh
```

## 💰 Cost Summary

**Dev Environment**:
- MSK Cluster: $140/month
- Storage: $30/month
- Networking: $42/month
- Other: $17/month
- **Total: ~$229/month**

See [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for details.

## 📚 Documentation

- **Detailed Integration**: [docs/EKS-INTEGRATION-GUIDE.md](docs/EKS-INTEGRATION-GUIDE.md)
- **Deployment Guide**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Rollback**: [docs/ROLLBACK.md](docs/ROLLBACK.md)
- **Spring Boot Examples**: [spring-boot-examples/README-SpringBoot.md](spring-boot-examples/README-SpringBoot.md)

## ✅ Verification Checklist

After deployment:

- [ ] MSK cluster is ACTIVE
- [ ] All 6 topics created
- [ ] Security groups configured
- [ ] ConfigMaps exist in all namespaces
- [ ] ServiceAccounts annotated with IAM roles
- [ ] Connectivity tested from pods
- [ ] CloudWatch dashboard shows metrics

## 🚑 Emergency Commands

```bash
# Get bootstrap servers
cd terraform/environments/dev
terraform output bootstrap_brokers_sasl_iam

# Check cluster state
aws kafka list-clusters --region us-east-1

# View logs
aws logs tail /aws/msk/msk-cluster-dev --follow

# Emergency rollback
cd ../../../scripts
./rollback.sh dev
```

## 📧 Support

For issues:
1. Check troubleshooting guide: `docs/TROUBLESHOOTING.md`
2. Run verification scripts
3. Review CloudWatch logs
4. Contact DevOps team

---

**⭐ Remember**: 
- Always use `serviceAccountName: kafka-service-account` in your deployments
- Load Kafka config from `kafka-config` ConfigMap
- Monitor consumer lag in CloudWatch

**Happy Streaming! 🚀**

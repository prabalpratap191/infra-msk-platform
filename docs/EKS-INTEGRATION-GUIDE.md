# MSK Integration with meracommerce-dev-cluster EKS

This guide explains how to integrate the MSK cluster with your existing `meracommerce-dev-cluster` EKS cluster.

## Overview

Your microservices running in `meracommerce-dev-cluster` will connect to the MSK cluster using:
- **IAM Authentication** (SASL/IAM)
- **TLS Encryption** (port 9098)
- **IRSA** (IAM Roles for Service Accounts)
- **Security Group** rules for network access

## Prerequisites

- ✅ EKS cluster `meracommerce-dev-cluster` is running
- ✅ Namespaces already created:
  - `customer-service-ns`
  - `order-service-ns`
  - `catalog-service-ns`
  - `order-history-service-ns`
  - `notification-service-ns`
  - `payments-service-ns`
- ✅ kubectl configured for the cluster
- ✅ AWS CLI configured with appropriate permissions

## Step-by-Step Integration

### Step 1: Get EKS Cluster Security Group

First, retrieve the EKS cluster security group ID (once the cluster is available):

```bash
# Get EKS cluster details
aws eks describe-cluster --name meracommerce-dev-cluster --region us-east-1

# Extract security group ID
EKS_SG=$(aws eks describe-cluster \
  --name meracommerce-dev-cluster \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

echo "EKS Security Group: $EKS_SG"
```

### Step 2: Update Terraform Configuration

Update `terraform/environments/dev/terraform.tfvars` with the EKS security group ID:

```hcl
# EKS Integration
eks_cluster_name = "meracommerce-dev-cluster"
eks_cluster_security_group_id = "sg-xxxxxxxxx"  # Replace with actual SG ID from Step 1
```

### Step 3: Deploy MSK Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (takes ~15-20 minutes)
terraform apply

# Save outputs
terraform output -json > msk-outputs.json
```

### Step 4: Configure EKS-MSK Integration

Run the automated integration script:

```bash
cd ../../../scripts

# Make scripts executable
chmod +x configure-eks-integration.sh
chmod +x setup-eks-irsa.sh

# Run EKS-MSK integration
./configure-eks-integration.sh
```

**This script will:**
- ✅ Verify EKS and MSK are in the same VPC
- ✅ Configure security group rules (MSK ← EKS)
- ✅ Create Kafka ConfigMaps in all namespaces
- ✅ Retrieve bootstrap servers
- ✅ Test connectivity

### Step 5: Setup IAM Roles for Service Accounts (IRSA)

Configure IRSA for Kafka access:

```bash
# Run IRSA setup
./setup-eks-irsa.sh
```

**This script will:**
- ✅ Create IAM policy for MSK access
- ✅ Create IAM roles for each namespace
- ✅ Configure trust relationships with EKS OIDC
- ✅ Create/annotate Kubernetes ServiceAccounts

### Step 6: Verify Integration

#### Test 1: Check ConfigMaps

```bash
# List ConfigMaps in all namespaces
kubectl get configmap kafka-config -n customer-service-ns
kubectl get configmap kafka-config -n order-service-ns

# View ConfigMap details
kubectl describe configmap kafka-config -n customer-service-ns
```

#### Test 2: Check Service Accounts

```bash
# Verify ServiceAccount annotations
kubectl get sa kafka-service-account -n customer-service-ns -o yaml

# Should show:
# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/msk-kafka-role-customer-service-ns
```

#### Test 3: Test Kafka Connectivity from Pod

```bash
# Create test pod in customer-service-ns
kubectl run kafka-test \
  --image=confluentinc/cp-kafka:latest \
  --serviceaccount=kafka-service-account \
  -n customer-service-ns \
  --rm -it --restart=Never -- bash

# Inside the pod:
# Get bootstrap servers from ConfigMap
export BOOTSTRAP=$(echo $KAFKA_BOOTSTRAP_SERVERS)

# List topics
kafka-topics.sh --bootstrap-server $BOOTSTRAP \
  --command-config <(cat <<EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF
) --list

# Expected output:
# catalog-updation-events
# customer-orderstatus-events
# dead-letter-events
# notification-events
# order-create-events
# payment-confirm-events
```

## Spring Boot Microservice Integration

### Step 1: Add Dependencies

Add to your `pom.xml`:

```xml
<!-- Spring Kafka -->
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>

<!-- AWS MSK IAM Auth -->
<dependency>
    <groupId>software.amazon.msk</groupId>
    <artifactId>aws-msk-iam-auth</artifactId>
    <version>1.1.9</version>
</dependency>
```

### Step 2: Configure application.yaml

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    properties:
      security.protocol: ${KAFKA_SECURITY_PROTOCOL:SASL_SSL}
      sasl.mechanism: ${KAFKA_SASL_MECHANISM:AWS_MSK_IAM}
      sasl.jaas.config: ${KAFKA_SASL_JAAS_CONFIG}
      sasl.client.callback.handler.class: ${KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS}
    
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all
      retries: 3
    
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      group-id: ${spring.application.name}-consumer-group
      auto-offset-reset: earliest
      enable-auto-commit: false
```

### Step 3: Update Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customer-service
  namespace: customer-service-ns
spec:
  template:
    spec:
      serviceAccountName: kafka-service-account  # Important!
      containers:
      - name: customer-service
        image: your-registry/customer-service:latest
        env:
        # Load from ConfigMap
        - name: KAFKA_BOOTSTRAP_SERVERS
          valueFrom:
            configMapKeyRef:
              name: kafka-config
              key: KAFKA_BOOTSTRAP_SERVERS
        - name: KAFKA_SECURITY_PROTOCOL
          valueFrom:
            configMapKeyRef:
              name: kafka-config
              key: KAFKA_SECURITY_PROTOCOL
        - name: KAFKA_SASL_MECHANISM
          valueFrom:
            configMapKeyRef:
              name: kafka-config
              key: KAFKA_SASL_MECHANISM
        - name: KAFKA_SASL_JAAS_CONFIG
          valueFrom:
            configMapKeyRef:
              name: kafka-config
              key: KAFKA_SASL_JAAS_CONFIG
        - name: KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS
          valueFrom:
            configMapKeyRef:
              name: kafka-config
              key: KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS
```

## Topic to Service Mapping

| Topic | Producer Services | Consumer Services |
|-------|------------------|------------------|
| customer-orderstatus-events | customer-service | order-service, notification-service |
| order-create-events | order-service | customer-service, order-history-service |
| catalog-updation-events | catalog-service | order-service |
| payment-confirm-events | payments-service | order-service, customer-service |
| notification-events | order-service, customer-service | notification-service |
| dead-letter-events | All services | monitoring-service |

## Security Considerations

### IAM Permissions

Each service account has been granted:
- ✅ Connect to MSK cluster
- ✅ Read/Write to all topics
- ✅ Join consumer groups
- ✅ Describe cluster and topics

### Network Security

- ✅ MSK brokers in private subnets
- ✅ Security groups restrict access to EKS only
- ✅ TLS encryption in transit
- ✅ No public internet access

### Best Practices

1. **Use ServiceAccounts**: Always specify `serviceAccountName` in deployments
2. **Environment Variables**: Load Kafka config from ConfigMaps
3. **Error Handling**: Implement retry logic and dead letter queues
4. **Monitoring**: Enable metrics and alerting
5. **Testing**: Test in dev before production deployment

## Troubleshooting

### Issue: Connection Timeout

**Check:**
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids <MSK_SG_ID>

# Should show ingress from EKS security group on port 9098
```

**Fix:**
```bash
# Run integration script again
./scripts/configure-eks-integration.sh
```

### Issue: Authentication Failed

**Check:**
```bash
# Verify ServiceAccount annotation
kubectl get sa kafka-service-account -n <namespace> -o yaml

# Verify IAM role exists
aws iam get-role --role-name msk-kafka-role-<namespace>
```

**Fix:**
```bash
# Run IRSA setup again
./scripts/setup-eks-irsa.sh
```

### Issue: Topics Not Found

**Check:**
```bash
# Verify topics were created
./scripts/verify-msk-cluster.sh

# List topics
kafka-topics.sh --bootstrap-server $BOOTSTRAP --command-config client.properties --list
```

**Fix:**
```bash
# Create topics
./scripts/create-kafka-topics.sh
```

## Monitoring

### CloudWatch Metrics

Access CloudWatch Dashboard:
- Navigate to CloudWatch → Dashboards
- Select: `msk-platform-dev-msk-dashboard`

Key metrics to monitor:
- Consumer Lag
- Broker CPU/Memory
- Network Throughput
- Partition Count

### Application Logs

```bash
# View application logs
kubectl logs -f deployment/customer-service -n customer-service-ns

# Filter for Kafka errors
kubectl logs deployment/customer-service -n customer-service-ns | grep -i kafka
```

## Cost Optimization

Current setup (Dev environment):
- **Monthly Cost**: ~$229 USD
- **Instance Type**: kafka.t3.small (cost-optimized)
- **Storage**: 100GB per broker (auto-scaling enabled)
- **NAT Gateway**: Single (shared across AZs)

For production:
- Upgrade to kafka.m5.large
- Increase storage
- Multiple NAT gateways
- Estimated: ~$750/month

## Next Steps

1. ✅ Complete infrastructure deployment
2. ✅ Run integration scripts
3. ✅ Verify connectivity
4. 🔄 Deploy microservices with Kafka configuration
5. 🔄 Test end-to-end message flow
6. 🔄 Set up monitoring and alerts
7. 🔄 Document runbooks for common operations

## Support

For issues:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review CloudWatch logs
3. Run verification scripts
4. Contact DevOps team

## References

- [AWS MSK Documentation](https://docs.aws.amazon.com/msk/)
- [EKS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Spring Kafka Documentation](https://spring.io/projects/spring-kafka)
- [Deployment Guide](DEPLOYMENT.md)

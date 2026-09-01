# MSK Platform Troubleshooting Guide

This guide provides solutions to common issues encountered with the MSK platform.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Connectivity Issues](#connectivity-issues)
- [Authentication Issues](#authentication-issues)
- [Performance Issues](#performance-issues)
- [Topic Issues](#topic-issues)
- [Monitoring Issues](#monitoring-issues)

## Deployment Issues

### Issue: Terraform Init Fails

**Error Message**:
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Cause**: Backend S3 bucket not created

**Solution**:
```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket terraform-state-msk-platform-dev \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-msk-platform-dev \
  --versioning-configuration Status=Enabled
```

---

### Issue: MSK Cluster Creation Timeout

**Error Message**:
```
Error: timeout while waiting for state to become 'ACTIVE'
```

**Cause**: MSK cluster creation takes 15-20 minutes

**Solution**:
```bash
# Increase timeout in Terraform
# Or wait and check cluster status
aws kafka describe-cluster \
  --cluster-arn <CLUSTER_ARN> \
  --query 'ClusterInfo.State'
```

---

### Issue: Insufficient Permissions

**Error Message**:
```
Error: AccessDeniedException: User is not authorized to perform: kafka:CreateCluster
```

**Cause**: IAM user/role lacks required permissions

**Solution**:
```bash
# Attach required policy
aws iam attach-user-policy \
  --user-name <USERNAME> \
  --policy-arn arn:aws:iam::aws:policy/AmazonMSKFullAccess

# Or create custom policy with minimal permissions
```

---

### Issue: Subnet Availability Zone Mismatch

**Error Message**:
```
Error: Subnets must be in different Availability Zones
```

**Cause**: Subnets configured in same AZ

**Solution**:
```hcl
# Update terraform.tfvars
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
```

## Connectivity Issues

### Issue: Cannot Connect from EKS

**Symptoms**:
- Connection timeout
- "Unable to resolve broker" errors

**Diagnosis**:
```bash
# Check security group rules
MSK_SG=$(aws kafka describe-cluster \
  --cluster-arn <CLUSTER_ARN> \
  --query 'ClusterInfo.BrokerNodeGroupInfo.SecurityGroups[0]' \
  --output text)

aws ec2 describe-security-groups --group-ids $MSK_SG
```

**Solution**:
```bash
# Add ingress rule from EKS security group
EKS_SG="sg-xxxxxxxxx"  # Your EKS security group

aws ec2 authorize-security-group-ingress \
  --group-id $MSK_SG \
  --protocol tcp \
  --port 9098 \
  --source-group $EKS_SG \
  --description "Allow Kafka from EKS"
```

---

### Issue: DNS Resolution Failure

**Error Message**:
```
UnknownHostException: b-1.msk-cluster-dev.xxxxx.kafka.us-east-1.amazonaws.com
```

**Cause**: VPC DNS settings or Route53 issues

**Solution**:
```bash
# Verify VPC DNS settings
VPC_ID=$(aws kafka describe-cluster \
  --cluster-arn <CLUSTER_ARN> \
  --query 'ClusterInfo.BrokerNodeGroupInfo.ClientSubnets[0]' \
  --output text | xargs aws ec2 describe-subnets \
  --subnet-ids \
  --query 'Subnets[0].VpcId' \
  --output text)

aws ec2 describe-vpc-attribute \
  --vpc-id $VPC_ID \
  --attribute enableDnsHostnames

aws ec2 describe-vpc-attribute \
  --vpc-id $VPC_ID \
  --attribute enableDnsSupport

# Enable if disabled
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support
```

---

### Issue: Port Not Reachable

**Diagnosis**:
```bash
# Test connectivity from EKS pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Inside pod
telnet b-1.msk-cluster-dev.xxxxx.kafka.us-east-1.amazonaws.com 9098
```

**Solution**:
Check security group rules for ports:
- 9092: Plaintext
- 9094: TLS
- 9098: SASL/IAM
- 2181: Zookeeper

## Authentication Issues

### Issue: IAM Authentication Fails

**Error Message**:
```
org.apache.kafka.common.errors.SaslAuthenticationException: 
Authentication failed: Invalid credentials
```

**Cause**: Missing or incorrect IAM permissions

**Solution 1: Verify IAM Policy**
```bash
# Check pod's service account role
kubectl describe sa kafka-service-account -n <namespace>

# Verify role has MSK permissions
ROLE_ARN="arn:aws:iam::<ACCOUNT>:role/msk-dev-<namespace>-role"

aws iam list-attached-role-policies --role-name $(echo $ROLE_ARN | cut -d'/' -f2)
```

**Solution 2: Update Trust Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:<NAMESPACE>:kafka-service-account"
        }
      }
    }
  ]
}
```

---

### Issue: Missing aws-msk-iam-auth Library

**Error Message**:
```
ClassNotFoundException: software.amazon.msk.auth.iam.IAMLoginModule
```

**Solution**:
```xml
<!-- Add to pom.xml -->
<dependency>
    <groupId>software.amazon.msk</groupId>
    <artifactId>aws-msk-iam-auth</artifactId>
    <version>1.1.9</version>
</dependency>
```

```gradle
// Add to build.gradle
implementation 'software.amazon.msk:aws-msk-iam-auth:1.1.9'
```

## Performance Issues

### Issue: High Consumer Lag

**Diagnosis**:
```bash
# Check consumer lag
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --describe \
  --group <consumer-group>
```

**Solutions**:

1. **Increase consumer concurrency**:
```yaml
spring:
  kafka:
    listener:
      concurrency: 6  # Increase from 3
```

2. **Increase partition count**:
```bash
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --alter \
  --topic <topic-name> \
  --partitions 12
```

3. **Optimize batch size**:
```properties
max.poll.records=1000
fetch.min.bytes=1048576
```

---

### Issue: High Broker CPU

**Diagnosis**:
```bash
# Check CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kafka \
  --metric-name CpuUser \
  --dimensions Name="Cluster Name",Value="msk-cluster-dev" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions**:

1. **Scale up broker instance type**:
```hcl
# Update terraform.tfvars
broker_instance_type = "kafka.m5.large"
```

2. **Enable compression**:
```properties
compression.type=snappy
```

3. **Optimize producer batch settings**:
```properties
linger.ms=10
batch.size=32768
```

---

### Issue: Disk Space Running Out

**Diagnosis**:
```bash
# Check disk usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kafka \
  --metric-name KafkaDataLogsDiskUsed \
  --dimensions Name="Cluster Name",Value="msk-cluster-dev" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```

**Solutions**:

1. **Reduce retention**:
```bash
kafka-configs.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --alter \
  --entity-type topics \
  --entity-name <topic-name> \
  --add-config retention.ms=259200000  # 3 days
```

2. **Storage autoscaling will handle it** (if enabled)

3. **Manual expansion**:
```bash
# Update broker storage
aws kafka update-broker-storage \
  --cluster-arn <CLUSTER_ARN> \
  --current-broker-storage-info BrokerId=1,VolumeSize=200
```

## Topic Issues

### Issue: Topic Creation Fails

**Error Message**:
```
org.apache.kafka.common.errors.TopicExistsException
```

**Solution**:
```bash
# Check if topic exists
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --list | grep <topic-name>

# Delete if needed
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --delete \
  --topic <topic-name>
```

---

### Issue: Under-Replicated Partitions

**Diagnosis**:
```bash
# Check topic details
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --describe \
  --topic <topic-name> \
  --under-replicated-partitions
```

**Solutions**:

1. **Wait for replication to catch up**
2. **Check broker health**
3. **Verify min.insync.replicas setting**

## Monitoring Issues

### Issue: Metrics Not Showing in CloudWatch

**Cause**: Metrics may take 5-10 minutes to appear

**Solution**:
```bash
# Verify enhanced monitoring is enabled
aws kafka describe-cluster \
  --cluster-arn <CLUSTER_ARN> \
  --query 'ClusterInfo.EnhancedMonitoring'

# Check available metrics
aws cloudwatch list-metrics \
  --namespace AWS/Kafka \
  --dimensions Name="Cluster Name",Value="msk-cluster-dev"
```

---

### Issue: Logs Not Appearing

**Solution**:
```bash
# Verify log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /aws/msk/

# Check if logging is enabled
aws kafka describe-cluster \
  --cluster-arn <CLUSTER_ARN> \
  --query 'ClusterInfo.LoggingInfo'
```

## Common Error Messages

### `LEADER_NOT_AVAILABLE`

**Meaning**: Topic is being created or leader election in progress

**Solution**: Wait 30 seconds and retry

### `NOT_LEADER_FOR_PARTITION`

**Meaning**: Broker is no longer leader for partition

**Solution**: Producer will automatically retry with correct leader

### `REQUEST_TIMED_OUT`

**Meaning**: Request exceeded timeout

**Solution**: Increase timeout or check network

```properties
request.timeout.ms=60000
```

### `NETWORK_EXCEPTION`

**Meaning**: Network connectivity issue

**Solution**: Check security groups and routing

## Diagnostic Commands

### Health Check
```bash
./scripts/verify-msk-cluster.sh
./scripts/verify-connectivity.sh
```

### Cluster Info
```bash
aws kafka describe-cluster --cluster-arn <CLUSTER_ARN>
```

### Consumer Groups
```bash
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --list
```

### Topic Details
```bash
kafka-topics.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --describe
```

### Produce Test Message
```bash
echo "test message" | kafka-console-producer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --producer.config client.properties \
  --topic test-topic
```

### Consume Test Messages
```bash
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --consumer.config client.properties \
  --topic test-topic \
  --from-beginning
```

## Getting Help

1. **Check CloudWatch Logs**:
   - Navigate to CloudWatch → Log Groups → `/aws/msk/msk-cluster-dev`

2. **Review Terraform State**:
   ```bash
   terraform state list
   terraform show
   ```

3. **AWS Support**:
   - Create support case in AWS Console
   - Include cluster ARN and error messages

4. **Internal Resources**:
   - DevOps team Slack channel
   - Confluence documentation
   - JIRA ticket for tracking

## Prevention Best Practices

1. **Always test in dev first**
2. **Review Terraform plans carefully**
3. **Monitor costs and set alerts**
4. **Keep documentation updated**
5. **Regular backups of Terraform state**
6. **Use version control for all changes**
7. **Implement proper monitoring and alerting**

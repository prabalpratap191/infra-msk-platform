# Kafka Infrastructure Rollback Strategy

## Overview

This document outlines strategies and procedures for rolling back Kafka infrastructure changes safely.

---

## Table of Contents

1. [Rollback Scenarios](#rollback-scenarios)
2. [Pre-Rollback Checklist](#pre-rollback-checklist)
3. [Rollback Procedures](#rollback-procedures)
4. [Data Preservation](#data-preservation)
5. [Recovery Procedures](#recovery-procedures)

---

## Rollback Scenarios

### Scenario 1: Failed Deployment
**Trigger:** Terraform apply fails midway  
**Impact:** Partial infrastructure created  
**Action:** Automated cleanup

### Scenario 2: Kafka Cluster Instability
**Trigger:** Brokers not starting or crashing  
**Impact:** Service degradation  
**Action:** Rollback to previous configuration

### Scenario 3: Performance Degradation
**Trigger:** High latency, low throughput  
**Impact:** SLA breach  
**Action:** Scale down or rollback changes

### Scenario 4: Complete Infrastructure Removal
**Trigger:** Project termination or migration  
**Impact:** Total resource cleanup  
**Action:** Full destroy with backup

---

## Pre-Rollback Checklist

### 1. **Assess Impact**
- [ ] Identify affected services
- [ ] Check consumer lag
- [ ] Verify data replication status
- [ ] Review active connections

### 2. **Notify Stakeholders**
- [ ] Alert development teams
- [ ] Notify operations team
- [ ] Create incident ticket
- [ ] Set maintenance window

### 3. **Backup Current State**
```bash
# Terraform state
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).json

# Kafka topics metadata
kafka-topics.sh --bootstrap-server localhost:9092 --describe > topics-backup.txt

# Consumer groups
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list > groups-backup.txt
```

### 4. **Document Current Configuration**
```bash
# EC2 instances
aws ec2 describe-instances --filters "Name=tag:Component,Values=Kafka-Broker" > ec2-config.json

# Security groups
aws ec2 describe-security-groups --group-ids <KAFKA_SG_ID> > sg-config.json

# Route53 records
aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID> > dns-config.json
```

---

## Rollback Procedures

### Method 1: Automated Rollback Script

#### Quick Rollback
```bash
cd scripts
./rollback.sh dev
```

#### With Confirmation
```bash
./rollback.sh dev
# Type 'yes' to confirm
# Type 'DESTROY' to proceed
```

---

### Method 2: Manual Terraform Destroy

#### Step 1: Drain Kafka Topics (Optional)

If data preservation is critical:

```bash
# Stop producers
kubectl scale deployment customer-service --replicas=0

# Wait for consumers to catch up
kafka-consumer-groups.sh --bootstrap-server kafka-bootstrap.internal:9092 --describe --all-groups

# Export topic data (if needed)
kafka-console-consumer.sh \
  --bootstrap-server kafka-bootstrap.internal:9092 \
  --topic customer-events \
  --from-beginning > customer-events-backup.json
```

#### Step 2: Terraform Destroy

```bash
cd terraform/environments/dev

# Review what will be destroyed
terraform plan -destroy

# Execute destroy
terraform destroy

# Or with auto-approve
terraform destroy -auto-approve
```

#### Step 3: Verify Cleanup

```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=meracommerce" "Name=tag:Component,Values=Kafka"

# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=meracommerce"

# Check Route53
aws route53 list-hosted-zones

# Check EBS volumes
aws ec2 describe-volumes --filters "Name=tag:Project,Values=meracommerce"
```

---

### Method 3: Partial Rollback (Specific Resources)

#### Rollback Only Kafka Instances

```bash
terraform destroy -target=module.kafka_ec2
```

#### Rollback Only Networking

```bash
terraform destroy -target=module.networking
```

**Warning:** This may leave orphaned resources.

---

### Method 4: Rollback via Jenkins

1. **Trigger Pipeline**
   - Environment: `dev`
   - Action: `destroy`

2. **Review Destroy Plan**
   - Jenkins will show what will be destroyed

3. **Confirm Destruction**
   - Manual approval required

4. **Monitor Progress**
   - Typical destroy time: 5-10 minutes

---

## Data Preservation

### Backup Strategies

#### 1. **Kafka Topic Data Backup**

```bash
#!/bin/bash
# backup-topics.sh

TOPICS=("customer-events" "order-events" "catalog-events" "payment-events" "notification-events" "audit-events")
BACKUP_DIR="/backups/kafka/$(date +%Y%m%d)"

mkdir -p $BACKUP_DIR

for topic in "${TOPICS[@]}"; do
    echo "Backing up $topic..."
    kafka-console-consumer.sh \
        --bootstrap-server kafka-bootstrap.internal:9092 \
        --topic $topic \
        --from-beginning \
        --timeout-ms 60000 > "$BACKUP_DIR/$topic.json"
done

# Upload to S3
aws s3 sync $BACKUP_DIR s3://meracommerce-kafka-backups/$(date +%Y%m%d)/
```

#### 2. **EBS Snapshot Backup**

```bash
# Create snapshots of all Kafka EBS volumes
for volume_id in $(aws ec2 describe-volumes \
  --filters "Name=tag:Component,Values=Kafka-Broker" \
  --query 'Volumes[*].VolumeId' --output text); do
  
  echo "Creating snapshot for $volume_id"
  aws ec2 create-snapshot \
    --volume-id $volume_id \
    --description "Kafka backup $(date +%Y%m%d)" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Purpose,Value=Backup},{Key=Date,Value=$(date +%Y%m%d)}]"
done
```

#### 3. **Configuration Backup**

```bash
# Backup all Terraform configurations
tar -czf terraform-config-backup-$(date +%Y%m%d).tar.gz terraform/
aws s3 cp terraform-config-backup-$(date +%Y%m%d).tar.gz s3://meracommerce-backups/
```

---

## Recovery Procedures

### Scenario 1: Recover from Backup

#### Restore Infrastructure

```bash
# Navigate to Terraform directory
cd terraform/environments/dev

# Re-apply infrastructure
terraform apply -auto-approve

# Wait for initialization
sleep 300
```

#### Restore Topic Data

```bash
# Download backups from S3
aws s3 sync s3://meracommerce-kafka-backups/20260901/ /tmp/kafka-restore/

# Restore each topic
for file in /tmp/kafka-restore/*.json; do
    topic=$(basename $file .json)
    echo "Restoring $topic..."
    cat $file | kafka-console-producer.sh \
        --bootstrap-server kafka-bootstrap.internal:9092 \
        --topic $topic
done
```

---

### Scenario 2: Recover from EBS Snapshot

```bash
# Find latest snapshots
aws ec2 describe-snapshots \
  --filters "Name=tag:Purpose,Values=Backup" \
  --query 'reverse(sort_by(Snapshots, &StartTime))[:3]'

# Create volumes from snapshots
for snapshot_id in <SNAPSHOT_IDS>; do
    aws ec2 create-volume \
        --snapshot-id $snapshot_id \
        --availability-zone us-east-1a \
        --volume-type gp3
done

# Attach volumes to new EC2 instances
# Manual step: Update Terraform to reference new volume IDs
```

---

### Scenario 3: Disaster Recovery (Complete Loss)

#### Recovery Steps

1. **Restore Terraform State**
```bash
aws s3 cp s3://meracommerce-terraform-state/kafka/dev/terraform.tfstate ./
```

2. **Re-deploy Infrastructure**
```bash
terraform init
terraform apply -auto-approve
```

3. **Restore Data from Backups**
```bash
# Run restoration scripts
./restore-from-s3.sh
```

4. **Verify Cluster Health**
```bash
./scripts/validate-kafka.sh
```

5. **Resume Services**
```bash
kubectl scale deployment customer-service --replicas=3
kubectl scale deployment order-service --replicas=3
```

---

## Testing Rollback

### Dry Run

```bash
# Test rollback without actually destroying
terraform plan -destroy > destroy-plan.txt
cat destroy-plan.txt
```

### Staging Environment Test

```bash
# Use staging environment to test rollback
cd terraform/environments/staging
terraform destroy -auto-approve
terraform apply -auto-approve
```

---

## Rollback Timeframes

| Action | Estimated Time |
|--------|---------------|
| Terraform Destroy | 5-10 minutes |
| Data Backup | 10-30 minutes |
| Full Re-deployment | 15-20 minutes |
| Data Restoration | 20-60 minutes |
| **Total DR Time** | **50-120 minutes** |

---

## Post-Rollback Verification

```bash
# 1. Verify no resources remain
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=meracommerce Key=Component,Values=Kafka

# 2. Check billing
aws ce get-cost-and-usage \
  --time-period Start=2026-09-01,End=2026-09-02 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --filter file://cost-filter.json

# 3. Confirm DNS cleanup
dig kafka-bootstrap.internal

# 4. Verify EKS connectivity removed
kubectl get configmap kafka-config
```

---

## Emergency Contacts

| Role | Contact | Phone |
|------|---------|-------|
| DevOps Lead | devops-lead@meracommerce.com | +1-XXX-XXX-XXXX |
| Platform Engineer | platform@meracommerce.com | +1-XXX-XXX-XXXX |
| On-Call | oncall@meracommerce.com | +1-XXX-XXX-XXXX |

---

## Lessons Learned

After each rollback:

1. **Document the incident**
2. **Root cause analysis**
3. **Update runbooks**
4. **Improve automation**
5. **Team retrospective**

---

## Questions?

Contact DevOps Team: devops@meracommerce.com

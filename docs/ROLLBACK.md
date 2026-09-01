# MSK Platform Rollback Strategy

This document outlines the rollback procedures for the MSK platform infrastructure.

## Table of Contents

- [Overview](#overview)
- [Rollback Scenarios](#rollback-scenarios)
- [Automated Rollback](#automated-rollback)
- [Manual Rollback](#manual-rollback)
- [Disaster Recovery](#disaster-recovery)
- [Best Practices](#best-practices)

## Overview

The MSK platform uses Terraform for infrastructure management, which provides several rollback mechanisms:

1. **State Rollback**: Restore previous Terraform state
2. **Configuration Rollback**: Apply previous Terraform configuration
3. **Resource Removal**: Selective removal of problematic resources
4. **Full Destruction**: Complete infrastructure teardown

## Rollback Scenarios

### Scenario 1: Failed Deployment

**Symptoms**:
- Terraform apply fails midway
- Some resources created, others failed
- Infrastructure in inconsistent state

**Solution**:
```bash
# Review current state
terraform state list

# Remove failed resources
terraform state rm <resource_address>

# Re-run apply
terraform apply
```

### Scenario 2: Configuration Issues

**Symptoms**:
- Deployment succeeds but cluster not functional
- Incorrect configuration applied
- Need to revert to previous working state

**Solution**:
```bash
# Use automated rollback script
cd scripts
./rollback.sh dev

# Select option 1: Rollback to previous state
```

### Scenario 3: Topic Creation Problems

**Symptoms**:
- Topics not created correctly
- Wrong configuration applied
- Need to recreate topics

**Solution**:
```bash
# Delete topics
kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client.properties \
  --delete \
  --topic <topic-name>

# Recreate with correct configuration
./create-kafka-topics.sh
```

### Scenario 4: Security Issues

**Symptoms**:
- Unauthorized access
- Security group misconfiguration
- IAM permission issues

**Solution**:
```bash
# Immediate: Restrict security groups
aws ec2 revoke-security-group-ingress \
  --group-id $MSK_SG_ID \
  --protocol tcp \
  --port 9092-9098 \
  --cidr 0.0.0.0/0

# Apply correct configuration
terraform apply -target=module.security_group
```

## Automated Rollback

### Using Rollback Script

The repository includes an automated rollback script:

```bash
cd scripts
chmod +x rollback.sh
./rollback.sh <environment>
```

**Options**:

1. **Rollback to previous Terraform state**
   - Restores last known good state
   - Re-applies previous configuration
   - Safest option for most issues

2. **Destroy all infrastructure**
   - Removes all Terraform-managed resources
   - Use only for complete rebuild
   - Creates backup before destruction

3. **Selective resource removal**
   - Remove specific problematic resources
   - Allows targeted fixes
   - Requires knowledge of Terraform state

### State Backup

Terraform automatically creates state backups:

```bash
# List available backups
ls -lht terraform.tfstate.backup*

# Restore from backup
cp terraform.tfstate.backup terraform.tfstate
terraform refresh
```

## Manual Rollback

### Step 1: Backup Current State

```bash
cd terraform/environments/dev

# Create timestamped backup
cp terraform.tfstate terraform.tfstate.$(date +%Y%m%d-%H%M%S).backup
```

### Step 2: Identify Changes

```bash
# Show current state
terraform state list

# Show specific resource
terraform state show <resource_address>

# Compare with previous version
git diff HEAD~1 -- terraform/
```

### Step 3: Revert Configuration

**Option A: Git Revert**
```bash
# Revert to previous commit
git log --oneline
git checkout <commit-hash> -- terraform/

# Apply previous configuration
terraform init -reconfigure
terraform plan
terraform apply
```

**Option B: Selective Revert**
```bash
# Revert specific module
git checkout <commit-hash> -- terraform/modules/msk/

# Apply changes
terraform apply -target=module.msk
```

### Step 4: Verify Rollback

```bash
# Run verification scripts
./scripts/verify-msk-cluster.sh
./scripts/verify-connectivity.sh

# Check Terraform state
terraform state list
terraform output
```

## Disaster Recovery

### Complete Infrastructure Loss

If the entire MSK cluster is lost:

#### 1. Restore from Terraform State

```bash
# Pull state from S3
aws s3 cp s3://terraform-state-msk-platform-dev/msk/dev/terraform.tfstate ./

# Re-apply
terraform init
terraform apply
```

#### 2. Restore Topics

```bash
# Topics are defined in Terraform variables
# Re-run topic creation script
./scripts/create-kafka-topics.sh
```

#### 3. Restore Data (if applicable)

```bash
# If using MirrorMaker or replication
# Restore from backup cluster

# Or restore from S3 if logs were exported
aws s3 sync s3://kafka-logs-backup/ ./logs/
```

### Partial Cluster Failure

#### Single Broker Failure

```bash
# AWS MSK automatically replaces failed brokers
# Monitor via CloudWatch

# Verify broker count
aws kafka describe-cluster \
  --cluster-arn $CLUSTER_ARN \
  --query 'ClusterInfo.NumberOfBrokerNodes'
```

#### Zookeeper Failure

```bash
# AWS MSK manages Zookeeper
# Monitor cluster state

aws kafka describe-cluster \
  --cluster-arn $CLUSTER_ARN \
  --query 'ClusterInfo.State'
```

## Best Practices

### Before Deployment

1. **Always create state backup**
   ```bash
   cp terraform.tfstate terraform.tfstate.$(date +%Y%m%d-%H%M%S).backup
   ```

2. **Review plan carefully**
   ```bash
   terraform plan -out=tfplan
   # Review all changes before applying
   ```

3. **Use approval gates**
   - Never auto-approve in production
   - Require manual review of plans

### During Deployment

1. **Monitor deployment**
   - Watch CloudWatch metrics
   - Check Terraform output
   - Verify each stage

2. **Checkpoint verification**
   ```bash
   # After each major change
   ./scripts/verify-msk-cluster.sh
   ```

3. **Keep Jenkins build logs**
   - Archive all pipeline outputs
   - Save plan files

### After Deployment

1. **Verify functionality**
   ```bash
   # Test all topics
   kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
     --command-config client.properties \
     --list
   ```

2. **Update documentation**
   - Document changes
   - Update configuration examples
   - Note any issues encountered

3. **Tag successful deployments**
   ```bash
   git tag -a v1.0.0 -m "Successful MSK deployment"
   git push origin v1.0.0
   ```

### State Management

1. **Regular state backups**
   ```bash
   # Automated backup script
   #!/bin/bash
   aws s3 cp terraform.tfstate \
     s3://terraform-state-msk-platform-dev/backups/$(date +%Y%m%d).tfstate
   ```

2. **State locking**
   - Always use DynamoDB locking
   - Never bypass lock
   - Clean up stale locks carefully

3. **Version control**
   - Commit all Terraform changes
   - Use descriptive commit messages
   - Tag releases

## Emergency Contacts

- **DevOps Team Lead**: [Contact Info]
- **AWS Support**: [Support Plan Level]
- **On-Call Engineer**: [Rotation Schedule]

## Rollback Checklist

- [ ] Create state backup
- [ ] Document current issue
- [ ] Identify rollback target (commit/state)
- [ ] Review rollback plan
- [ ] Execute rollback
- [ ] Verify cluster health
- [ ] Verify topic functionality
- [ ] Test application connectivity
- [ ] Update documentation
- [ ] Notify stakeholders
- [ ] Schedule post-mortem

## Post-Rollback Steps

1. **Root cause analysis**
   - Identify what went wrong
   - Document findings
   - Create preventive measures

2. **Update procedures**
   - Improve deployment process
   - Add validation checks
   - Update documentation

3. **Plan forward**
   - Fix underlying issues
   - Test in isolated environment
   - Schedule new deployment

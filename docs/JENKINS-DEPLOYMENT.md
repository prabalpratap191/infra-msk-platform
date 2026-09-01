# Jenkins Pipeline Deployment Guide

## Overview

This guide explains how to deploy the MSK infrastructure using the Jenkins pipeline with the `jenkins-user` AWS credentials.

## Prerequisites

### 1. Jenkins Configuration

- ✅ Jenkins installed and accessible
- ✅ Required plugins installed:
  - Pipeline plugin
  - AWS Credentials plugin
  - Git plugin
  - AnsiColor plugin (optional, for colored output)

### 2. AWS Credentials Setup

**Credential ID**: `jenkins-user`

**Steps to configure**:

1. Navigate to Jenkins → Credentials → System → Global credentials
2. Click "Add Credentials"
3. Select "AWS Credentials" as Kind
4. Set ID: `jenkins-user`
5. Enter AWS Access Key ID
6. Enter AWS Secret Access Key
7. Click "Save"

### 3. AWS Resources Setup (One-time)

Before running the pipeline, create the backend resources:

```bash
# S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-msk-platform-dev \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-msk-platform-dev \
  --versioning-configuration Status=Enabled

# DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-msk-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Pipeline Configuration

### Updated Jenkinsfile Features

✅ **AWS Credentials Integration**
- All AWS-dependent stages wrapped with `withCredentials`
- Uses `jenkins-user` credential ID
- Automatically exports `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

✅ **EKS Integration**
- New stage: "Configure EKS Integration"
- Automatically runs `configure-eks-integration.sh`
- Sets up IRSA with `setup-eks-irsa.sh`
- Can be disabled via parameter

✅ **Enhanced Error Handling**
- Better error messages
- Graceful degradation for optional steps
- Detailed troubleshooting in post-failure

## Pipeline Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **ENVIRONMENT** | Choice | dev | Environment to deploy (dev/staging/prod) |
| **ACTION** | Choice | plan | Terraform action (plan/apply/destroy) |
| **AUTO_APPROVE** | Boolean | false | Skip manual approval (use with caution) |
| **CREATE_TOPICS** | Boolean | true | Create Kafka topics after deployment |
| **CONFIGURE_EKS_INTEGRATION** | Boolean | true | Configure EKS-MSK integration |

## Deployment Workflows

### Workflow 1: Initial Deployment (Recommended)

**Step 1: Plan**
```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: false  # First time, EKS may not be ready
```

**Review the plan output** in Jenkins console or artifacts.

**Step 2: Apply**
```
ENVIRONMENT: dev
ACTION: apply
AUTO_APPROVE: false
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: false  # Run separately after EKS is ready
```

Approve the deployment when prompted.

**Step 3: Configure EKS Integration** (After EKS is available)
```bash
# Manually run integration scripts
cd scripts
chmod +x configure-eks-integration.sh setup-eks-irsa.sh
./configure-eks-integration.sh
./setup-eks-irsa.sh
```

### Workflow 2: Quick Deployment (Auto-approve)

```
ENVIRONMENT: dev
ACTION: apply
AUTO_APPROVE: true  # ⚠️ Use carefully!
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: true  # Only if EKS is ready
```

### Workflow 3: Plan Only (Review Changes)

```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: false
CONFIGURE_EKS_INTEGRATION: false
```

### Workflow 4: Destroy Infrastructure

```
ENVIRONMENT: dev
ACTION: destroy
AUTO_APPROVE: false  # Manual confirmation required
CREATE_TOPICS: false
CONFIGURE_EKS_INTEGRATION: false
```

## Pipeline Stages

### 1. Checkout
- Clones the repository
- Displays git information

### 2. Setup & Verify
- **Uses AWS Credentials**: ✅
- Verifies Terraform version
- Validates AWS credentials with `aws sts get-caller-identity`
- Displays deployment configuration

### 3. Terraform Init
- **Uses AWS Credentials**: ✅
- Initializes Terraform with S3 backend
- Configures DynamoDB state locking

### 4. Terraform Validate
- Validates Terraform syntax
- Checks formatting

### 5. Terraform Plan
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'plan' or 'apply'
- Generates execution plan
- Archives plan file as artifact

### 6. Approval Gate
- **When**: ACTION = 'apply' or 'destroy' AND AUTO_APPROVE = false
- Requires manual confirmation
- Shows environment name

### 7. Terraform Apply
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'apply'
- Applies infrastructure changes
- Archives outputs as JSON

### 8. Terraform Destroy
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'destroy'
- Destroys all infrastructure

### 9. Create Kafka Topics
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'apply' AND CREATE_TOPICS = true
- Waits 120 seconds for MSK to be ready
- Creates all 6 Kafka topics
- Continues on failure (topics may exist)

### 10. Configure EKS Integration ⭐ NEW
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'apply' AND CONFIGURE_EKS_INTEGRATION = true
- Configures security groups
- Creates ConfigMaps in all namespaces
- Sets up IRSA
- Creates ServiceAccounts

### 11. Verification
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'apply'
- Runs cluster health checks
- Tests connectivity

### 12. Publish Outputs
- **Uses AWS Credentials**: ✅
- **When**: ACTION = 'apply'
- Extracts bootstrap servers
- Creates deployment summary
- Archives summary as artifact

## Accessing Build Artifacts

### Available Artifacts

1. **tfplan** - Terraform execution plan
2. **outputs.json** - Terraform outputs in JSON format
3. **deployment-summary.txt** - Human-readable deployment summary

### How to Access

1. Navigate to Jenkins build page
2. Click "Build Artifacts" in left sidebar
3. Download required files

## Monitoring Pipeline Execution

### Console Output

- Real-time logs available in Jenkins console
- Color-coded output (if AnsiColor plugin installed)
- Shows Terraform plan/apply output
- Displays verification results

### Build Status

- **Blue/Green**: Successful
- **Yellow**: Unstable (warnings)
- **Red**: Failed

## Troubleshooting

### Issue: AWS Credentials Not Found

**Error**:
```
Unable to locate credentials. You can configure credentials by running "aws login".
```

**Fix**:
1. Verify `jenkins-user` credential exists in Jenkins
2. Check credential ID is exactly: `jenkins-user`
3. Ensure AWS Credentials plugin is installed
4. Restart Jenkins if needed

### Issue: Terraform Backend Error

**Error**:
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Fix**:
```bash
# Create backend resources
aws s3api create-bucket --bucket terraform-state-msk-platform-dev --region us-east-1
aws dynamodb create-table --table-name terraform-state-lock-msk-platform ...
```

### Issue: EKS Integration Fails

**Error**:
```
No cluster found for name: meracommerce-dev-cluster
```

**Fix**:
- Set `CONFIGURE_EKS_INTEGRATION = false` for initial deployment
- Run integration scripts manually after EKS is available
- Or create EKS cluster first

### Issue: Topic Creation Fails

**Error**:
```
Topics may already exist
```

**This is normal** - The pipeline continues successfully. Topics are idempotent.

### Issue: Pipeline Timeout

**Error**:
```
Build timed out (after 60 minutes)
```

**Fix**:
- MSK deployment takes 15-20 minutes
- Increased timeout to 90 minutes in updated Jenkinsfile
- For slower deployments, increase in Jenkinsfile:
  ```groovy
  timeout(time: 120, unit: 'MINUTES')
  ```

## Best Practices

### Security

1. ✅ **Never commit AWS credentials** to Git
2. ✅ Use Jenkins credentials store
3. ✅ Rotate credentials regularly
4. ✅ Use least-privilege IAM policies
5. ✅ Enable MFA on AWS accounts

### Pipeline Execution

1. ✅ **Always run 'plan' first** before 'apply'
2. ✅ Review plan output carefully
3. ✅ Use AUTO_APPROVE sparingly (dev only)
4. ✅ Require manual approval for prod
5. ✅ Archive important outputs

### State Management

1. ✅ Enable S3 versioning on state bucket
2. ✅ Use DynamoDB for state locking
3. ✅ Never edit state files manually
4. ✅ Backup state regularly
5. ✅ Use separate state per environment

## Post-Deployment Verification

### 1. Check MSK Cluster

```bash
aws kafka list-clusters --region us-east-1
```

### 2. Verify Topics

```bash
cd scripts
./verify-msk-cluster.sh
```

### 3. Check EKS Integration

```bash
# ConfigMaps
kubectl get configmap kafka-config -n customer-service-ns

# ServiceAccounts
kubectl get sa kafka-service-account -n customer-service-ns -o yaml
```

### 4. Test Connectivity

```bash
cd scripts
./verify-connectivity.sh
```

## Rollback Procedure

If deployment fails or needs to be rolled back:

### Option 1: Terraform Destroy

```
ENVIRONMENT: dev
ACTION: destroy
AUTO_APPROVE: false
```

### Option 2: Manual Rollback Script

```bash
cd scripts
chmod +x rollback.sh
./rollback.sh dev
```

## Next Steps After Successful Deployment

1. ✅ Download deployment-summary.txt from artifacts
2. ✅ Note bootstrap servers for microservices
3. ✅ Verify EKS integration
4. ✅ Deploy microservices with Kafka config
5. ✅ Monitor CloudWatch dashboards
6. ✅ Set up alerting

## Support

For issues:
1. Check Jenkins console output
2. Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Check [EKS-INTEGRATION-GUIDE.md](EKS-INTEGRATION-GUIDE.md)
4. Contact DevOps team

---

**Pipeline Status**: ✅ Ready for deployment with jenkins-user credentials

**Recommended First Run**:
```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: false
```

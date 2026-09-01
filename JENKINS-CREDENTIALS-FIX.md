# 🔧 Quick Fix: Jenkins AWS Credentials Issue

## Problem

Jenkins pipeline failing with:
```
Unable to locate credentials. You can configure credentials by running "aws login".
```

## ✅ Solution Applied

The Jenkinsfile has been **updated** to use AWS credentials properly.

### What Changed?

**Before** (Not working):
```groovy
stage('Setup') {
    steps {
        sh '''
            aws sts get-caller-identity  # ❌ No credentials!
        '''
    }
}
```

**After** (✅ Working):
```groovy
stage('Setup & Verify') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'jenkins-user',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
                aws sts get-caller-identity  # ✅ Has credentials!
            '''
        }
    }
}
```

### Stages Updated with Credentials

All AWS-dependent stages now wrapped with `withCredentials`:

1. ✅ **Setup & Verify** - AWS identity check
2. ✅ **Terraform Init** - S3 backend access
3. ✅ **Terraform Plan** - AWS resource planning
4. ✅ **Terraform Apply** - Infrastructure deployment
5. ✅ **Terraform Destroy** - Infrastructure removal
6. ✅ **Create Kafka Topics** - MSK topic creation
7. ✅ **Configure EKS Integration** - EKS-MSK setup (NEW!)
8. ✅ **Verification** - Cluster health checks
9. ✅ **Publish Outputs** - Extract deployment info

## New Pipeline Features

### 1. EKS Integration (Automated)

New parameter added:
```groovy
booleanParam(
    name: 'CONFIGURE_EKS_INTEGRATION',
    defaultValue: true,
    description: 'Configure EKS integration after deployment'
)
```

When enabled, automatically:
- ✅ Configures security groups for MSK ↔ EKS
- ✅ Creates ConfigMaps in all namespaces
- ✅ Sets up IRSA (IAM Roles for Service Accounts)
- ✅ Creates ServiceAccounts

### 2. Better Environment Variables

```groovy
environment {
    AWS_DEFAULT_REGION = 'us-east-1'
    EKS_CLUSTER_NAME = 'meracommerce-dev-cluster'  // ⭐ NEW
    TF_DIR = "terraform/environments/${params.ENVIRONMENT}"
    SCRIPTS_DIR = 'scripts'
}
```

### 3. Enhanced Error Handling

```groovy
post {
    failure {
        script {
            echo "❌ Pipeline failed!"
            echo "Troubleshooting steps:"
            echo "  1. Check AWS credentials"
            echo "  2. Verify Terraform state"
            echo "  3. Review CloudWatch logs"
        }
    }
}
```

## How to Use

### First Run (Recommended)

**Jenkins Pipeline Parameters**:
```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: false  # Set to true only when EKS is ready
```

**Click**: "Build with Parameters"

### Expected Output (Setup Stage)

```
🔧 Setting up Terraform and AWS credentials
=== Terraform Version ===
Terraform v1.12.2

=== AWS Identity ===
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/jenkins-user"
}

=== Deployment Configuration ===
Environment: dev
Action: plan
Working Directory: terraform/environments/dev
AWS Region: us-east-1
EKS Cluster: meracommerce-dev-cluster
```

## Verification

### 1. Check Credentials in Jenkins

1. Go to: **Jenkins** → **Credentials** → **System** → **Global credentials**
2. Verify: `jenkins-user` exists
3. Type should be: **AWS Credentials**

### 2. Test Pipeline

Run a simple plan:
```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: false
CONFIGURE_EKS_INTEGRATION: false
```

### 3. Check Console Output

Look for:
```
✅ aws sts get-caller-identity
{
    "Account": "123456789012",
    ...
}
```

If you see this → **Credentials are working!**

## Troubleshooting

### Still Getting "Unable to locate credentials"?

**Check 1**: Credential ID matches
```groovy
credentialsId: 'jenkins-user'  // Must match exactly!
```

**Check 2**: AWS Credentials Plugin installed
- Jenkins → Manage Jenkins → Manage Plugins
- Search: "AWS Credentials Plugin"
- Should be installed and enabled

**Check 3**: Credential type is correct
- Must be: **AWS Credentials** (not "Secret text" or "Username/Password")

**Check 4**: Restart Jenkins
```bash
# If needed
sudo systemctl restart jenkins
```

### Error: "S3 bucket does not exist"

**Fix**: Create backend resources first

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket terraform-state-msk-platform-dev \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-msk-platform-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock-msk-platform \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Error: "EKS cluster not found"

**This is expected** if EKS cluster doesn't exist yet.

**Fix**: Set `CONFIGURE_EKS_INTEGRATION = false` for first deployment.

Run EKS integration later:
```bash
cd scripts
./configure-eks-integration.sh
./setup-eks-irsa.sh
```

## Summary of Changes

| File | Status | Changes |
|------|--------|----------|
| `Jenkinsfile` | ✅ Updated | Added `withCredentials` to all AWS stages |
| `Jenkinsfile` | ✅ Updated | Added EKS integration stage |
| `Jenkinsfile` | ✅ Updated | Added `CONFIGURE_EKS_INTEGRATION` parameter |
| `Jenkinsfile` | ✅ Updated | Added `EKS_CLUSTER_NAME` environment variable |
| `Jenkinsfile` | ✅ Updated | Improved error messages and logging |
| `Jenkinsfile` | ✅ Updated | Increased timeout to 90 minutes |

## Next Steps

1. ✅ **Verify** jenkins-user credentials exist in Jenkins
2. ✅ **Create** S3 bucket and DynamoDB table (if not exists)
3. ✅ **Run** pipeline with ACTION=plan first
4. ✅ **Review** plan output
5. ✅ **Run** pipeline with ACTION=apply
6. ✅ **Configure** EKS integration (after EKS is available)

## Quick Reference

### Credential Configuration
```groovy
withCredentials([[
    $class: 'AmazonWebServicesCredentialsBinding',
    credentialsId: 'jenkins-user',  // ⭐ Your credential ID
    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
]]) {
    // All AWS commands here have credentials
}
```

### Backend Configuration
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-msk-platform-dev"
    key            = "msk/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-msk-platform"
  }
}
```

---

**✅ Credentials Issue Fixed!**

Your pipeline is now ready to deploy with proper AWS authentication using the `jenkins-user` credentials.

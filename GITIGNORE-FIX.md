# 🔧 GitIgnore Fix - terraform.tfvars Missing in Jenkins

## Issue

Jenkins pipeline failed with:

```
Error: Failed to read variables file
Given variables file terraform.tfvars does not exist.
```

**Location**: `terraform/environments/dev/terraform.tfvars`

## Root Cause

The `.gitignore` file was configured to ignore **ALL** `.tfvars` files:

```gitignore
*.tfvars                        # ❌ Ignores ALL .tfvars files
!terraform.tfvars.example       # ✅ Except example files
```

This prevented the essential `terraform/environments/dev/terraform.tfvars` file from being:
1. ❌ Committed to Git
2. ❌ Pushed to the repository
3. ❌ Checked out by Jenkins
4. ❌ Available during pipeline execution

## The Fix

### Updated `.gitignore`

**Before** ❌:
```gitignore
# Terraform
*.tfstate
*.tfstate.*
*.tfvars                        # Ignores ALL
!terraform.tfvars.example
.terraform/
```

**After** ✅:
```gitignore
# Terraform
*.tfstate
*.tfstate.*
*.tfvars                                          # Ignores .tfvars in general
!terraform.tfvars.example                         # Allow example files
!terraform/environments/*/terraform.tfvars        # ⭐ Allow environment configs
.terraform/
```

### What Changed

Added exception for environment-specific configuration files:
```gitignore
!terraform/environments/*/terraform.tfvars
```

This allows:
- ✅ `terraform/environments/dev/terraform.tfvars`
- ✅ `terraform/environments/staging/terraform.tfvars`
- ✅ `terraform/environments/prod/terraform.tfvars`

While still ignoring:
- ❌ Root-level `*.tfvars` files (may contain secrets)
- ❌ Ad-hoc variable files (e.g., `secrets.tfvars`)

## Why This Approach?

### ✅ **Pros**

1. **Environment configs in Git**: Infrastructure as Code principle
2. **Version control**: Track changes to infrastructure configuration
3. **Jenkins compatibility**: Files available during checkout
4. **Team collaboration**: Everyone uses same base configuration
5. **Audit trail**: See who changed what and when

### ⚠️ **Considerations**

**Security**: The `terraform.tfvars` files should **NOT** contain sensitive data:

❌ **DON'T** put in `terraform.tfvars`:
- Database passwords
- API keys
- Access tokens
- SSH private keys
- Service account credentials

✅ **DO** put in `terraform.tfvars`:
- Environment names
- Region settings
- Instance types
- VPC CIDRs
- Cluster names
- Non-sensitive configuration

### 🔐 **For Sensitive Data**

Use one of these approaches:

**Option 1: AWS Secrets Manager** (Recommended)
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "dev/msk/db-password"
}
```

**Option 2: Environment Variables in Jenkins**
```groovy
withCredentials([string(credentialsId: 'db-password', variable: 'DB_PASSWORD')]) {
  sh 'terraform apply -var="db_password=$DB_PASSWORD"'
}
```

**Option 3: Separate `.tfvars` file (NOT in Git)**
```bash
# Create secrets.tfvars (ignored by Git)
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

## What to Commit

### Step 1: Stage the Changes

```bash
cd c:\Users\prasingh80\Music\Legacy\MS Legacy\infra-kafka-platform

# Check Git status
git status

# Should show:
# modified:   .gitignore
# modified:   terraform/modules/networking/main.tf
# untracked:  terraform/environments/dev/terraform.tfvars  # ⭐ Now tracked!
```

### Step 2: Add Files

```bash
# Add the .gitignore fix
git add .gitignore

# Add the Terraform syntax fix
git add terraform/modules/networking/main.tf

# Add environment configuration
git add terraform/environments/dev/terraform.tfvars

# Add any other modified files
git add terraform/environments/dev/main.tf
git add terraform/environments/dev/variables.tf
```

### Step 3: Commit

```bash
git commit -m "fix: update .gitignore to allow environment tfvars files

- Allow terraform.tfvars in terraform/environments/* directories
- Fix VPC endpoints security group syntax error
- Environment configs needed for Jenkins pipeline
- Sensitive data still excluded via *.tfvars pattern"
```

### Step 4: Push

```bash
git push origin main
```

## Verification

### Before Pushing (Local)

```bash
# Check what will be committed
git status

# Verify .tfvars files are staged
git ls-files | grep tfvars

# Should show:
# terraform/environments/dev/terraform.tfvars
```

### After Pushing (Remote)

```bash
# Verify file exists in remote repository
git ls-tree -r HEAD --name-only | grep tfvars

# Or check on GitHub/GitLab
```

### In Jenkins (After Checkout)

The Jenkins pipeline should now show:

```
✅ Checkout stage completes
✅ terraform.tfvars file present
✅ Terraform plan executes successfully
```

## Alternative: Using tfvars.example

If you prefer to keep ALL `.tfvars` files out of Git:

### Step 1: Create Example File

```bash
cp terraform/environments/dev/terraform.tfvars \
   terraform/environments/dev/terraform.tfvars.example
```

### Step 2: Update Jenkinsfile

```groovy
stage('Prepare Variables') {
    steps {
        dir("${TF_DIR}") {
            sh '''
                # Copy example to actual tfvars
                cp terraform.tfvars.example terraform.tfvars
                
                # Or generate from template
                envsubst < terraform.tfvars.example > terraform.tfvars
            '''
        }
    }
}
```

### Step 3: Update .gitignore

```gitignore
*.tfvars
!*.tfvars.example  # Only commit example files
```

**Pros**: Maximum security, no configs in Git  
**Cons**: More complex pipeline, manual variable management

## Current Configuration Review

### Files That Should Be in Git

✅ **Committed** (Infrastructure as Code):
- `terraform/environments/dev/main.tf`
- `terraform/environments/dev/variables.tf`
- `terraform/environments/dev/terraform.tfvars` ⭐ (after fix)
- All module files
- Scripts
- Documentation

❌ **Ignored** (Security):
- `*.tfstate` - Terraform state (in S3 backend)
- `*.tfstate.backup` - State backups
- `.terraform/` - Provider plugins
- `secrets.tfvars` - Sensitive variables
- `*.pem`, `*.key` - Credentials

### Current terraform.tfvars Content

Verify your `terraform/environments/dev/terraform.tfvars` contains only **non-sensitive** data:

```hcl
# General Settings ✅
aws_region   = "us-east-1"
environment  = "dev"
project_name = "msk-platform"

# Networking ✅
vpc_cidr = "10.0.0.0/16"

# MSK Configuration ✅
msk_cluster_name = "msk-cluster-dev"
kafka_version    = "3.6.0"

# EKS Integration ✅
eks_cluster_name = "meracommerce-dev-cluster"

# ❌ NO SECRETS!
# database_password = "secret123"  # DON'T DO THIS!
```

## Next Steps

1. ✅ `.gitignore` updated
2. ⏳ **Commit and push changes**
3. ⏳ **Re-run Jenkins pipeline**
4. ⏳ **Verify terraform.tfvars is found**

## Commands Summary

```bash
# Navigate to repo
cd c:\Users\prasingh80\Music\Legacy\MS Legacy\infra-kafka-platform

# Stage all fixes
git add .gitignore
git add terraform/modules/networking/main.tf
git add terraform/environments/dev/terraform.tfvars

# Commit
git commit -m "fix: allow environment tfvars in Git and fix security group syntax"

# Push
git push origin main

# Trigger Jenkins pipeline
# Jenkins → Your Pipeline → Build with Parameters
# ENVIRONMENT: dev
# ACTION: plan
```

## Troubleshooting

### Issue: File Still Not in Git

```bash
# Force add the file
git add -f terraform/environments/dev/terraform.tfvars

# Verify it's staged
git status
```

### Issue: Jenkins Still Can't Find File

```bash
# Check file is in remote repo
git ls-tree -r origin/main --name-only | grep terraform.tfvars

# Verify Jenkins is pulling latest
# In Jenkins: Configure → Source Code Management → Check branch
```

### Issue: Git Shows File as Ignored

```bash
# Test .gitignore patterns
git check-ignore -v terraform/environments/dev/terraform.tfvars

# Should show:
# .gitignore:6:!terraform/environments/*/terraform.tfvars
# (negative pattern = file is NOT ignored)
```

---

**Status**: ✅ **FIXED**  
**Action Required**: Commit `.gitignore` and push to trigger Jenkins pipeline

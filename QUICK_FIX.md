# Quick Fix - Jenkins Pipeline Failure

🔴 **Error**: `Error: No value for required variable` at Terraform Plan stage

## ⚡ Instant Fix (3 Steps)

```bash
# Step 1: Navigate to environment directory
cd terraform/environments/dev

# Step 2: Verify terraform.tfvars exists
ls terraform.tfvars
# If missing, copy from example:
cp terraform.tfvars.example terraform.tfvars

# Step 3: Test locally (optional)
terraform init
terraform plan
```

## ⚠️ Critical: Update These Values Before Deployment

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
# SECURITY: Restrict admin access
admin_cidr_blocks = ["YOUR_OFFICE_IP/32"]  # Change from 0.0.0.0/0

# AWS: Ensure this key exists in your AWS account
ssh_key_name = "kafka-key"  # Create in AWS Console if missing

# REGION: Match your target region
aws_region = "us-east-1"  # Verify this is correct
```

## 🚀 Re-run Jenkins Pipeline

1. Go to Jenkins job
2. Click "Build with Parameters"
3. Select:
   - **ENVIRONMENT**: `dev`
   - **ACTION**: `plan` (safe test) or `apply` (deploy)
4. Click **Build**

## ✅ Expected Result

Pipeline should now pass the "Terraform Plan" stage without variable errors.

## 📖 Full Documentation

- **Complete Fix Guide**: [docs/JENKINS_PIPELINE_FIX.md](docs/JENKINS_PIPELINE_FIX.md)
- **Summary**: [PIPELINE_FIX_SUMMARY.md](PIPELINE_FIX_SUMMARY.md)
- **Troubleshooting**: [README.md#troubleshooting](README.md#troubleshooting)

## 🆘 Need Help?

Contact DevOps Team or create a GitHub issue.

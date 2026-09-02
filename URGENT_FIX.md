# 🚨 URGENT: Fix Pipeline Failure

## Current Error

```
Error: No value for required variable
The root module input variable "vpc_id" is not set
```

---

## ⚡ Quick Fix (Choose One)

### Option 1: Automated Setup (Recommended)

Run the helper script to automatically get your AWS values:

```bash
# Make script executable
chmod +x get-aws-values.sh

# Run the script
./get-aws-values.sh

# Follow prompts to select VPC and Subnet
# Script will update terraform/terraform.tfvars automatically
```

### Option 2: Manual Setup

#### Step 1: Get Your AWS Values

```bash
# Get your VPC ID
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# Get your Subnet ID (replace VPC_ID)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=VPC_ID" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table

# Get your public IP
curl https://checkip.amazonaws.com
```

#### Step 2: Update terraform/terraform.tfvars

Edit the file and replace placeholder values:

```bash
cd terraform
vim terraform.tfvars
```

**Replace these values**:

```hcl
# Change from:
vpc_id = "REPLACE_WITH_YOUR_VPC_ID"
subnet_id = "REPLACE_WITH_YOUR_SUBNET_ID"
private_vpc_cidr = "REPLACE_WITH_YOUR_VPC_CIDR"
admin_ip_address = "REPLACE_WITH_YOUR_PUBLIC_IP"

# To actual values like:
vpc_id = "vpc-0abc123def456789"
subnet_id = "subnet-0xyz789abc123456"
private_vpc_cidr = "10.0.0.0/16"
admin_ip_address = "203.0.113.1"
```

**DO NOT add**:
```hcl
key_name = "..."  # ❌ NOT NEEDED - auto-generated!
```

#### Step 3: Verify Configuration

```bash
cd terraform
cat terraform.tfvars

# Ensure no "REPLACE_WITH" placeholders remain
grep -i "REPLACE" terraform.tfvars
# Should return nothing
```

---

## ✅ Run Pipeline Again

1. **Commit changes** (if needed):
   ```bash
   git add terraform/terraform.tfvars
   git commit -m "Configure Terraform variables"
   git push
   ```

2. **Run Jenkins pipeline**:
   - Go to Jenkins
   - Click **Build Now**
   - Pipeline should succeed now!

---

## 🔍 What Was Fixed?

### Changes Made

1. **Removed `key_name` variable** from `terraform/variables.tf`
   - No longer needed (SSH keys auto-generated)

2. **Created `terraform/terraform.tfvars`** with placeholders
   - You need to fill in your AWS values

3. **Created helper script** `get-aws-values.sh`
   - Automates finding and setting AWS values

### Why It Failed

The pipeline failed because:

❌ `terraform.tfvars` file was missing  
❌ Required variables (vpc_id, subnet_id, etc.) had no values  
❌ `key_name` variable was still defined but shouldn't be

### What's Different Now

✅ `terraform.tfvars` file created with placeholders  
✅ `key_name` variable removed (auto-generated)  
✅ Helper script available to get AWS values  
✅ SSH keys generated automatically by Terraform

---

## 📝 Required Variables

You **must** provide these values in `terraform/terraform.tfvars`:

| Variable | Description | How to Get |
|----------|-------------|------------|
| `vpc_id` | Your VPC ID | `aws ec2 describe-vpcs` |
| `subnet_id` | Your Subnet ID | `aws ec2 describe-subnets` |
| `private_vpc_cidr` | VPC CIDR block | Same as VPC's CIDR |
| `admin_ip_address` | Your public IP | `curl https://checkip.amazonaws.com` |

**Optional** (can leave as defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `instance_type` | `t3.medium` | EC2 instance type |
| `volume_size` | `40` | Root volume size (GB) |
| `eks_worker_security_group_id` | `""` | EKS security group (if using EKS) |
| `kafka_cluster_name` | `kafka-cluster-dev` | Kafka cluster name |
| `kafka_broker_id` | `1` | Kafka broker ID |

---

## 🧰 Verification

Before running the pipeline, verify:

```bash
# Check terraform.tfvars exists and is populated
cat terraform/terraform.tfvars | grep -v "#" | grep -v "^$"

# Verify no placeholders remain
grep "REPLACE" terraform/terraform.tfvars
# Should return nothing

# Validate Terraform configuration
cd terraform
terraform init
terraform validate
# Should say "Success! The configuration is valid."
```

---

## 🚀 Next Steps After Fix

1. ✅ Update `terraform/terraform.tfvars` with your values
2. ✅ Run Jenkins pipeline
3. ✅ SSH keys will be auto-generated
4. ✅ Docker will be installed via SSH (visible logs)
5. ✅ Kafka will be deployed via SSH (visible logs)
6. ✅ Deployment complete!

---

## 🔗 Related Documentation

- **[START_HERE.md](START_HERE.md)** - Main navigation
- **[DYNAMIC_SSH_QUICKSTART.md](DYNAMIC_SSH_QUICKSTART.md)** - Quick start guide
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Full migration guide

---

**Fix this and you'll be ready to deploy!** 🚀

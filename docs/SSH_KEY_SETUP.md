# SSH Key Setup for Kafka EC2 Instances

Before deploying the Kafka infrastructure, you need to create an SSH key pair in AWS.

---

## Quick Setup

### Option 1: Create via AWS Console

1. **Navigate to EC2 Console**
   - Go to AWS Console → EC2 → Key Pairs
   - Region: **us-east-1**

2. **Create Key Pair**
   - Click "Create key pair"
   - Name: `kafka-key` (or your preferred name)
   - Type: RSA
   - Format: `.pem` (for Linux/Mac) or `.ppk` (for Windows/PuTTY)
   - Click "Create key pair"

3. **Save the Private Key**
   - The `.pem` file will download automatically
   - Save it to a secure location
   - **IMPORTANT**: You cannot download it again!

4. **Set Permissions** (Linux/Mac)
   ```bash
   chmod 400 ~/Downloads/kafka-key.pem
   ```

---

### Option 2: Create via AWS CLI

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name kafka-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > kafka-key.pem

# Set permissions
chmod 400 kafka-key.pem

# Verify
aws ec2 describe-key-pairs \
  --key-names kafka-key \
  --region us-east-1
```

---

## Update Configuration

If you used a different key name, update `terraform.tfvars`:

```hcl
# terraform/environments/dev/terraform.tfvars
ssh_key_name = "your-key-name-here"
```

---

## Connect to Kafka Brokers

Once deployed, connect using:

```bash
# Get broker IP from Terraform output
terraform output kafka_private_ips

# SSH to broker (replace with actual IP)
ssh -i kafka-key.pem ec2-user@10.0.101.10

# Or use bastion host if configured
ssh -i kafka-key.pem -J bastion-user@bastion-ip ec2-user@10.0.101.10
```

---

## Security Best Practices

### 1. **Secure Storage**
- Store `.pem` files in a secure location
- Never commit private keys to Git
- Use AWS Secrets Manager or Parameter Store for shared access

### 2. **Access Control**
```bash
# Your private key should have restrictive permissions
ls -la kafka-key.pem
# Should show: -r-------- (400)
```

### 3. **Key Rotation**
```bash
# Create new key
aws ec2 create-key-pair --key-name kafka-key-new --region us-east-1

# Update instances (requires recreation)
# Update terraform.tfvars:
# ssh_key_name = "kafka-key-new"

# Apply changes
terraform apply

# Delete old key (after verification)
aws ec2 delete-key-pair --key-name kafka-key --region us-east-1
```

### 4. **SSH Config** (Optional)

Create `~/.ssh/config` for easier access:

```bash
# Kafka Broker 1
Host kafka-1
  HostName 10.0.101.10
  User ec2-user
  IdentityFile ~/path/to/kafka-key.pem
  StrictHostKeyChecking no

# Kafka Broker 2
Host kafka-2
  HostName 10.0.102.10
  User ec2-user
  IdentityFile ~/path/to/kafka-key.pem
  StrictHostKeyChecking no

# Kafka Broker 3
Host kafka-3
  HostName 10.0.103.10
  User ec2-user
  IdentityFile ~/path/to/kafka-key.pem
  StrictHostKeyChecking no
```

Then connect using:
```bash
ssh kafka-1
ssh kafka-2
ssh kafka-3
```

---

## Troubleshooting

### Permission Denied

```bash
# Issue: Permission denied (publickey)
# Solution: Check permissions
chmod 400 kafka-key.pem

# Verify key fingerprint matches AWS
ssh-keygen -lf kafka-key.pem
aws ec2 describe-key-pairs --key-names kafka-key --region us-east-1
```

### Wrong User

```bash
# Amazon Linux 2023 default user is ec2-user
ssh -i kafka-key.pem ec2-user@<broker-ip>

# NOT: ubuntu, admin, or root
```

### Connection Timeout

```bash
# Check security group allows SSH from your IP
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --region us-east-1

# Update admin_cidr_blocks in terraform.tfvars
admin_cidr_blocks = ["YOUR_IP/32"]
```

### Key Not Found

```bash
# List available keys
aws ec2 describe-key-pairs --region us-east-1

# If key doesn't exist, create it:
aws ec2 create-key-pair --key-name kafka-key --region us-east-1
```

---

## Alternative: Session Manager

For enhanced security, use AWS Systems Manager Session Manager (no SSH key required):

```bash
# Connect via Session Manager
aws ssm start-session \
  --target <instance-id> \
  --region us-east-1
```

**Requirements:**
- EC2 instance has SSM agent (pre-installed on Amazon Linux 2023)
- EC2 instance has IAM role with `AmazonSSMManagedInstanceCore` policy
- Your IAM user has SSM permissions

---

## Summary

✅ **Before deployment:**
1. Create SSH key pair: `kafka-key`
2. Save `.pem` file securely
3. Set permissions: `chmod 400`
4. Update `terraform.tfvars` if needed

✅ **After deployment:**
1. Get IPs: `terraform output kafka_private_ips`
2. Connect: `ssh -i kafka-key.pem ec2-user@<ip>`
3. Verify: Check logs in `/var/log/kafka-setup.log`

---

**Need Help?**
- AWS Key Pairs Documentation: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
- Session Manager Setup: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html

# Quick Fix Guide - Jenkins Pipeline Failure

## 🚨 Error Summary

```
ERROR: kafka-ec2-key
Finished: FAILURE
```

**Pipeline**: `Infra_kafka_pipeline_mainbranch`  
**Status**: Failed at credential loading stage  
**Root Cause**: Missing Jenkins credential `kafka-ec2-key`

---

## ⚡ Quick Fix (5 Minutes)

### Step 1: Create EC2 Key Pair in AWS

```bash
# Run this command
aws ec2 create-key-pair \
  --key-name kafka-ec2-key \
  --query 'KeyMaterial' \
  --output text > kafka-ec2-key.pem

# Set permissions
chmod 400 kafka-ec2-key.pem
```

### Step 2: Add SSH Credential to Jenkins

1. **Go to**: Jenkins → Manage Jenkins → Manage Credentials
2. **Click**: (global) → Add Credentials
3. **Fill**:
   - **Kind**: SSH Username with private key
   - **ID**: `kafka-ec2-key` (must be exact)
   - **Username**: `ec2-user`
   - **Private Key**: Enter directly → Paste content of `kafka-ec2-key.pem`
4. **Click**: OK

### Step 3: Add AWS Credentials to Jenkins

1. **Go to**: Manage Credentials → Add Credentials
2. **Fill**:
   - **Kind**: AWS Credentials
   - **ID**: `jenkins-user` (must be exact)
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
3. **Click**: OK

### Step 4: Re-run Pipeline

1. Navigate to your pipeline
2. Click **Build Now**
3. ✅ Pipeline should succeed!

---

## 📋 Detailed Instructions

For complete step-by-step guide, see:
- **[JENKINS_CREDENTIALS_SETUP.md](JENKINS_CREDENTIALS_SETUP.md)** - Full setup guide
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete deployment guide

---

## 🔍 Verify Setup

Run the verification script:

```bash
# Make executable
chmod +x verify-jenkins-setup.sh

# Run verification
./verify-jenkins-setup.sh
```

**Expected Output**:
```
✓ AWS CLI installed
✓ AWS Credentials configured
✓ EC2 Key Pair 'kafka-ec2-key' exists
✓ Terraform installed
✓ All checks passed!
```

---

## ❓ Troubleshooting

### Problem: "Key pair already exists"

**Solution**: Download existing key or use different name

```bash
# List existing keys
aws ec2 describe-key-pairs

# Delete old key (if needed)
aws ec2 delete-key-pair --key-name kafka-ec2-key

# Create new key
aws ec2 create-key-pair --key-name kafka-ec2-key \
  --query 'KeyMaterial' --output text > kafka-ec2-key.pem
```

### Problem: "Credentials not found" in Jenkins

**Solution**: Verify exact ID and restart Jenkins

```bash
# Check credential ID is exactly: kafka-ec2-key
# Restart Jenkins
sudo systemctl restart jenkins
```

### Problem: "Permission denied (publickey)"

**Solution**: Verify key format and username

```bash
# Verify key starts with:
head -1 kafka-ec2-key.pem
# Should show: -----BEGIN RSA PRIVATE KEY-----

# Username must be: ec2-user
```

---

## 📊 Pipeline Stages Overview

After fixing credentials, pipeline will execute:

```mermaid
graph TD
    A[Checkout] --> B[Terraform Init]
    B --> C[Terraform Validate]
    C --> D[Terraform Plan]
    D --> E[Terraform Apply]
    E --> F[Get EC2 Details]
    F --> G[Wait for EC2 Init]
    G --> H[Verify Docker]
    H --> I[Deploy Kafka]
    I --> J[Create Topics]
    J --> K[Verify Kafka]
    K --> L[Print Details]
    L --> M[Success]
```

**Total Duration**: ~10-15 minutes

---

## ✅ Success Indicators

When pipeline succeeds, you'll see:

```
==================================
   KAFKA DEPLOYMENT SUCCESSFUL
==================================

Kafka Status: ✓ RUNNING
EC2 Status: ✓ RUNNING

Topics Created:
  • customer-events
  • order-events
  • catalog-events
  • payment-events
  • inventory-events
  • notification-events
  • dead-letter-events

✓ Ready for Spring Boot Integration
==================================
```

---

## 📝 Required Credentials Summary

| Credential ID | Type | Purpose | Required Fields |
|--------------|------|---------|----------------|
| `kafka-ec2-key` | SSH Username with private key | EC2 SSH access | Username: `ec2-user`<br>Private Key: `.pem` content |
| `jenkins-user` | AWS Credentials | AWS API access | Access Key ID<br>Secret Access Key |

⚠️ **Critical**: Credential IDs must match **exactly** as shown above (case-sensitive).

---

## 🔐 Security Checklist

- [ ] Never commit `.pem` files to Git
- [ ] Never commit `terraform.tfvars` to Git
- [ ] Set `.pem` file permissions to 400
- [ ] Store AWS credentials securely
- [ ] Use IAM roles instead of keys (when possible)
- [ ] Rotate credentials regularly (every 90 days)

---

## 🎯 Next Steps After Pipeline Success

1. **Connect to EC2**:
   ```bash
   ssh -i kafka-ec2-key.pem ec2-user@<EC2_PUBLIC_IP>
   ```

2. **Verify Kafka**:
   ```bash
   docker ps
   docker logs kafka-server
   ```

3. **Test Topics**:
   ```bash
   docker exec kafka-server kafka-topics.sh \
     --list --bootstrap-server localhost:9092
   ```

4. **Integrate with Spring Boot**:
   - Update `application.yml` with EC2 IP
   - Test producer/consumer

---

## 📚 Additional Resources

- **Jenkins Setup**: [JENKINS_CREDENTIALS_SETUP.md](JENKINS_CREDENTIALS_SETUP.md)
- **Full Deployment**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Kafka Config**: [KAFKA_CONFIG.md](KAFKA_CONFIG.md)
- **Project Overview**: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
- **Main README**: [README.md](README.md)

---

## 💬 Support

If issues persist:

1. Run verification script: `./verify-jenkins-setup.sh`
2. Check Jenkins logs: `/var/log/jenkins/jenkins.log`
3. Check AWS permissions: `aws sts get-caller-identity`
4. Review console output in Jenkins pipeline

---

**Last Updated**: 2025-01-02  
**Status**: Ready to Use  
**Estimated Fix Time**: 5-10 minutes

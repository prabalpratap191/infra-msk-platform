# Jenkins Credentials Setup Guide

## Overview

This guide will help you configure the required Jenkins credentials to fix the pipeline failure.

**Error**: `ERROR: kafka-ec2-key`

**Cause**: Missing Jenkins credentials for SSH access to EC2 instances.

---

## Prerequisites

✅ Jenkins installed and running  
✅ Admin access to Jenkins  
✅ AWS CLI configured  
✅ Access to AWS Console

---

## Step 1: Create EC2 Key Pair in AWS

### Option A: Using AWS CLI

```bash
# Create the key pair and save to file
aws ec2 create-key-pair \
  --key-name kafka-ec2-key \
  --query 'KeyMaterial' \
  --output text > kafka-ec2-key.pem

# Set proper permissions
chmod 400 kafka-ec2-key.pem

# Verify the key was created
aws ec2 describe-key-pairs --key-names kafka-ec2-key
```

**Expected Output**:
```json
{
    "KeyPairs": [
        {
            "KeyPairId": "key-0123456789abcdef",
            "KeyFingerprint": "...",
            "KeyName": "kafka-ec2-key",
            "KeyType": "rsa",
            "Tags": []
        }
    ]
}
```

### Option B: Using AWS Console

1. Navigate to **EC2 Console** → **Key Pairs**
2. Click **Create key pair**
3. **Name**: `kafka-ec2-key`
4. **Key pair type**: RSA
5. **Private key file format**: `.pem`
6. Click **Create key pair**
7. Save the downloaded `kafka-ec2-key.pem` file securely
8. Set permissions: `chmod 400 kafka-ec2-key.pem`

⚠️ **Important**: Keep this `.pem` file safe - AWS will not provide it again!

---

## Step 2: Add SSH Credential to Jenkins

### Method 1: Using Jenkins Web UI (Recommended)

#### A. Navigate to Credentials

1. Open Jenkins in your browser
2. Click **Manage Jenkins** (left sidebar)
3. Click **Manage Credentials**
4. Click **(global)** domain under **Stores scoped to Jenkins**
5. Click **Add Credentials** (left sidebar)

#### B. Configure SSH Credential

Fill in the following details:

| Field | Value |
|-------|-------|
| **Kind** | SSH Username with private key |
| **Scope** | Global (Jenkins, nodes, items, all child items, etc) |
| **ID** | `kafka-ec2-key` ⚠️ **Must match exactly** |
| **Description** | SSH key for Kafka EC2 instances |
| **Username** | `ec2-user` |
| **Private Key** | **Enter directly** (select this option) |
| **Key** | Paste entire contents of `kafka-ec2-key.pem` |
| **Passphrase** | Leave empty (unless you set one) |

#### C. Add Private Key Content

1. Open your `.pem` file:
   ```bash
   cat kafka-ec2-key.pem
   ```

2. Copy **entire content** including:
   ```
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   ...
   -----END RSA PRIVATE KEY-----
   ```

3. Paste into the **Key** field in Jenkins

4. Click **OK** to save

### Method 2: Using Jenkins CLI

```bash
# Create credential XML file
cat > ssh-credential.xml << 'EOF'
<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.18">
  <scope>GLOBAL</scope>
  <id>kafka-ec2-key</id>
  <description>SSH key for Kafka EC2 instances</description>
  <username>ec2-user</username>
  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey$DirectEntryPrivateKeySource">
    <privateKey>$(cat kafka-ec2-key.pem)</privateKey>
  </privateKeySource>
</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
EOF

# Import to Jenkins
java -jar jenkins-cli.jar -s http://localhost:8080/ create-credentials-by-xml system::system::jenkins "(global)" < ssh-credential.xml
```

---

## Step 3: Add AWS Credentials to Jenkins

### Option A: Using AWS Access Keys

#### 1. Create AWS Access Keys

```bash
# Create IAM user (if needed)
aws iam create-user --user-name jenkins-user

# Attach required policies
aws iam attach-user-policy \
  --user-name jenkins-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-user-policy \
  --user-name jenkins-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

# Create access keys
aws iam create-access-key --user-name jenkins-user
```

**Save the output**:
```json
{
    "AccessKey": {
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    }
}
```

#### 2. Add to Jenkins

1. Navigate to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** → **Add Credentials**
3. Configure:

| Field | Value |
|-------|-------|
| **Kind** | AWS Credentials |
| **Scope** | Global |
| **ID** | `jenkins-user` ⚠️ **Must match exactly** |
| **Description** | AWS credentials for Jenkins pipeline |
| **Access Key ID** | Your AWS Access Key ID |
| **Secret Access Key** | Your AWS Secret Access Key |

4. Click **OK**

### Option B: Using IAM Role (Recommended for Production)

If Jenkins runs on EC2:

```bash
# Create IAM role
aws iam create-role \
  --role-name JenkinsEC2Role \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name JenkinsEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# Attach role to Jenkins EC2 instance
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=JenkinsEC2Role
```

Then in Jenkins:
- Use the **AWS Steps** plugin
- Credentials will be auto-detected from the instance profile

---

## Step 4: Update Terraform Variables

⚠️ **Critical**: Update your `terraform/terraform.tfvars` to use the correct key name:

```hcl
# Ensure this matches the key pair name in AWS
key_name = "kafka-ec2-key"
```

If the file doesn't exist:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit the file
vim terraform.tfvars
```

Update these values:

```hcl
# Network Configuration
vpc_id            = "vpc-xxxxx"        # Your VPC ID
subnet_id         = "subnet-xxxxx"     # Your Subnet ID
private_vpc_cidr  = "10.0.0.0/16"     # Your VPC CIDR

# Security Configuration
admin_ip_address  = "YOUR.PUBLIC.IP"   # Get via: curl https://checkip.amazonaws.com
key_name          = "kafka-ec2-key"    # Must match AWS key pair name

# Optional: EKS Security Group
eks_worker_security_group_id = ""      # Leave empty if no EKS
```

---

## Step 5: Verify Credentials

### Verify in Jenkins UI

1. Navigate to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)**
3. You should see:

| ID | Description | Kind |
|----|-------------|------|
| `kafka-ec2-key` | SSH key for Kafka EC2 instances | SSH Username with private key |
| `jenkins-user` | AWS credentials for Jenkins pipeline | AWS Credentials |

### Test SSH Credential

Create a test pipeline:

```groovy
pipeline {
    agent any
    
    environment {
        SSH_KEY_PATH = credentials('kafka-ec2-key')
    }
    
    stages {
        stage('Test SSH Credential') {
            steps {
                sh '''
                    echo "SSH key loaded successfully!"
                    ls -l $SSH_KEY_PATH
                '''
            }
        }
    }
}
```

### Test AWS Credential

```groovy
pipeline {
    agent any
    
    environment {
        AWS_CREDENTIALS = credentials('jenkins-user')
    }
    
    stages {
        stage('Test AWS Credential') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                                  credentialsId: 'jenkins-user']]) {
                    sh '''
                        aws sts get-caller-identity
                        echo "AWS credentials working!"
                    '''
                }
            }
        }
    }
}
```

---

## Step 6: Re-run the Pipeline

1. Navigate to your pipeline job: **Infra_kafka_pipeline_mainbranch**
2. Click **Build Now**
3. Monitor **Console Output**
4. Pipeline should now proceed past the credential loading phase

### Expected Successful Output

```
[Pipeline] Start of Pipeline
[Pipeline] node
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Declarative: Checkout SCM)
[Pipeline] checkout
✓ Checkout completed
[Pipeline] }
[Pipeline] stage
[Pipeline] { (Terraform Init)
✓ Terraform initialized
...
```

---

## Troubleshooting

### Issue 1: "Credentials not found"

**Symptom**: `ERROR: kafka-ec2-key`

**Solution**:
- Verify credential ID is exactly `kafka-ec2-key` (case-sensitive)
- Check credential scope is **Global**
- Restart Jenkins: `sudo systemctl restart jenkins`

### Issue 2: "Permission denied (publickey)"

**Symptom**: SSH connection fails

**Solution**:
```bash
# Verify key format
head -1 kafka-ec2-key.pem  # Should show: -----BEGIN RSA PRIVATE KEY-----

# Verify username is ec2-user for Amazon Linux
# Verify the key matches the EC2 instance
aws ec2 describe-instances --filters "Name=key-name,Values=kafka-ec2-key"
```

### Issue 3: "Invalid AWS credentials"

**Symptom**: AWS API calls fail

**Solution**:
```bash
# Test credentials locally
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user --user-name jenkins-user
aws iam list-attached-user-policies --user-name jenkins-user
```

### Issue 4: "Key pair does not exist"

**Symptom**: Terraform apply fails with key pair error

**Solution**:
```bash
# List existing key pairs
aws ec2 describe-key-pairs

# Verify terraform.tfvars has correct key name
grep key_name terraform/terraform.tfvars

# Ensure they match
```

---

## Security Best Practices

✅ **Never commit credentials to Git**
```bash
# Add to .gitignore
echo "*.pem" >> .gitignore
echo "**/terraform.tfvars" >> .gitignore
echo "credentials.xml" >> .gitignore
```

✅ **Rotate credentials regularly**
```bash
# Rotate AWS keys every 90 days
aws iam create-access-key --user-name jenkins-user
aws iam delete-access-key --user-name jenkins-user --access-key-id OLD_KEY_ID
```

✅ **Use IAM roles instead of access keys** (when possible)

✅ **Enable MFA for IAM users**

✅ **Apply least privilege principle**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "vpc:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

✅ **Audit credential usage**
```bash
# Check CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=jenkins-user \
  --max-results 10
```

---

## Quick Reference

### Jenkins Credential IDs (must match exactly)

| Credential ID | Type | Username | Purpose |
|--------------|------|----------|----------|
| `kafka-ec2-key` | SSH Username with private key | `ec2-user` | SSH access to EC2 |
| `jenkins-user` | AWS Credentials | N/A | AWS API access |

### Required AWS Permissions

```yaml
Required IAM Policies:
  - AmazonEC2FullAccess
  - AmazonVPCFullAccess
  
Optional (for S3 backups):
  - AmazonS3FullAccess
```

### Key Files

```
Local Machine:
  ✓ kafka-ec2-key.pem (600/400 permissions)
  ✓ terraform/terraform.tfvars (configured)

AWS:
  ✓ EC2 Key Pair: kafka-ec2-key
  ✓ IAM User: jenkins-user (with access keys)

Jenkins:
  ✓ Credential: kafka-ec2-key (SSH)
  ✓ Credential: jenkins-user (AWS)
```

---

## Next Steps

After configuring credentials:

1. ✅ Re-run the Jenkins pipeline
2. ✅ Monitor the console output
3. ✅ Verify all stages complete successfully
4. ✅ Test SSH connectivity to EC2
5. ✅ Verify Kafka deployment
6. ✅ Update documentation with your specific values

---

## Support

If you encounter issues:

1. Check Jenkins logs: `/var/log/jenkins/jenkins.log`
2. Check Terraform logs in pipeline console output
3. Verify AWS credentials: `aws sts get-caller-identity`
4. Test SSH manually: `ssh -i kafka-ec2-key.pem ec2-user@<EC2_IP>`

---

**Last Updated**: 2025-01-02  
**Author**: Platform Team  
**Status**: Ready for Use

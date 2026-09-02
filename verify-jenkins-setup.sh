#!/bin/bash

################################################################################
# Jenkins Credentials Verification Script
# Purpose: Verify all prerequisites are met for Kafka pipeline deployment
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "===================================="
echo "  Jenkins Setup Verification"
echo "===================================="
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

ERRORS=0

# Check 1: AWS CLI
echo "Checking AWS CLI..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    print_status 0 "AWS CLI installed: $AWS_VERSION"
else
    print_status 1 "AWS CLI not installed"
    ((ERRORS++))
fi
echo ""

# Check 2: AWS Credentials
echo "Checking AWS Credentials..."
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_status 0 "AWS Credentials configured"
    echo "   Account: $AWS_ACCOUNT"
    echo "   User: $AWS_USER"
else
    print_status 1 "AWS Credentials not configured or invalid"
    echo -e "${YELLOW}   Run: aws configure${NC}"
    ((ERRORS++))
fi
echo ""

# Check 3: EC2 Key Pair
echo "Checking EC2 Key Pair..."
KEY_NAME="kafka-ec2-key"
if aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
    print_status 0 "EC2 Key Pair '$KEY_NAME' exists in AWS"
    
    # Check local .pem file
    if [ -f "$KEY_NAME.pem" ]; then
        print_status 0 "Local key file '$KEY_NAME.pem' found"
        
        # Check permissions
        PERMS=$(stat -c %a "$KEY_NAME.pem" 2>/dev/null || stat -f %A "$KEY_NAME.pem" 2>/dev/null)
        if [ "$PERMS" = "400" ] || [ "$PERMS" = "600" ]; then
            print_status 0 "Key file permissions are correct ($PERMS)"
        else
            print_status 1 "Key file permissions incorrect: $PERMS (should be 400)"
            echo -e "${YELLOW}   Run: chmod 400 $KEY_NAME.pem${NC}"
            ((ERRORS++))
        fi
    else
        print_status 1 "Local key file '$KEY_NAME.pem' not found"
        echo -e "${YELLOW}   Download from AWS Console or recreate${NC}"
        ((ERRORS++))
    fi
else
    print_status 1 "EC2 Key Pair '$KEY_NAME' not found in AWS"
    echo -e "${YELLOW}   Run: aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem${NC}"
    echo -e "${YELLOW}   Then: chmod 400 $KEY_NAME.pem${NC}"
    ((ERRORS++))
fi
echo ""

# Check 4: Terraform
echo "Checking Terraform..."
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version | head -1)
    print_status 0 "Terraform installed: $TF_VERSION"
else
    print_status 1 "Terraform not installed"
    ((ERRORS++))
fi
echo ""

# Check 5: Terraform Variables
echo "Checking Terraform Configuration..."
if [ -f "terraform/terraform.tfvars" ]; then
    print_status 0 "terraform.tfvars file exists"
    
    # Check required variables
    REQUIRED_VARS=("vpc_id" "subnet_id" "private_vpc_cidr" "admin_ip_address" "key_name")
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^$var" terraform/terraform.tfvars; then
            VALUE=$(grep "^$var" terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
            if [ ! -z "$VALUE" ] && [ "$VALUE" != "YOUR_" ]; then
                print_status 0 "  $var = $VALUE"
            else
                print_status 1 "  $var is not configured"
                ((ERRORS++))
            fi
        else
            print_status 1 "  $var is missing"
            ((ERRORS++))
        fi
    done
else
    print_status 1 "terraform.tfvars not found"
    echo -e "${YELLOW}   Run: cp terraform/terraform.tfvars.example terraform/terraform.tfvars${NC}"
    echo -e "${YELLOW}   Then edit terraform/terraform.tfvars with your values${NC}"
    ((ERRORS++))
fi
echo ""

# Check 6: VPC and Subnet
if [ -f "terraform/terraform.tfvars" ]; then
    echo "Checking VPC and Subnet in AWS..."
    
    VPC_ID=$(grep "^vpc_id" terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo "")
    SUBNET_ID=$(grep "^subnet_id" terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo "")
    
    if [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "vpc-" ]; then
        if aws ec2 describe-vpcs --vpc-ids $VPC_ID &> /dev/null; then
            print_status 0 "VPC $VPC_ID exists"
        else
            print_status 1 "VPC $VPC_ID not found"
            ((ERRORS++))
        fi
    fi
    
    if [ ! -z "$SUBNET_ID" ] && [ "$SUBNET_ID" != "subnet-" ]; then
        if aws ec2 describe-subnets --subnet-ids $SUBNET_ID &> /dev/null; then
            print_status 0 "Subnet $SUBNET_ID exists"
        else
            print_status 1 "Subnet $SUBNET_ID not found"
            ((ERRORS++))
        fi
    fi
    echo ""
fi

# Check 7: Get current IP
echo "Checking Admin IP Address..."
CURRENT_IP=$(curl -s https://checkip.amazonaws.com || echo "Unable to determine")
if [ "$CURRENT_IP" != "Unable to determine" ]; then
    print_status 0 "Your current public IP: $CURRENT_IP"
    
    if [ -f "terraform/terraform.tfvars" ]; then
        CONFIGURED_IP=$(grep "^admin_ip_address" terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo "")
        if [ "$CURRENT_IP" = "$CONFIGURED_IP" ]; then
            print_status 0 "Configured admin IP matches current IP"
        else
            print_status 1 "Configured IP ($CONFIGURED_IP) doesn't match current IP ($CURRENT_IP)"
            echo -e "${YELLOW}   Update terraform.tfvars with: admin_ip_address = \"$CURRENT_IP\"${NC}"
            ((ERRORS++))
        fi
    fi
else
    print_status 1 "Unable to determine current public IP"
fi
echo ""

# Check 8: Required IAM Permissions
echo "Checking IAM Permissions..."
if aws ec2 describe-vpcs --max-results 1 &> /dev/null; then
    print_status 0 "EC2 read permissions"
else
    print_status 1 "Missing EC2 read permissions"
    ((ERRORS++))
fi

if aws ec2 describe-key-pairs --max-results 1 &> /dev/null; then
    print_status 0 "EC2 key pair permissions"
else
    print_status 1 "Missing EC2 key pair permissions"
    ((ERRORS++))
fi
echo ""

# Summary
echo "===================================="
echo "  Verification Summary"
echo "===================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You can now proceed to configure Jenkins credentials:"
    echo "1. Add SSH credential with ID: kafka-ec2-key"
    echo "2. Add AWS credential with ID: jenkins-user"
    echo "3. Run the Jenkins pipeline"
    echo ""
    echo "For detailed instructions, see: JENKINS_CREDENTIALS_SETUP.md"
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    echo "Refer to JENKINS_CREDENTIALS_SETUP.md for detailed setup instructions."
fi
echo "===================================="

exit $ERRORS

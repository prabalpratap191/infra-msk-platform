#!/bin/bash

################################################################################
# AWS Values Helper Script
# This script helps you find the required values for terraform.tfvars
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "===================================="
echo "  AWS Configuration Values Helper"
echo "===================================="
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}Warning: AWS CLI not installed${NC}"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${YELLOW}Warning: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI configured${NC}"
echo ""

# Get AWS Account Info
echo "===================================="
echo "AWS Account Information"
echo "===================================="
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
echo -e "Account: ${BLUE}$AWS_ACCOUNT${NC}"
echo -e "User: ${BLUE}$AWS_USER${NC}"
echo ""

# Get VPCs
echo "===================================="
echo "Available VPCs"
echo "===================================="
echo "Fetching VPCs..."
echo ""

VPCS=$(aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output text)

if [ -z "$VPCS" ]; then
    echo -e "${YELLOW}No VPCs found${NC}"
else
    echo "VPC ID              CIDR Block        Name"
    echo "------------------  ----------------  --------------------"
    echo "$VPCS" | while IFS=$'\t' read -r vpc_id cidr name; do
        name=${name:-"(no name)"}
        printf "%-18s  %-16s  %s\n" "$vpc_id" "$cidr" "$name"
    done
fi
echo ""

# Get your public IP
echo "===================================="
echo "Your Public IP Address"
echo "===================================="
PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)
if [ ! -z "$PUBLIC_IP" ]; then
    echo -e "Public IP: ${BLUE}$PUBLIC_IP${NC}"
else
    echo -e "${YELLOW}Could not determine public IP${NC}"
fi
echo ""

# Prompt for VPC selection
echo "===================================="
echo "Configuration Helper"
echo "===================================="
read -p "Enter your VPC ID: " VPC_ID

if [ -z "$VPC_ID" ]; then
    echo -e "${YELLOW}No VPC ID entered${NC}"
    exit 1
fi

# Get subnets for selected VPC
echo ""
echo "Fetching subnets for VPC: $VPC_ID..."
echo ""

SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$SUBNETS" ]; then
    echo -e "${YELLOW}No subnets found in VPC $VPC_ID${NC}"
    exit 1
fi

echo "Subnet ID           CIDR Block       AZ              Name"
echo "------------------  ---------------  --------------  --------------------"
echo "$SUBNETS" | while IFS=$'\t' read -r subnet_id cidr az name; do
    name=${name:-"(no name)"}
    printf "%-18s  %-15s  %-14s  %s\n" "$subnet_id" "$cidr" "$az" "$name"
done
echo ""

read -p "Enter your Subnet ID: " SUBNET_ID

if [ -z "$SUBNET_ID" ]; then
    echo -e "${YELLOW}No Subnet ID entered${NC}"
    exit 1
fi

# Get VPC CIDR
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text)

echo ""
echo "===================================="
echo "terraform.tfvars Configuration"
echo "===================================="
echo ""
echo "Copy these values to terraform/terraform.tfvars:"
echo ""
echo -e "${GREEN}vpc_id = \"$VPC_ID\"${NC}"
echo -e "${GREEN}subnet_id = \"$SUBNET_ID\"${NC}"
echo -e "${GREEN}private_vpc_cidr = \"$VPC_CIDR\"${NC}"
echo -e "${GREEN}admin_ip_address = \"$PUBLIC_IP\"${NC}"
echo ""

# Offer to update automatically
read -p "Update terraform/terraform.tfvars automatically? (y/n): " UPDATE_FILE

if [ "$UPDATE_FILE" = "y" ] || [ "$UPDATE_FILE" = "Y" ]; then
    if [ -f "terraform/terraform.tfvars" ]; then
        # Update existing file
        sed -i.bak "s/vpc_id = .*/vpc_id = \"$VPC_ID\"/" terraform/terraform.tfvars
        sed -i.bak "s/subnet_id = .*/subnet_id = \"$SUBNET_ID\"/" terraform/terraform.tfvars
        sed -i.bak "s/private_vpc_cidr = .*/private_vpc_cidr = \"$VPC_CIDR\"/" terraform/terraform.tfvars
        sed -i.bak "s/admin_ip_address = .*/admin_ip_address = \"$PUBLIC_IP\"/" terraform/terraform.tfvars
        
        echo ""
        echo -e "${GREEN}✓ terraform/terraform.tfvars updated successfully${NC}"
        echo "Backup saved as: terraform/terraform.tfvars.bak"
    else
        echo -e "${YELLOW}terraform/terraform.tfvars not found${NC}"
        echo "Please create it from terraform.tfvars.example"
    fi
fi

echo ""
echo "===================================="
echo "Next Steps"
echo "===================================="
echo "1. Verify values in terraform/terraform.tfvars"
echo "2. Ensure 'jenkins-user' AWS credential is configured in Jenkins"
echo "3. Run the Jenkins pipeline"
echo "4. SSH keys will be auto-generated!"
echo ""
echo -e "${GREEN}Ready to deploy!${NC}"

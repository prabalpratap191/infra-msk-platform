#!/bin/bash

# ============================================================================
# Kafka Infrastructure Setup Script
# Prepares the repository for deployment
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log "=========================================="
log "Kafka Infrastructure Setup"
log "=========================================="

# Check if running in correct directory
if [ ! -f "README.md" ] || [ ! -d "terraform" ]; then
    error "Please run this script from the repository root directory"
fi

# Make scripts executable
log "Making scripts executable..."
chmod +x scripts/*.sh
chmod +x setup.sh
log "Scripts are now executable"

# Create secrets directory
log "Creating secrets directory..."
mkdir -p secrets
echo "# SSH keys will be stored here" > secrets/README.md
log "Secrets directory created"

# Check required tools
log "Checking required tools..."

if ! command -v terraform &> /dev/null; then
    warn "Terraform not found. Please install Terraform >= 1.5.0"
    warn "Download from: https://www.terraform.io/downloads"
else
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    log "Terraform version: $TERRAFORM_VERSION"
fi

if ! command -v aws &> /dev/null; then
    warn "AWS CLI not found. Please install AWS CLI >= 2.0"
    warn "Download from: https://aws.amazon.com/cli/"
else
    AWS_VERSION=$(aws --version)
    log "AWS CLI: $AWS_VERSION"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
        log "AWS Account: $AWS_ACCOUNT"
        log "AWS User: $AWS_USER"
    else
        warn "AWS credentials not configured. Run 'aws configure'"
    fi
fi

if ! command -v kubectl &> /dev/null; then
    warn "kubectl not found (optional for EKS integration)"
    warn "Download from: https://kubernetes.io/docs/tasks/tools/"
else
    KUBECTL_VERSION=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    log "kubectl version: $KUBECTL_VERSION"
fi

if ! command -v jq &> /dev/null; then
    warn "jq not found (recommended for JSON parsing)"
    warn "Install: apt-get install jq (Ubuntu) or brew install jq (Mac)"
fi

# Setup Terraform backend
log "Checking Terraform backend..."

BUCKET_NAME="meracommerce-terraform-state"
TABLE_NAME="meracommerce-terraform-locks"
REGION="us-east-1"

if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    info "S3 bucket not found. Creating..."
    read -p "Create S3 bucket $BUCKET_NAME? (y/n): " CREATE_BUCKET
    if [ "$CREATE_BUCKET" = "y" ]; then
        aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled
        log "S3 bucket created: $BUCKET_NAME"
    else
        warn "Skipping S3 bucket creation. You'll need to create it manually."
    fi
else
    log "S3 bucket exists: $BUCKET_NAME"
fi

if ! aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" &> /dev/null; then
    info "DynamoDB table not found. Creating..."
    read -p "Create DynamoDB table $TABLE_NAME? (y/n): " CREATE_TABLE
    if [ "$CREATE_TABLE" = "y" ]; then
        aws dynamodb create-table \
            --table-name "$TABLE_NAME" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$REGION"
        log "DynamoDB table created: $TABLE_NAME"
    else
        warn "Skipping DynamoDB table creation. You'll need to create it manually."
    fi
else
    log "DynamoDB table exists: $TABLE_NAME"
fi

# Setup terraform.tfvars
log "Checking Terraform configuration..."
cd terraform/environments/dev

if [ ! -f "terraform.tfvars" ]; then
    info "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    log "terraform.tfvars created"
    warn "IMPORTANT: Edit terraform/environments/dev/terraform.tfvars"
    warn "Update 'admin_cidr_blocks' with your IP address!"
    
    # Try to get user's public IP
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s https://api.ipify.org)
        if [ -n "$PUBLIC_IP" ]; then
            info "Your public IP appears to be: $PUBLIC_IP"
            info "Suggested value: admin_cidr_blocks = [\"$PUBLIC_IP/32\"]"
        fi
    fi
else
    log "terraform.tfvars already exists"
fi

cd ../../..

# Initialize Terraform (optional)
read -p "Initialize Terraform now? (y/n): " INIT_TF
if [ "$INIT_TF" = "y" ]; then
    log "Initializing Terraform..."
    cd terraform/environments/dev
    terraform init
    cd ../../..
    log "Terraform initialized successfully"
fi

log "=========================================="
log "Setup Complete!"
log "=========================================="

echo ""
info "Next steps:"
echo "1. Edit terraform/environments/dev/terraform.tfvars"
echo "2. Update 'admin_cidr_blocks' with your IP"
echo "3. Run deployment:"
echo "   - Via Jenkins: See jenkins/Jenkinsfile"
echo "   - Manually: cd terraform/environments/dev && terraform apply"
echo "4. Read QUICK_START.md for detailed guide"
echo ""

log "Happy deploying! 🚀"

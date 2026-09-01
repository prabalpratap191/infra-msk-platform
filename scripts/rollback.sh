#!/bin/bash

################################################################################
# MSK Infrastructure Rollback Script
# This script provides automated rollback capabilities for MSK deployment
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
REGION="us-east-1"
TERRAFORM_DIR="../terraform/environments/$ENVIRONMENT"
BACKUP_DIR="../backups"

echo "========================================"
echo "MSK Infrastructure Rollback"
echo "========================================"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to confirm action
confirm() {
    read -p "$1 [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
}

# 1. Verify prerequisites
echo "Checking prerequisites..."
if ! command -v terraform &> /dev/null; then
    print_status 1 "Terraform not found"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_status 1 "AWS CLI not found"
    exit 1
fi

print_status 0 "Prerequisites verified"

# 2. Check current state
echo ""
echo "Checking current infrastructure state..."
cd "$TERRAFORM_DIR"

terraform init -reconfigure > /dev/null 2>&1

if terraform state list &> /dev/null; then
    RESOURCE_COUNT=$(terraform state list | wc -l)
    print_status 0 "Current resources: $RESOURCE_COUNT"
else
    print_status 1 "No Terraform state found"
    exit 1
fi

# 3. List available backups
echo ""
echo "Available state backups:"
if [ -d "$BACKUP_DIR" ]; then
    ls -lht "$BACKUP_DIR" | grep "tfstate" | head -5
else
    echo "No backups found"
fi

# 4. Rollback options
echo ""
echo "Rollback Options:"
echo "  1. Rollback to previous Terraform state"
echo "  2. Destroy all infrastructure"
echo "  3. Selective resource removal"
echo "  4. Cancel"
echo ""
read -p "Select option [1-4]: " OPTION

case $OPTION in
    1)
        echo ""
        echo "Rolling back to previous state..."
        
        # Create backup of current state
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/terraform-$(date +%Y%m%d-%H%M%S).tfstate.backup"
        
        if [ -f "terraform.tfstate" ]; then
            cp terraform.tfstate "$BACKUP_FILE"
            print_status 0 "Current state backed up to: $BACKUP_FILE"
        fi
        
        # Find latest backup
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.tfstate.backup 2>/dev/null | head -2 | tail -1)
        
        if [ -z "$LATEST_BACKUP" ]; then
            print_status 1 "No previous backup found"
            exit 1
        fi
        
        echo "Latest backup: $LATEST_BACKUP"
        confirm "Restore this backup?"
        
        # Restore backup
        cp "$LATEST_BACKUP" terraform.tfstate
        print_status 0 "State restored"
        
        # Apply the restored state
        echo ""
        echo "Applying restored state..."
        terraform apply -auto-approve
        ;;
        
    2)
        echo ""
        echo -e "${RED}WARNING: This will destroy ALL infrastructure!${NC}"
        confirm "Are you sure you want to continue?"
        
        # Backup current state
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/terraform-$(date +%Y%m%d-%H%M%S).tfstate.backup"
        
        if [ -f "terraform.tfstate" ]; then
            cp terraform.tfstate "$BACKUP_FILE"
            print_status 0 "Current state backed up to: $BACKUP_FILE"
        fi
        
        # Destroy infrastructure
        echo ""
        echo "Destroying infrastructure..."
        terraform destroy -auto-approve
        
        print_status 0 "Infrastructure destroyed"
        ;;
        
    3)
        echo ""
        echo "Current resources:"
        terraform state list
        echo ""
        read -p "Enter resource address to remove: " RESOURCE
        
        if [ -z "$RESOURCE" ]; then
            print_status 1 "No resource specified"
            exit 1
        fi
        
        confirm "Remove resource: $RESOURCE?"
        
        # Remove resource
        terraform state rm "$RESOURCE"
        print_status 0 "Resource removed from state"
        ;;
        
    4)
        echo "Rollback cancelled"
        exit 0
        ;;
        
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# 5. Verify final state
echo ""
echo "Verifying final state..."
RESOURCE_COUNT=$(terraform state list | wc -l)
echo "Resources in state: $RESOURCE_COUNT"

# Summary
echo ""
echo "========================================"
echo "Rollback Complete"
echo "========================================"
echo ""
echo "Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Resources: $RESOURCE_COUNT"
echo ""
echo -e "${GREEN}✓ Rollback operation completed successfully${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify infrastructure state"
echo "  2. Run verification scripts"
echo "  3. Update documentation"
echo ""

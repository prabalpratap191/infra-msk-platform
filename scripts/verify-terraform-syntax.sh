#!/bin/bash

################################################################################
# Terraform Syntax Verification Script
# Quick validation of Terraform configuration before Jenkins deployment
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Syntax Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_status 1 "Terraform not found. Please install Terraform first."
    exit 1
fi

print_status 0 "Terraform found"
terraform version
echo ""

# Environments to check
ENVIRONMENTS=("dev" "staging" "prod")

for ENV in "${ENVIRONMENTS[@]}"; do
    ENV_DIR="../terraform/environments/$ENV"
    
    if [ ! -d "$ENV_DIR" ]; then
        print_warning "Environment directory not found: $ENV_DIR"
        continue
    fi
    
    echo -e "${BLUE}Checking environment: $ENV${NC}"
    echo ""
    
    cd "$ENV_DIR" || exit 1
    
    # Step 1: Initialize (backend disabled for syntax check)
    print_info "Initializing Terraform..."
    if terraform init -backend=false > /dev/null 2>&1; then
        print_status 0 "Terraform initialized"
    else
        print_status 1 "Terraform initialization failed"
        cd - > /dev/null
        continue
    fi
    
    # Step 2: Validate syntax
    print_info "Validating Terraform syntax..."
    if terraform validate > /dev/null 2>&1; then
        print_status 0 "Terraform validation passed"
    else
        print_status 1 "Terraform validation failed"
        echo ""
        echo "Validation errors:"
        terraform validate
        cd - > /dev/null
        continue
    fi
    
    # Step 3: Format check
    print_info "Checking Terraform formatting..."
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        print_status 0 "Terraform formatting is correct"
    else
        print_warning "Terraform files need formatting"
        echo "Run: terraform fmt -recursive"
    fi
    
    echo ""
    cd - > /dev/null
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Syntax Verification Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. If all checks passed, commit and push changes"
echo "  2. Run Jenkins pipeline with ACTION=plan"
echo "  3. Review plan output"
echo "  4. Apply changes if plan looks good"
echo ""

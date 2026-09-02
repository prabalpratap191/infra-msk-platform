#!/bin/bash

# ============================================================================
# Terraform Configuration Verification Script
# Verifies that all required files and configurations are in place
# ============================================================================

set -e

ECHO_RED='\033[0;31m'
ECHO_GREEN='\033[0;32m'
ECHO_YELLOW='\033[1;33m'
ECHO_BLUE='\033[0;34m'
ECHO_NC='\033[0m' # No Color

echo -e "${ECHO_BLUE}=========================================="
echo -e "Terraform Configuration Verification"
echo -e "==========================================${ECHO_NC}\n"

# Function to check file exists
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${ECHO_GREEN}✓${ECHO_NC} $description: Found"
        return 0
    else
        echo -e "${ECHO_RED}✗${ECHO_NC} $description: Missing"
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${ECHO_GREEN}✓${ECHO_NC} $description: Found"
        return 0
    else
        echo -e "${ECHO_RED}✗${ECHO_NC} $description: Missing"
        return 1
    fi
}

ERRORS=0

echo -e "${ECHO_BLUE}Checking directory structure...${ECHO_NC}"
check_dir "terraform/environments/dev" "Dev environment directory" || ((ERRORS++))
check_dir "terraform/modules" "Terraform modules directory" || ((ERRORS++))
check_dir "scripts" "Scripts directory" || ((ERRORS++))
echo ""

echo -e "${ECHO_BLUE}Checking Terraform files...${ECHO_NC}"
check_file "terraform/environments/dev/terraform.tfvars" "terraform.tfvars (REQUIRED)" || {
    echo -e "${ECHO_YELLOW}  → Run: cd terraform/environments/dev && cp terraform.tfvars.example terraform.tfvars${ECHO_NC}"
    ((ERRORS++))
}
check_file "terraform/environments/dev/terraform.tfvars.example" "terraform.tfvars.example" || ((ERRORS++))
check_file "terraform/environments/dev/main.tf" "main.tf" || ((ERRORS++))
check_file "terraform/environments/dev/variables.tf" "variables.tf" || ((ERRORS++))
check_file "terraform/environments/dev/outputs.tf" "outputs.tf" || ((ERRORS++))
echo ""

echo -e "${ECHO_BLUE}Checking scripts...${ECHO_NC}"
check_file "scripts/create-topics.sh" "Topic creation script" || ((ERRORS++))
check_file "scripts/deploy-kafka.sh" "Kafka deployment script" || ((ERRORS++))
check_file "scripts/validate-kafka.sh" "Kafka validation script" || ((ERRORS++))
check_file "scripts/rollback.sh" "Rollback script" || ((ERRORS++))
echo ""

echo -e "${ECHO_BLUE}Checking documentation...${ECHO_NC}"
check_file "README.md" "README" || ((ERRORS++))
check_file "docs/DEPLOYMENT.md" "Deployment guide" || ((ERRORS++))
check_file "docs/JENKINS_PIPELINE_FIX.md" "Pipeline fix guide" || ((ERRORS++))
echo ""

echo -e "${ECHO_BLUE}Checking Terraform syntax...${ECHO_NC}"
if command -v terraform &> /dev/null; then
    cd terraform/environments/dev
    
    echo -n "Initializing Terraform... "
    if terraform init -backend=false &> /dev/null; then
        echo -e "${ECHO_GREEN}✓${ECHO_NC}"
    else
        echo -e "${ECHO_RED}✗${ECHO_NC}"
        ((ERRORS++))
    fi
    
    echo -n "Validating configuration... "
    if terraform validate &> /dev/null; then
        echo -e "${ECHO_GREEN}✓${ECHO_NC}"
    else
        echo -e "${ECHO_RED}✗${ECHO_NC}"
        echo -e "${ECHO_YELLOW}  → Run: terraform validate for details${ECHO_NC}"
        ((ERRORS++))
    fi
    
    echo -n "Checking format... "
    if terraform fmt -check -recursive &> /dev/null; then
        echo -e "${ECHO_GREEN}✓${ECHO_NC}"
    else
        echo -e "${ECHO_YELLOW}⚠${ECHO_NC} Formatting issues found"
        echo -e "${ECHO_YELLOW}  → Run: terraform fmt -recursive to fix${ECHO_NC}"
    fi
    
    cd ../../..
else
    echo -e "${ECHO_YELLOW}⚠${ECHO_NC} Terraform not installed - skipping validation"
fi
echo ""

echo -e "${ECHO_BLUE}Checking critical configuration values...${ECHO_NC}"
if [ -f "terraform/environments/dev/terraform.tfvars" ]; then
    # Check for insecure admin CIDR
    if grep -q 'admin_cidr_blocks.*=.*\[.*"0.0.0.0/0".*\]' "terraform/environments/dev/terraform.tfvars"; then
        echo -e "${ECHO_YELLOW}⚠${ECHO_NC} admin_cidr_blocks is set to 0.0.0.0/0 (allows all IPs)"
        echo -e "${ECHO_YELLOW}  → RECOMMENDATION: Restrict to specific IP ranges in production${ECHO_NC}"
    else
        echo -e "${ECHO_GREEN}✓${ECHO_NC} admin_cidr_blocks is restricted"
    fi
    
    # Check SSH key name is set
    if grep -q 'ssh_key_name.*=.*".*"' "terraform/environments/dev/terraform.tfvars"; then
        KEY_NAME=$(grep 'ssh_key_name' "terraform/environments/dev/terraform.tfvars" | sed 's/.*"\(.*\)".*/\1/')
        echo -e "${ECHO_GREEN}✓${ECHO_NC} ssh_key_name is configured: $KEY_NAME"
        echo -e "${ECHO_YELLOW}  → Ensure this key exists in AWS before deployment${ECHO_NC}"
    else
        echo -e "${ECHO_RED}✗${ECHO_NC} ssh_key_name not configured"
        ((ERRORS++))
    fi
    
    # Check AWS region is set
    if grep -q 'aws_region.*=.*".*"' "terraform/environments/dev/terraform.tfvars"; then
        REGION=$(grep 'aws_region' "terraform/environments/dev/terraform.tfvars" | sed 's/.*"\(.*\)".*/\1/')
        echo -e "${ECHO_GREEN}✓${ECHO_NC} aws_region is configured: $REGION"
    else
        echo -e "${ECHO_RED}✗${ECHO_NC} aws_region not configured"
        ((ERRORS++))
    fi
fi
echo ""

echo -e "${ECHO_BLUE}==========================================${ECHO_NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${ECHO_GREEN}✓ All checks passed!${ECHO_NC}"
    echo -e "${ECHO_GREEN}Configuration is ready for deployment.${ECHO_NC}"
    exit 0
else
    echo -e "${ECHO_RED}✗ Found $ERRORS issue(s)${ECHO_NC}"
    echo -e "${ECHO_YELLOW}Please fix the issues above before deployment.${ECHO_NC}"
    echo ""
    echo -e "${ECHO_BLUE}Quick fixes:${ECHO_NC}"
    echo "  1. Create terraform.tfvars:"
    echo "     cd terraform/environments/dev && cp terraform.tfvars.example terraform.tfvars"
    echo ""
    echo "  2. Review configuration:"
    echo "     vim terraform/environments/dev/terraform.tfvars"
    echo ""
    echo "  3. Re-run this script:"
    echo "     bash scripts/verify-config.sh"
    exit 1
fi

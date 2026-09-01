#!/bin/bash

# ============================================================================
# Kafka Infrastructure Rollback Script
# Safely rollback Kafka infrastructure changes
# ============================================================================

set -e

ENVIRONMENT="${1:-dev}"
TERRAFORM_DIR="../terraform/environments/$ENVIRONMENT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

log "=========================================="
log "Kafka Infrastructure Rollback"
log "Environment: $ENVIRONMENT"
log "=========================================="

# Confirmation
warn "This will destroy ALL Kafka infrastructure in $ENVIRONMENT environment!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log "Rollback cancelled"
    exit 0
fi

read -p "Type 'DESTROY' to confirm: " CONFIRM_DESTROY

if [ "$CONFIRM_DESTROY" != "DESTROY" ]; then
    log "Rollback cancelled"
    exit 0
fi

# Navigate to Terraform directory
if [ ! -d "$TERRAFORM_DIR" ]; then
    error "Terraform directory not found: $TERRAFORM_DIR"
fi

cd "$TERRAFORM_DIR"

# Backup current state
log "Backing up Terraform state..."
STATE_BACKUP="terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "$STATE_BACKUP"
    log "State backed up to: $STATE_BACKUP"
fi

# Terraform destroy
log "Running Terraform destroy..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    log "=========================================="
    log "Rollback Complete"
    log "All infrastructure has been destroyed"
    log "State backup: $STATE_BACKUP"
    log "=========================================="nelse
    error "Terraform destroy failed. Check logs for details."
fi

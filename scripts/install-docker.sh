#!/bin/bash

# ============================================================================
# Docker Installation Script for Amazon Linux 2023
# ============================================================================

set -e

LOG_FILE="/var/log/docker-install.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "Starting Docker Installation"
log "========================================"

# Update system
log "Updating system packages..."
sudo yum update -y >> "$LOG_FILE" 2>&1

# Install Docker
log "Installing Docker..."
sudo yum install -y docker >> "$LOG_FILE" 2>&1

# Start Docker service
log "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
log "Adding user to docker group..."
sudo usermod -aG docker $USER

# Install Docker Compose
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.5"
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify installation
log "Verifying Docker installation..."
docker --version >> "$LOG_FILE" 2>&1
docker-compose --version >> "$LOG_FILE" 2>&1

# Configure Docker daemon
log "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker

log "========================================"
log "Docker Installation Complete"
log "Docker Version: $(docker --version)"
log "Docker Compose Version: $(docker-compose --version)"
log "========================================"

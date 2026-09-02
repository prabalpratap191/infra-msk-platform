#!/bin/bash

################################################################################
# Docker Installation Script for Amazon Linux 2023
# This script installs Docker and Docker Compose on EC2 instance
################################################################################

set -e

LOG_FILE="/var/log/docker-installation.log"

echo "====================================" | tee -a $LOG_FILE
echo "Docker Installation Script" | tee -a $LOG_FILE
echo "Date: $(date)" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

# Install Docker
echo "[1/5] Installing Docker..." | tee -a $LOG_FILE
sudo yum install -y docker 2>&1 | tee -a $LOG_FILE

# Start and enable Docker
echo "[2/5] Starting Docker service..." | tee -a $LOG_FILE
sudo systemctl start docker 2>&1 | tee -a $LOG_FILE
sudo systemctl enable docker 2>&1 | tee -a $LOG_FILE

# Add ec2-user to docker group
echo "[3/5] Adding ec2-user to docker group..." | tee -a $LOG_FILE
sudo usermod -a -G docker ec2-user 2>&1 | tee -a $LOG_FILE

# Verify Docker installation
echo "[4/5] Verifying Docker installation..." | tee -a $LOG_FILE
sudo docker --version 2>&1 | tee -a $LOG_FILE

# Install Docker Compose
echo "[5/5] Installing Docker Compose..." | tee -a $LOG_FILE
sudo mkdir -p /usr/local/lib/docker/cli-plugins 2>&1 | tee -a $LOG_FILE
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose 2>&1 | tee -a $LOG_FILE
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose 2>&1 | tee -a $LOG_FILE
sudo ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>&1 | tee -a $LOG_FILE

# Verify Docker Compose installation
echo "Verifying Docker Compose installation..." | tee -a $LOG_FILE
sudo docker compose version 2>&1 | tee -a $LOG_FILE

echo "====================================" | tee -a $LOG_FILE
echo "✓ Docker installation completed successfully" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

#!/bin/bash

set -e

LOG_FILE="/home/ec2-user/docker-installation.log"

echo "====================================" | tee -a $LOG_FILE
echo "Docker Installation Script" | tee -a $LOG_FILE
echo "Date: $(date)" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE

echo "[1/5] Installing Docker..." | tee -a $LOG_FILE

sudo dnf update -y >> $LOG_FILE 2>&1
sudo dnf install -y docker >> $LOG_FILE 2>&1

echo "[2/5] Starting Docker service..." | tee -a $LOG_FILE

sudo systemctl enable docker >> $LOG_FILE 2>&1
sudo systemctl start docker >> $LOG_FILE 2>&1

echo "[3/5] Adding ec2-user to docker group..." | tee -a $LOG_FILE

sudo usermod -aG docker ec2-user >> $LOG_FILE 2>&1

echo "[4/5] Verifying Docker installation..." | tee -a $LOG_FILE

sudo docker --version | tee -a $LOG_FILE

echo "[5/5] Installing Docker Compose..." | tee -a $LOG_FILE

sudo mkdir -p /usr/local/lib/docker/cli-plugins

sudo curl -SL \
https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
-o /usr/local/lib/docker/cli-plugins/docker-compose

sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

sudo docker compose version | tee -a $LOG_FILE

echo "====================================" | tee -a $LOG_FILE
echo "✓ Docker installation completed successfully" | tee -a $LOG_FILE
echo "====================================" | tee -a $LOG_FILE
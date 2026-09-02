#!/bin/bash
set -e

# Log file for debugging
LOG_FILE="/var/log/kafka-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=================================="
echo "Starting Kafka EC2 Basic Setup"
echo "Date: $(date)"
echo "=================================="

# Update system
echo "[1/2] Updating system packages..."
yum update -y

# Install basic utilities
echo "[2/2] Installing basic utilities..."
yum install -y curl wget git vim

echo "=================================="
echo "EC2 Basic Setup Completed"
echo "System is ready for Docker and Kafka installation via SSH"
echo "Date: $(date)"
echo "=================================="

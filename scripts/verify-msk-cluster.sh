#!/bin/bash

################################################################################
# MSK Cluster Health Verification Script
# This script verifies the health and status of the MSK cluster
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
CLUSTER_NAME="msk-cluster-dev"

echo "========================================"
echo "MSK Cluster Health Verification"
echo "========================================"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# 1. Check if AWS CLI is installed
echo "Checking prerequisites..."
if command -v aws &> /dev/null; then
    print_status 0 "AWS CLI is installed"
else
    print_status 1 "AWS CLI is not installed"
    exit 1
fi

# 2. Get cluster ARN
echo ""
echo "Fetching cluster information..."
CLUSTER_ARN=$(aws kafka list-clusters \
    --region $REGION \
    --query "ClusterInfoList[?ClusterName=='$CLUSTER_NAME'].ClusterArn" \
    --output text)

if [ -z "$CLUSTER_ARN" ]; then
    print_status 1 "Cluster not found: $CLUSTER_NAME"
    exit 1
else
    print_status 0 "Cluster found"
    echo "   ARN: $CLUSTER_ARN"
fi

# 3. Check cluster state
echo ""
echo "Checking cluster state..."
CLUSTER_STATE=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.State' \
    --output text)

echo "   State: $CLUSTER_STATE"

if [ "$CLUSTER_STATE" == "ACTIVE" ]; then
    print_status 0 "Cluster is ACTIVE"
else
    print_status 1 "Cluster is not ACTIVE (State: $CLUSTER_STATE)"
fi

# 4. Get broker information
echo ""
echo "Fetching broker information..."
BROKER_INFO=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.{Brokers:NumberOfBrokerNodes,Type:BrokerNodeGroupInfo.InstanceType,Storage:BrokerNodeGroupInfo.StorageInfo.EbsStorageInfo.VolumeSize}' \
    --output json)

echo "$BROKER_INFO" | jq '.'

NUM_BROKERS=$(echo "$BROKER_INFO" | jq -r '.Brokers')
if [ "$NUM_BROKERS" -ge 3 ]; then
    print_status 0 "Broker count: $NUM_BROKERS (Multi-AZ)"
else
    print_status 1 "Broker count: $NUM_BROKERS (Less than 3)"
fi

# 5. Get bootstrap brokers
echo ""
echo "Fetching bootstrap brokers..."
BOOTSTRAP_TLS=$(aws kafka get-bootstrap-brokers \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'BootstrapBrokerStringTls' \
    --output text)

BOOTSTRAP_IAM=$(aws kafka get-bootstrap-brokers \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'BootstrapBrokerStringSaslIam' \
    --output text)

if [ -n "$BOOTSTRAP_TLS" ]; then
    print_status 0 "TLS bootstrap brokers available"
    echo "   $BOOTSTRAP_TLS"
fi

if [ -n "$BOOTSTRAP_IAM" ]; then
    print_status 0 "IAM bootstrap brokers available"
    echo "   $BOOTSTRAP_IAM"
fi

# 6. Check encryption settings
echo ""
echo "Checking security configuration..."
ENCRYPTION_INFO=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.EncryptionInfo' \
    --output json)

IN_TRANSIT=$(echo "$ENCRYPTION_INFO" | jq -r '.EncryptionInTransit.ClientBroker')
AT_REST=$(echo "$ENCRYPTION_INFO" | jq -r '.EncryptionAtRest.DataVolumeKMSKeyId')

if [ "$IN_TRANSIT" == "TLS" ] || [ "$IN_TRANSIT" == "TLS_PLAINTEXT" ]; then
    print_status 0 "Encryption in transit: $IN_TRANSIT"
else
    print_status 1 "Encryption in transit: $IN_TRANSIT"
fi

if [ -n "$AT_REST" ] && [ "$AT_REST" != "null" ]; then
    print_status 0 "Encryption at rest: Enabled"
else
    print_status 1 "Encryption at rest: Disabled"
fi

# 7. Check monitoring
echo ""
echo "Checking monitoring configuration..."
MONITORING_LEVEL=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.EnhancedMonitoring' \
    --output text)

echo "   Enhanced Monitoring: $MONITORING_LEVEL"
if [ "$MONITORING_LEVEL" != "DEFAULT" ]; then
    print_status 0 "Enhanced monitoring enabled"
else
    print_status 1 "Enhanced monitoring at DEFAULT level"
fi

# 8. List CloudWatch metrics
echo ""
echo "Checking CloudWatch metrics..."
METRICS=$(aws cloudwatch list-metrics \
    --region $REGION \
    --namespace AWS/Kafka \
    --dimensions Name="Cluster Name",Value="$CLUSTER_NAME" \
    --query 'Metrics[].MetricName' \
    --output text | wc -w)

if [ "$METRICS" -gt 0 ]; then
    print_status 0 "CloudWatch metrics available: $METRICS metrics"
else
    print_status 1 "No CloudWatch metrics found"
fi

# Summary
echo ""
echo "========================================"
echo "Verification Complete"
echo "========================================"
echo ""
echo "Cluster Status Summary:"
echo "  Name: $CLUSTER_NAME"
echo "  State: $CLUSTER_STATE"
echo "  Brokers: $NUM_BROKERS"
echo "  Region: $REGION"
echo ""

if [ "$CLUSTER_STATE" == "ACTIVE" ]; then
    echo -e "${GREEN}✓ Cluster is healthy and ready to use${NC}"
    exit 0
else
    echo -e "${RED}✗ Cluster is not ready${NC}"
    exit 1
fi

#!/bin/bash

################################################################################
# MSK Connectivity Verification Script
# This script verifies network connectivity to MSK cluster from EKS
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REGION="us-east-1"
CLUSTER_NAME="msk-cluster-dev"
EKS_CLUSTER_NAME="eks-cluster-dev"

echo "========================================"
echo "MSK Connectivity Verification"
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

# 1. Get cluster ARN and bootstrap brokers
echo "Fetching MSK cluster information..."
CLUSTER_ARN=$(aws kafka list-clusters \
    --region $REGION \
    --query "ClusterInfoList[?ClusterName=='$CLUSTER_NAME'].ClusterArn" \
    --output text)

if [ -z "$CLUSTER_ARN" ]; then
    print_status 1 "Cluster not found"
    exit 1
fi

BOOTSTRAP_BROKERS=$(aws kafka get-bootstrap-brokers \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'BootstrapBrokerStringSaslIam' \
    --output text)

print_status 0 "Bootstrap brokers retrieved"
echo "   $BOOTSTRAP_BROKERS"

# 2. Parse broker endpoints
echo ""
echo "Parsing broker endpoints..."
IFS=',' read -ra BROKERS <<< "$BOOTSTRAP_BROKERS"
BROKER_COUNT=${#BROKERS[@]}
echo "   Found $BROKER_COUNT broker endpoints"

# 3. Test network connectivity to each broker
echo ""
echo "Testing network connectivity..."
for BROKER in "${BROKERS[@]}"; do
    HOST=$(echo "$BROKER" | cut -d':' -f1)
    PORT=$(echo "$BROKER" | cut -d':' -f2)
    
    echo ""
    echo "Testing connection to: $HOST:$PORT"
    
    # DNS resolution test
    if nslookup "$HOST" > /dev/null 2>&1; then
        print_status 0 "DNS resolution successful"
        IP=$(nslookup "$HOST" | grep -A1 "Name:" | grep "Address:" | tail -1 | awk '{print $2}')
        echo "   Resolved to: $IP"
    else
        print_status 1 "DNS resolution failed"
        continue
    fi
    
    # Port connectivity test
    if timeout 5 bash -c "</dev/tcp/$HOST/$PORT" 2>/dev/null; then
        print_status 0 "Port $PORT is reachable"
    else
        print_status 1 "Port $PORT is not reachable"
    fi
done

# 4. Check VPC connectivity
echo ""
echo "Checking VPC configuration..."
VPC_CONFIG=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.BrokerNodeGroupInfo.{Subnets:ClientSubnets,SecurityGroups:SecurityGroups}' \
    --output json)

echo "$VPC_CONFIG" | jq '.'

SUBNETS=$(echo "$VPC_CONFIG" | jq -r '.Subnets[]')
SECURITY_GROUPS=$(echo "$VPC_CONFIG" | jq -r '.SecurityGroups[]')

print_status 0 "VPC configuration retrieved"
echo "   Subnets: $(echo $SUBNETS | wc -w)"
echo "   Security Groups: $(echo $SECURITY_GROUPS | wc -w)"

# 5. Check security group rules
echo ""
echo "Checking security group rules..."
for SG in $SECURITY_GROUPS; do
    echo ""
    echo "Security Group: $SG"
    
    RULES=$(aws ec2 describe-security-groups \
        --region $REGION \
        --group-ids "$SG" \
        --query 'SecurityGroups[0].IpPermissions' \
        --output json)
    
    # Check for Kafka ports
    KAFKA_PORTS=("9092" "9094" "9098" "2181")
    for PORT in "${KAFKA_PORTS[@]}"; do
        if echo "$RULES" | jq -e ".[] | select(.FromPort==$PORT)" > /dev/null 2>&1; then
            print_status 0 "Port $PORT allowed in security group"
        else
            echo -e "${YELLOW}⚠${NC} Port $PORT not found in security group rules"
        fi
    done
done

# 6. Create Kubernetes job for connectivity test (if EKS is available)
echo ""
echo "Checking EKS cluster availability..."
if aws eks describe-cluster --region $REGION --name "$EKS_CLUSTER_NAME" > /dev/null 2>&1; then
    print_status 0 "EKS cluster found: $EKS_CLUSTER_NAME"
    
    echo ""
    echo "To test connectivity from EKS, run:"
    echo ""
    echo "kubectl run kafka-test --image=confluentinc/cp-kafka:latest --rm -it --restart=Never -- bash -c \\""
    echo "  kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_BROKERS \\""
    echo "  --command-config /tmp/client.properties\\""
    echo ""
else
    echo -e "${YELLOW}⚠${NC} EKS cluster not found or not accessible"
fi

# 7. Test Zookeeper connectivity
echo ""
echo "Fetching Zookeeper connection string..."
ZK_CONNECTION=$(aws kafka describe-cluster \
    --region $REGION \
    --cluster-arn "$CLUSTER_ARN" \
    --query 'ClusterInfo.ZookeeperConnectString' \
    --output text)

if [ -n "$ZK_CONNECTION" ]; then
    print_status 0 "Zookeeper connection string available"
    echo "   $ZK_CONNECTION"
else
    print_status 1 "Zookeeper connection string not available"
fi

# Summary
echo ""
echo "========================================"
echo "Connectivity Check Complete"
echo "========================================"
echo ""
echo "Summary:"
echo "  Cluster: $CLUSTER_NAME"
echo "  Brokers: $BROKER_COUNT"
echo "  Bootstrap Servers: Available"
echo ""
echo -e "${GREEN}✓ Connectivity verification complete${NC}"
echo ""
echo "Next steps:"
echo "  1. Ensure EKS pods have proper IAM roles (IRSA)"
echo "  2. Update security groups to allow traffic from EKS"
echo "  3. Test from within EKS using kafka-console-producer/consumer"
echo ""

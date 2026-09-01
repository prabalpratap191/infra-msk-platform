#!/bin/bash

################################################################################
# Setup IAM Roles for Service Accounts (IRSA) for MSK Access
# This script creates IAM roles for Kubernetes service accounts in EKS
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

REGION="us-east-1"
EKS_CLUSTER_NAME="meracommerce-dev-cluster"
MSK_CLUSTER_NAME="msk-cluster-dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Setup IRSA for MSK Access${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${BLUE}AWS Account ID:${NC} $AWS_ACCOUNT_ID"

# Get EKS OIDC Provider
OIDC_PROVIDER=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.identity.oidc.issuer' \
    --output text | sed 's|https://||')

echo -e "${BLUE}OIDC Provider:${NC} $OIDC_PROVIDER"

# Get MSK Cluster ARN
MSK_CLUSTER_ARN=$(aws kafka list-clusters \
    --region "$REGION" \
    --query "ClusterInfoList[?ClusterName=='$MSK_CLUSTER_NAME'].ClusterArn" \
    --output text)

if [ -z "$MSK_CLUSTER_ARN" ]; then
    echo -e "${YELLOW}MSK cluster not found. Deploy infrastructure first.${NC}"
    exit 1
fi

echo -e "${BLUE}MSK Cluster ARN:${NC} $MSK_CLUSTER_ARN"
echo ""

# Namespaces
NAMESPACES=(
    "customer-service-ns"
    "order-service-ns"
    "catalog-service-ns"
    "order-history-service-ns"
    "notification-service-ns"
    "payments-service-ns"
)

# Create IAM policy for MSK access
POLICY_NAME="MSK-Kafka-Access-Policy"

echo "Creating IAM policy: $POLICY_NAME"

POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:DescribeCluster"
      ],
      "Resource": "${MSK_CLUSTER_ARN}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:*Topic*",
        "kafka-cluster:WriteData",
        "kafka-cluster:ReadData"
      ],
      "Resource": "${MSK_CLUSTER_ARN}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:AlterGroup",
        "kafka-cluster:DescribeGroup"
      ],
      "Resource": "${MSK_CLUSTER_ARN}/*"
    }
  ]
}
EOF
)

POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
    aws iam list-policies \
    --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" \
    --output text)

echo -e "${GREEN}✓ Policy ARN: $POLICY_ARN${NC}"
echo ""

# Create IAM role for each namespace
for NAMESPACE in "${NAMESPACES[@]}"; do
    ROLE_NAME="msk-kafka-role-$NAMESPACE"
    SA_NAME="kafka-service-account"
    
    echo -e "${BLUE}Creating IAM role for namespace: $NAMESPACE${NC}"
    
    # Trust policy
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${SA_NAME}",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
)
    
    # Create role
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --query 'Role.Arn' \
        --output text 2>/dev/null || \
        aws iam get-role \
        --role-name "$ROLE_NAME" \
        --query 'Role.Arn' \
        --output text)
    
    # Attach policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN" 2>/dev/null || true
    
    echo -e "  Role: $ROLE_ARN"
    
    # Create/Update Kubernetes ServiceAccount
    kubectl create serviceaccount "$SA_NAME" \
        --namespace "$NAMESPACE" \
        --dry-run=client -o yaml | \
        kubectl annotate -f - \
        eks.amazonaws.com/role-arn="$ROLE_ARN" \
        --local --dry-run=client -o yaml | \
        kubectl apply -f -
    
    echo -e "${GREEN}  ✓ ServiceAccount created/updated: $SA_NAME${NC}"
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}IRSA Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "IAM Policy: $POLICY_ARN"
echo ""
echo "IAM Roles created for namespaces:"
for NAMESPACE in "${NAMESPACES[@]}"; do
    echo "  - $NAMESPACE: msk-kafka-role-$NAMESPACE"
done
echo ""
echo "Service accounts annotated with IAM roles."
echo "Pods using these service accounts will have MSK access."
echo ""

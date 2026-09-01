#!/bin/bash

################################################################################
# MSK-EKS Integration Configuration Script
# This script configures the MSK cluster to work with meracommerce-dev-cluster
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
EKS_CLUSTER_NAME="meracommerce-dev-cluster"
MSK_CLUSTER_NAME="msk-cluster-dev"
TERRAFORM_DIR="../terraform/environments/dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MSK-EKS Integration Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Step 1: Get EKS Cluster Information
echo -e "${BLUE}Step 1: Retrieving EKS Cluster Information${NC}"
echo ""

if ! aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1; then
    print_status 1 "EKS cluster '$EKS_CLUSTER_NAME' not found in region $REGION"
    echo ""
    echo "Please ensure:"
    echo "  1. The cluster name is correct"
    echo "  2. You have access to the cluster"
    echo "  3. AWS credentials are configured"
    exit 1
fi

print_status 0 "EKS cluster found: $EKS_CLUSTER_NAME"

# Get EKS cluster details
EKS_VPC_ID=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' \
    --output text)

EKS_CLUSTER_SG=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
    --output text)

EKS_ADDITIONAL_SGS=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.securityGroupIds[]' \
    --output text)

EKS_SUBNETS=$(aws eks describe-cluster \
    --name "$EKS_CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.subnetIds[]' \
    --output text)

echo ""
print_info "EKS VPC ID: $EKS_VPC_ID"
print_info "EKS Cluster Security Group: $EKS_CLUSTER_SG"
if [ -n "$EKS_ADDITIONAL_SGS" ]; then
    print_info "Additional Security Groups: $EKS_ADDITIONAL_SGS"
fi

# Step 2: Get MSK Cluster Information
echo ""
echo -e "${BLUE}Step 2: Retrieving MSK Cluster Information${NC}"
echo ""

MSK_CLUSTER_ARN=$(aws kafka list-clusters \
    --region "$REGION" \
    --query "ClusterInfoList[?ClusterName=='$MSK_CLUSTER_NAME'].ClusterArn" \
    --output text)

if [ -z "$MSK_CLUSTER_ARN" ]; then
    print_warning "MSK cluster '$MSK_CLUSTER_NAME' not found yet"
    print_info "This is expected if you haven't deployed the infrastructure yet"
    print_info "Run this script again after: terraform apply"
    echo ""
    echo -e "${BLUE}Configuration to update in terraform.tfvars:${NC}"
    echo ""
    echo "eks_cluster_security_group_id = \"$EKS_CLUSTER_SG\""
    echo ""
    exit 0
fi

print_status 0 "MSK cluster found: $MSK_CLUSTER_NAME"

# Get MSK cluster details
MSK_VPC_ID=$(aws kafka describe-cluster \
    --cluster-arn "$MSK_CLUSTER_ARN" \
    --region "$REGION" \
    --query 'ClusterInfo.BrokerNodeGroupInfo.ClientSubnets[0]' \
    --output text | xargs -I {} aws ec2 describe-subnets \
    --subnet-ids {} \
    --query 'Subnets[0].VpcId' \
    --output text)

MSK_SECURITY_GROUPS=$(aws kafka describe-cluster \
    --cluster-arn "$MSK_CLUSTER_ARN" \
    --region "$REGION" \
    --query 'ClusterInfo.BrokerNodeGroupInfo.SecurityGroups[]' \
    --output text)

echo ""
print_info "MSK VPC ID: $MSK_VPC_ID"
print_info "MSK Security Groups: $MSK_SECURITY_GROUPS"

# Step 3: Verify VPC Compatibility
echo ""
echo -e "${BLUE}Step 3: Verifying VPC Configuration${NC}"
echo ""

if [ "$EKS_VPC_ID" != "$MSK_VPC_ID" ]; then
    print_status 1 "VPC mismatch: EKS ($EKS_VPC_ID) != MSK ($MSK_VPC_ID)"
    echo ""
    print_warning "EKS and MSK are in different VPCs"
    echo ""
    echo "Options:"
    echo "  1. Deploy MSK in the same VPC as EKS (Recommended)"
    echo "  2. Set up VPC Peering between the two VPCs"
    echo "  3. Use VPN or Transit Gateway"
    echo ""
    echo "To deploy MSK in EKS VPC, update terraform.tfvars:"
    echo "  - Use existing VPC: $EKS_VPC_ID"
    echo "  - Use existing subnets from EKS"
    exit 1
else
    print_status 0 "VPCs match: Both using $EKS_VPC_ID"
fi

# Step 4: Configure Security Group Rules
echo ""
echo -e "${BLUE}Step 4: Configuring Security Group Rules${NC}"
echo ""

for MSK_SG in $MSK_SECURITY_GROUPS; do
    print_info "Configuring MSK Security Group: $MSK_SG"
    
    # Allow traffic from EKS cluster security group
    echo "  Adding ingress rule for Kafka (port 9098) from EKS cluster SG..."
    
    aws ec2 authorize-security-group-ingress \
        --group-id "$MSK_SG" \
        --protocol tcp \
        --port 9098 \
        --source-group "$EKS_CLUSTER_SG" \
        --region "$REGION" \
        --description "Allow Kafka SASL/IAM from EKS cluster" 2>/dev/null || \
        print_warning "  Rule may already exist"
    
    # Add rules for additional EKS security groups if any
    for EKS_SG in $EKS_ADDITIONAL_SGS; do
        if [ "$EKS_SG" != "$EKS_CLUSTER_SG" ]; then
            aws ec2 authorize-security-group-ingress \
                --group-id "$MSK_SG" \
                --protocol tcp \
                --port 9098 \
                --source-group "$EKS_SG" \
                --region "$REGION" \
                --description "Allow Kafka SASL/IAM from EKS nodes" 2>/dev/null || \
                print_warning "  Rule may already exist"
        fi
    done
    
    # Also add TLS port for compatibility
    aws ec2 authorize-security-group-ingress \
        --group-id "$MSK_SG" \
        --protocol tcp \
        --port 9094 \
        --source-group "$EKS_CLUSTER_SG" \
        --region "$REGION" \
        --description "Allow Kafka TLS from EKS cluster" 2>/dev/null || \
        print_warning "  TLS rule may already exist"
done

print_status 0 "Security group rules configured"

# Step 5: Get Bootstrap Servers
echo ""
echo -e "${BLUE}Step 5: Retrieving Kafka Bootstrap Servers${NC}"
echo ""

BOOTSTRAP_SERVERS=$(aws kafka get-bootstrap-brokers \
    --cluster-arn "$MSK_CLUSTER_ARN" \
    --region "$REGION" \
    --query 'BootstrapBrokerStringSaslIam' \
    --output text)

print_status 0 "Bootstrap servers retrieved"
echo ""
print_info "Bootstrap Servers:"
echo "  $BOOTSTRAP_SERVERS"

# Step 6: Update Kubernetes ConfigMaps
echo ""
echo -e "${BLUE}Step 6: Updating Kubernetes ConfigMaps${NC}"
echo ""

# Check if kubectl is configured for the cluster
if kubectl config get-contexts | grep -q "$EKS_CLUSTER_NAME"; then
    print_status 0 "kubectl configured for $EKS_CLUSTER_NAME"
    
    # Update kubeconfig if needed
    aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1
    
    # Get current namespaces
    NAMESPACES=$(kubectl get namespaces -o name | grep -E "(customer|order|catalog|notification|payment)" | cut -d'/' -f2)
    
    if [ -z "$NAMESPACES" ]; then
        print_warning "No service namespaces found"
        print_info "Expected namespaces: customer-service-ns, order-service-ns, etc."
    else
        print_status 0 "Found namespaces: $(echo $NAMESPACES | tr '\n' ' ')"
        
        # Create/Update ConfigMaps for each namespace
        for NS in $NAMESPACES; do
            echo ""
            print_info "Creating ConfigMap in namespace: $NS"
            
            kubectl create configmap kafka-config \
                --from-literal=KAFKA_BOOTSTRAP_SERVERS="$BOOTSTRAP_SERVERS" \
                --from-literal=KAFKA_SECURITY_PROTOCOL="SASL_SSL" \
                --from-literal=KAFKA_SASL_MECHANISM="AWS_MSK_IAM" \
                --from-literal=KAFKA_SASL_JAAS_CONFIG="software.amazon.msk.auth.iam.IAMLoginModule required;" \
                --from-literal=KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS="software.amazon.msk.auth.iam.IAMClientCallbackHandler" \
                --namespace="$NS" \
                --dry-run=client -o yaml | kubectl apply -f -
            
            print_status 0 "ConfigMap created/updated in $NS"
        done
    fi
else
    print_warning "kubectl not configured for $EKS_CLUSTER_NAME"
    print_info "Configure kubectl with: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $REGION"
fi

# Step 7: Output Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Integration Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✓ MSK-EKS Integration Configured${NC}"
echo ""
echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo "MSK Cluster: $MSK_CLUSTER_NAME"
echo "VPC: $EKS_VPC_ID"
echo ""
echo "Bootstrap Servers:"
echo "  $BOOTSTRAP_SERVERS"
echo ""
echo "Security Groups Configured:"
for MSK_SG in $MSK_SECURITY_GROUPS; do
    echo "  MSK SG: $MSK_SG (allows traffic from EKS SG: $EKS_CLUSTER_SG)"
done
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Configure IAM roles for service accounts (IRSA)"
echo "  2. Deploy your microservices with Kafka integration"
echo "  3. Test connectivity from pods"
echo ""
echo "To test from a pod:"
echo "  kubectl run kafka-test --image=confluentinc/cp-kafka:latest -n <namespace> --rm -it --restart=Never -- bash"
echo ""

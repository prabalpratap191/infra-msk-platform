key_name = "kafka-ec2-key"

admin_ip_address = "YOUR_PUBLIC_IP/32"

kafka_cluster_name = "kafka-cluster-dev"
admin_ip_address = "54.91.126.56"

# AWS Configuration
aws_region  = "us-east-1"
environment = "dev"

# EC2 Instance Configuration
instance_type = "t3.medium"
volume_size   = 40

# Network Configuration
# TODO: Replace with your actual VPC ID from AWS Console
#vpc_id = "vpc-04c700d412f86947c "

# TODO: Replace with your actual Subnet ID from AWS Console
#subnet_id = "subnet-02ce84284a49d7dbf"

# TODO: Replace with your VPC CIDR block (e.g., 10.0.0.0/16)
#private_vpc_cidr = "172.31.0.0/16"

# Security Configuration
# TODO: Replace with your public IP (get via: curl https://checkip.amazonaws.com)
#admin_ip_address = "54.91.126.56"

# Optional: EKS Worker Security Group ID (leave empty "" if not using EKS)
#eks_worker_security_group_id = ""

# Kafka Configuration
kafka_cluster_name = "kafka-cluster-dev"
kafka_broker_id    = 1


key_name = "kafka-ec2-key"
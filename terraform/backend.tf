# Terraform Backend Configuration for State Management
# Note: S3 bucket and DynamoDB table must be created before running terraform init

terraform {
  backend "s3" {
    bucket         = "terraform-state-msk-platform-dev" # Update with your bucket name
    key            = "msk/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-msk-platform" # Update with your table name
    
    # Uncomment for versioning
    # versioning = true
  }
}

# To create backend resources, use the following AWS CLI commands:
# 
# aws s3api create-bucket --bucket terraform-state-msk-platform-dev --region us-east-1
# aws s3api put-bucket-versioning --bucket terraform-state-msk-platform-dev --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption --bucket terraform-state-msk-platform-dev --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
# 
# aws dynamodb create-table \
#   --table-name terraform-state-lock-msk-platform \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1

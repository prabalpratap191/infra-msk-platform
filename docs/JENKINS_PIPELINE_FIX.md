# Jenkins Pipeline Failure Fix - Terraform Variables

## Issue Summary

**Build**: #5  
**Status**: FAILURE  
**Stage**: Terraform Plan  
**Date**: 2026-09-02

### Error Description

The Jenkins pipeline failed during the `Terraform Plan` stage with the following errors:

```
Error: No value for required variable
```

Terraform attempted to prompt for 27 required variables interactively, which failed in the non-interactive Jenkins environment with EOF (End of File) errors.

## Root Cause

The repository contained only `terraform.tfvars.example` but was missing the actual `terraform.tfvars` file in the `terraform/environments/dev/` directory. When Terraform runs `terraform plan`, it looks for variable values in the following order:

1. Environment variables (TF_VAR_name)
2. `terraform.tfvars` or `terraform.tfvars.json` files
3. `*.auto.tfvars` or `*.auto.tfvars.json` files
4. `-var` and `-var-file` command line flags
5. Interactive prompts (doesn't work in CI/CD)

Since none of these sources provided the required variables, Terraform attempted interactive prompting, which failed in Jenkins.

## Solution Implemented

### Solution 1: Created `terraform.tfvars` File ✅

Created `terraform/environments/dev/terraform.tfvars` with values from `terraform.tfvars.example`.

**Location**: `terraform/environments/dev/terraform.tfvars`

**Security Note**: This file is already excluded from version control via `.gitignore` pattern `*.tfvars`.

### Variables Configured

All 27 required variables are now configured:

#### Global Settings
- `project_name`: "meracommerce"
- `environment`: "dev"
- `aws_region`: "us-east-1"

#### Networking (7 variables)
- `vpc_cidr`: "10.0.0.0/16"
- `public_subnet_cidrs`: ["10.0.1.0/24", "10.0.2.0/24"]
- `private_subnet_cidrs`: ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
- `availability_zones`: ["us-east-1a", "us-east-1b", "us-east-1c"]
- `enable_nat_gateway`: true
- `single_nat_gateway`: true

#### Kafka Configuration (8 variables)
- `kafka_instance_type`: "t3.medium"
- `kafka_instance_count`: 3
- `kafka_volume_size`: 100
- `kafka_volume_type`: "gp3"
- `kafka_version`: "3.6.1"
- `kafka_private_ips`: ["10.0.101.10", "10.0.102.10", "10.0.103.10"]
- `kafka_public_dns`: "kafka-public.meracommerce.dev"
- `kafka_heap_opts`: "-Xms2G -Xmx2G"

#### Kafka Topics (1 complex variable)
- `kafka_topics`: 7 topics configured (customer-events, order-events, catalog-events, payment-events, notification-events, dead-letter-events, audit-events)

#### Security (4 variables)
- `admin_cidr_blocks`: ["0.0.0.0/0"] ⚠️ **CHANGE IN PRODUCTION**
- `enable_public_access`: false
- `eks_cluster_name`: "meracommerce-dev-cluster"
- `ssh_key_name`: "kafka-key"

#### Route53 (2 variables)
- `create_route53_zone`: true
- `route53_zone_name`: "internal"

#### Monitoring (3 variables)
- `enable_cloudwatch_monitoring`: true
- `enable_prometheus`: true
- `cloudwatch_retention_days`: 7

## Alternative Solutions (For Production/Multi-Environment)

While creating `terraform.tfvars` fixes the immediate issue, consider these alternatives for production:

### Option 2: Use `-var-file` Flag (Recommended for Production)

Modify the Jenkinsfile to use environment-specific variable files:

```groovy
stage('Terraform Plan') {
    steps {
        dir("${TERRAFORM_DIR}") {
            script {
                echo "Creating Terraform plan..."
                sh "terraform plan -var-file=\"${params.ENVIRONMENT}.tfvars\" -out=tfplan"
            }
        }
    }
}
```

Then create separate files:
- `dev.tfvars`
- `staging.tfvars`
- `prod.tfvars`

### Option 3: Use Jenkins Credentials for Sensitive Variables

For sensitive values, use Jenkins credentials:

```groovy
environment {
    TF_VAR_ssh_key_name = credentials('kafka-ssh-key-name')
    TF_VAR_admin_cidr_blocks = credentials('kafka-admin-cidr')
}
```

### Option 4: Use Terraform Cloud/Enterprise Workspaces

Manage variables centrally in Terraform Cloud with workspace-specific configurations.

## Verification Steps

### Local Verification

```bash
# Navigate to environment directory
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Create plan (should work now)
terraform plan
```

### Jenkins Re-run

1. Commit the `terraform.tfvars` file (if not gitignored) OR ensure it's created in Jenkins workspace
2. Trigger a new build
3. The pipeline should now pass the "Terraform Plan" stage

## Security Considerations

### ⚠️ Important Security Notes

1. **Never commit `terraform.tfvars` to version control** if it contains sensitive data
   - Current `.gitignore` already excludes `*.tfvars`
   - Only `terraform.tfvars.example` should be committed

2. **Update production values**:
   - `admin_cidr_blocks`: Currently set to `["0.0.0.0/0"]` - **MUST be restricted in production**
   - `ssh_key_name`: Ensure the SSH key exists in AWS before deployment

3. **For production environments**:
   - Use Jenkins credentials or AWS Secrets Manager
   - Restrict network access with proper CIDR blocks
   - Enable encryption for sensitive data
   - Use separate AWS accounts for dev/staging/prod

## Pre-Deployment Checklist

Before running the pipeline, ensure:

- [ ] SSH key pair `kafka-key` exists in AWS us-east-1 region
- [ ] AWS credentials are configured in Jenkins
- [ ] S3 backend bucket for Terraform state exists (if using remote state)
- [ ] Required AWS permissions are granted to the Jenkins IAM role/user
- [ ] VPC CIDR `10.0.0.0/16` doesn't conflict with existing networks
- [ ] EC2 instance type `t3.medium` is available in target region
- [ ] Review and update `admin_cidr_blocks` for security

## Expected Pipeline Flow After Fix

```
✅ Checkout          → Pull code from git
✅ Setup             → Install/verify Terraform
✅ Terraform Init    → Initialize providers and modules
✅ Terraform Validate → Validate configuration
✅ Terraform Plan    → Create execution plan (PREVIOUSLY FAILED, NOW FIXED)
⏸️  Approval Gate    → Manual approval (if AUTO_APPROVE=false)
⏳ Terraform Apply   → Create infrastructure
⏳ Wait for Init     → Wait for EC2/Docker/Kafka setup (5 minutes)
⏳ Kafka Validation  → Verify deployment
✅ Publish Outputs   → Display connection details
```

## Next Steps

1. **Immediate**: Test the fix by triggering a new Jenkins build
2. **Short-term**: Review and customize variable values for your specific requirements
3. **Medium-term**: Implement Jenkins credentials for sensitive variables
4. **Long-term**: Set up Terraform Cloud/Enterprise for centralized variable management

## Additional Resources

- [Terraform Input Variables Documentation](https://www.terraform.io/docs/language/values/variables.html)
- [Jenkins Credentials Plugin](https://plugins.jenkins.io/credentials/)
- [AWS Secrets Manager Integration](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_how-services.html)
- Project documentation: `docs/DEPLOYMENT.md`

## Contact

For questions or issues:
- Review: `docs/PRE_DEPLOYMENT_CHECKLIST.md`
- Rollback: `docs/ROLLBACK_STRATEGY.md`
- Platform Engineering Team

---

**Document Version**: 1.0  
**Last Updated**: 2026-09-02  
**Author**: DevOps Team

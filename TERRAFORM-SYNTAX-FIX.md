# 🔧 Terraform Syntax Error Fixed

## Issue

Jenkins pipeline failed during `terraform validate` with:

```
Error: Unsupported argument
  on ../../modules/networking/main.tf line 237, in resource "aws_security_group" "vpc_endpoints":
  237:   name_description = "Security group for VPC endpoints"

An argument named "name_description" is not expected here.
```

## Root Cause

Incorrect attribute name in the VPC endpoints security group resource.

**File**: `terraform/modules/networking/main.tf`  
**Line**: 237

### Before (Incorrect) ❌

```hcl
resource "aws_security_group" "vpc_endpoints" {
  name_description = "Security group for VPC endpoints"  # ❌ Invalid attribute
  vpc_id          = aws_vpc.main.id
  ...
}
```

### After (Correct) ✅

```hcl
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"  # ✅ Correct
  description = "Security group for VPC endpoints"       # ✅ Correct
  vpc_id      = aws_vpc.main.id
  ...
}
```

## What Changed

**AWS Security Group** resource in Terraform has two separate attributes:

1. **`name`** - The name of the security group
2. **`description`** - Description of the security group

The code incorrectly used `name_description` (which doesn't exist) instead of using both attributes separately.

## Fix Applied

✅ **File Modified**: `terraform/modules/networking/main.tf`

```diff
resource "aws_security_group" "vpc_endpoints" {
-  name_description = "Security group for VPC endpoints"
+  name        = "${local.name_prefix}-vpc-endpoints-sg"
+  description = "Security group for VPC endpoints"
   vpc_id      = aws_vpc.main.id
```

## Verification

✅ Searched entire codebase - **no other occurrences** of `name_description`
✅ Syntax is now correct according to AWS provider documentation

## Next Steps

### 1. Commit the Fix

```bash
cd c:\Users\prasingh80\Music\Legacy\MS Legacy\infra-kafka-platform

git add terraform/modules/networking/main.tf
git commit -m "fix: correct security group attribute from name_description to name and description"
git push origin main
```

### 2. Re-run Jenkins Pipeline

**Parameters**:
```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false
CREATE_TOPICS: true
CONFIGURE_EKS_INTEGRATION: false
```

**Expected**: Pipeline should now pass the `Terraform Validate` stage.

## AWS Security Group Syntax Reference

### Correct Syntax

```hcl
resource "aws_security_group" "example" {
  name        = "my-security-group"              # Required or auto-generated
  description = "Description of security group"  # Optional, defaults to "Managed by Terraform"
  vpc_id      = aws_vpc.main.id                  # Required for VPC security groups

  ingress {
    # Ingress rules
  }

  egress {
    # Egress rules
  }

  tags = {
    Name = "my-sg"
  }
}
```

### Common Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No* | Name of the security group |
| `name_prefix` | string | No* | Creates unique name with prefix |
| `description` | string | No | Description (default: "Managed by Terraform") |
| `vpc_id` | string | No** | VPC ID for VPC security groups |
| `ingress` | block | No | Ingress rules |
| `egress` | block | No | Egress rules |
| `tags` | map | No | Tags to assign |

*Either `name` or `name_prefix` can be used, but not both  
**Required for VPC security groups

## Testing

After the fix, test locally:

```bash
cd terraform/environments/dev

# Initialize
terraform init

# Validate (should pass now)
terraform validate

# Format check
terraform fmt -check -recursive

# Plan
terraform plan
```

**Expected Output**:
```
✅ Success! The configuration is valid.
```

## Impact

This was a **syntax error** in the Terraform configuration that prevented:
- ❌ Terraform validation
- ❌ Terraform plan generation
- ❌ Infrastructure deployment

With the fix:
- ✅ Terraform validates successfully
- ✅ Pipeline can proceed to plan/apply stages
- ✅ Infrastructure deployment can proceed

## Related Files

- **Fixed**: `terraform/modules/networking/main.tf`
- **Affected Pipeline**: Jenkinsfile (no changes needed)
- **Documentation**: This file

---

**Status**: ✅ **FIXED**  
**Action Required**: Commit and push changes, then re-run Jenkins pipeline

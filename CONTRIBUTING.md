# Contributing to Kafka Infrastructure Platform

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

---

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Prioritize security and best practices

---

## How to Contribute

### Reporting Bugs

**Before submitting:**
1. Check existing issues
2. Verify it's reproducible
3. Test on latest version

**Bug report should include:**
- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Logs and error messages

### Suggesting Enhancements

**Enhancement requests should include:**
- Use case description
- Proposed solution
- Alternative approaches considered
- Impact assessment

---

## Development Workflow

### 1. Fork and Clone

```bash
git clone https://github.com/your-username/infra-kafka-platform.git
cd infra-kafka-platform
git remote add upstream https://github.com/original-org/infra-kafka-platform.git
```

### 2. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

**Branch naming conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/modifications

### 3. Make Changes

**Follow these guidelines:**
- Write clean, readable code
- Follow existing code style
- Add comments for complex logic
- Update documentation
- Add tests if applicable

### 4. Test Your Changes

```bash
# Terraform validation
cd terraform/environments/dev
terraform init
terraform validate
terraform fmt -check -recursive

# Test deployment (optional, in staging)
terraform plan
```

### 5. Commit Changes

**Commit message format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Tests
- `chore`: Maintenance

**Example:**
```
feat(kafka-ec2): add support for m5 instance types

Added configuration options for m5.large and m5.xlarge
instance types to support higher throughput requirements.

Closes #123
```

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create PR on GitHub with:
- Clear title
- Detailed description
- Link to related issues
- Screenshots/logs if applicable

---

## Pull Request Guidelines

### PR Checklist

- [ ] Code follows project style
- [ ] Documentation updated
- [ ] Tests pass
- [ ] Terraform validates
- [ ] No sensitive data committed
- [ ] Commits are meaningful
- [ ] PR description is clear

### Review Process

1. **Automated checks** must pass
2. **Peer review** by team member
3. **Security review** for infrastructure changes
4. **Approval** by maintainer
5. **Merge** after approval

---

## Coding Standards

### Terraform

```hcl
# Good
resource "aws_instance" "kafka" {
  count         = var.kafka_instance_count
  instance_type = var.kafka_instance_type
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-kafka-${count.index}"
    }
  )
}

# Use meaningful variable names
variable "kafka_instance_type" {
  description = "EC2 instance type for Kafka brokers"
  type        = string
  default     = "t3.medium"
}
```

### Shell Scripts

```bash
#!/bin/bash
set -e  # Exit on error

# Use functions
log() {
    echo "[$(date)] $1"
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    log "ERROR: Docker not found"
    exit 1
fi
```

### Documentation

- Use clear, concise language
- Include code examples
- Add troubleshooting sections
- Keep README updated

---

## Security Guidelines

### Do NOT commit:

- AWS credentials
- Private keys
- Passwords or tokens
- Sensitive configuration

### Use:

- AWS Secrets Manager
- Environment variables
- `.gitignore` for sensitive files
- Parameter Store for configs

### Security checklist:

- [ ] No hardcoded credentials
- [ ] Security groups follow least privilege
- [ ] Encryption enabled
- [ ] Secrets properly managed
- [ ] IAM roles with minimal permissions

---

## Testing

### Infrastructure Tests

```bash
# Validate Terraform
terraform validate

# Check formatting
terraform fmt -check -recursive

# Test plan
terraform plan

# Validate in staging
terraform apply -target=module.networking
```

### Integration Tests

```bash
# Deploy to staging
cd terraform/environments/staging
terraform apply -auto-approve

# Run validation
ssh ec2-user@<broker-ip> 'bash /opt/kafka/validate-kafka.sh'

# Cleanup
terraform destroy -auto-approve
```

---

## Documentation

### Required Documentation

**For new features:**
- README update
- Usage examples
- Configuration options
- Troubleshooting guide

**For bug fixes:**
- What was broken
- How it's fixed
- How to verify

### Documentation Style

- Use Markdown
- Include code blocks with syntax highlighting
- Add diagrams where helpful
- Provide real examples

---

## Release Process

### Version Numbering

Follow Semantic Versioning (semver):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

Example: `1.2.3`

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] Version bumped
- [ ] Tag created
- [ ] Release notes written

---

## Getting Help

### Resources

- **Documentation**: [docs/](docs/)
- **Quick Start**: [QUICK_START.md](QUICK_START.md)
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

### Contact

- **Email**: devops@meracommerce.com
- **Slack**: #kafka-infrastructure
- **Team**: @devops-team

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🚀

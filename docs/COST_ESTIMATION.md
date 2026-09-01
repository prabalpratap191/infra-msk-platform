# Kafka Infrastructure Cost Estimation

## Overview

This document provides detailed cost estimates for running the Kafka infrastructure on AWS.

**Region:** us-east-1  
**Environment:** Dev  
**Billing Period:** Monthly

---

## Cost Breakdown

### 1. Compute (EC2 Instances)

| Component | Specification | Quantity | Unit Cost | Monthly Cost |
|-----------|--------------|----------|-----------|-------------|
| Kafka Brokers | t3.medium | 3 | $30.37 | **$91.11** |
| Reserved Instance (1yr) | t3.medium | 3 | $19.71 | **$59.13** |
| Reserved Instance (3yr) | t3.medium | 3 | $13.14 | **$39.42** |

**Recommendation:** Use Reserved Instances for production to save 35-55%

---

### 2. Storage (EBS Volumes)

| Component | Type | Size | Quantity | Unit Cost | Monthly Cost |
|-----------|------|------|----------|-----------|-------------|
| Kafka Data | gp3 | 100 GB | 3 | $8.00 | **$24.00** |
| IOPS (3000) | gp3 | Included | 3 | $0.00 | **$0.00** |
| Throughput | gp3 (125 MB/s) | Included | 3 | $0.00 | **$0.00** |

**Note:** gp3 provides better price/performance than gp2

---

### 3. Networking

| Component | Specification | Quantity | Unit Cost | Monthly Cost |
|-----------|--------------|----------|-----------|-------------|
| NAT Gateway | - | 1 | $32.85 | **$32.85** |
| NAT Gateway Data | Per GB | ~500 GB | $0.045/GB | **$22.50** |
| Elastic IPs | Associated | 1 | $0.00 | **$0.00** |
| Data Transfer Out | To Internet | ~100 GB | $0.09/GB | **$9.00** |
| Data Transfer EKS | VPC Peering | ~400 GB | $0.01/GB | **$4.00** |

**Note:** NAT Gateway is the highest networking cost

---

### 4. Route53

| Component | Specification | Quantity | Unit Cost | Monthly Cost |
|-----------|--------------|----------|-----------|-------------|
| Hosted Zone | Private | 1 | $0.50 | **$0.50** |
| DNS Queries | First 1B | ~10M | $0.00 | **$0.00** |

---

### 5. CloudWatch

| Component | Specification | Quantity | Unit Cost | Monthly Cost |
|-----------|--------------|----------|-----------|-------------|
| Logs Ingestion | Per GB | ~50 GB | $0.50/GB | **$25.00** |
| Logs Storage | Per GB | ~50 GB | $0.03/GB | **$1.50** |
| Metrics | Custom | ~100 | $0.30 each | **$30.00** |
| Alarms | Standard | 12 | $0.10 each | **$1.20** |
| Dashboard | Custom | 1 | $3.00 | **$3.00** |

**Optimization:** Reduce log retention to 3 days: saves ~$12/month

---

### 6. Backups (Optional)

| Component | Specification | Quantity | Unit Cost | Monthly Cost |
|-----------|--------------|----------|-----------|-------------|
| S3 Standard | Kafka Backups | ~100 GB | $0.023/GB | **$2.30** |
| S3 Lifecycle | Glacier (30d) | ~200 GB | $0.004/GB | **$0.80** |

---

## Total Monthly Cost Summary

### Standard On-Demand Configuration

```
EC2 Instances (On-Demand):      $91.11
EBS Storage:                     $24.00
NAT Gateway:                     $32.85
NAT Gateway Data:                $22.50
Data Transfer:                   $13.00
Route53:                         $0.50
CloudWatch Logs:                 $26.50
CloudWatch Metrics & Alarms:     $34.20
S3 Backups (optional):           $3.10
----------------------------------------
TOTAL:                          $247.76/month
```

### Optimized Configuration (Reserved Instances + Cost Savings)

```
EC2 Instances (1yr RI):         $59.13  (save $32)
EBS Storage:                     $24.00
NAT Gateway:                     $32.85
NAT Gateway Data:                $22.50
Data Transfer:                   $13.00
Route53:                         $0.50
CloudWatch Logs (3d retention):  $14.00  (save $12.50)
CloudWatch Metrics & Alarms:     $20.00  (reduced metrics)
S3 Backups (optional):           $3.10
----------------------------------------
TOTAL:                          $189.08/month

Savings: $58.68/month (24%)
```

---

## Cost Optimization Strategies

### 1. **Use Reserved Instances**
- **1-year RI:** Save ~35% ($32/month)
- **3-year RI:** Save ~55% ($52/month)

### 2. **Optimize NAT Gateway**
```
Option A: Single NAT Gateway (current)     $32.85
Option B: NAT Instance (t3.small)          $15.18  (save $17.67)
Option C: VPC Endpoints                     $7.30  (save $25.55)
```

**Recommendation:** Use VPC Endpoints for S3 and DynamoDB

### 3. **Reduce CloudWatch Costs**
- Reduce log retention: 7d → 3d (save $12.50/month)
- Use metric filters instead of all metrics
- Consolidate dashboards

### 4. **Storage Optimization**
```
Current: gp3 100GB x 3 = $24/month
Optimized: Implement log compaction and retention policies
Reduced: gp3 50GB x 3 = $12/month (save $12)
```

### 5. **Right-sizing Instances**
```
Dev Environment:
  Current: t3.medium x 3 = $91.11
  Alternative: t3.small x 3 = $45.55 (save $45.56)
  
Note: Only for dev/test. Production should use t3.medium or larger.
```

---

## Scaling Cost Projections

### Small Scale (Dev)
- **Brokers:** 3 x t3.medium
- **Storage:** 100 GB each
- **Cost:** $189/month (optimized)

### Medium Scale (Staging)
- **Brokers:** 3 x t3.large
- **Storage:** 250 GB each
- **Cost:** ~$340/month

### Large Scale (Production)
- **Brokers:** 3 x m5.xlarge
- **Storage:** 500 GB each
- **High Availability:** Multi-AZ NAT
- **Cost:** ~$850/month

---

## Annual Cost Comparison

| Configuration | Monthly | Annual | Annual (RI) |
|--------------|---------|--------|-------------|
| Dev (On-Demand) | $248 | $2,976 | $2,269 |
| Staging (On-Demand) | $340 | $4,080 | $3,120 |
| Production (On-Demand) | $850 | $10,200 | $7,650 |

**3-Year Production Cost:** $22,950 (RI) vs $30,600 (On-Demand)  
**Savings:** $7,650 (25%)

---

## Cost Monitoring

### Set Up AWS Budgets

```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://kafka-budget.json
```

### Cost Allocation Tags

```hcl
tags = {
  Project     = "meracommerce"
  Environment = "dev"
  CostCenter  = "Engineering"
  Component   = "Kafka"
}
```

### CloudWatch Cost Alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name kafka-cost-alert \
  --alarm-description "Alert if Kafka costs exceed budget" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold
```

---

## ROI Analysis

### Managed Kafka (MSK) vs Self-Managed (This Solution)

| Feature | AWS MSK | Self-Managed |
|---------|---------|-------------|
| **3 Brokers** | $486/month | $189/month |
| **Management** | Fully managed | Manual |
| **Customization** | Limited | Full control |
| **Monitoring** | Included | Self-setup |
| **Annual Cost** | $5,832 | $2,268 |
| **Savings** | - | **$3,564/year** |

**Recommendation:** Self-managed provides 61% cost savings with full control

---

## Conclusion

**Baseline Cost:** $248/month  
**Optimized Cost:** $189/month  
**Annual Cost:** $2,268 (optimized with RI)

**Key Savings:**
1. Reserved Instances: $384/year
2. VPC Endpoints: $307/year
3. Log Optimization: $150/year
4. **Total Savings:** $841/year (27%)

---

## Questions?

Contact: devops@meracommerce.com

# MSK Platform Cost Estimation

This document provides a detailed cost breakdown and optimization strategies for the MSK platform infrastructure.

## Table of Contents

- [Cost Summary](#cost-summary)
- [Detailed Breakdown](#detailed-breakdown)
- [Cost Optimization](#cost-optimization)
- [Monitoring Costs](#monitoring-costs)
- [Cost Comparison](#cost-comparison)

## Cost Summary

### Dev Environment (Current Configuration)

| Component | Monthly Cost (USD) | Annual Cost (USD) |
|-----------|-------------------|------------------|
| MSK Cluster (3 x kafka.t3.small) | $140.16 | $1,681.92 |
| EBS Storage (300 GB total) | $30.00 | $360.00 |
| Data Transfer (estimated) | $10.00 | $120.00 |
| CloudWatch Logs | $5.00 | $60.00 |
| CloudWatch Metrics | $3.00 | $36.00 |
| KMS (encryption keys) | $1.00 | $12.00 |
| NAT Gateway (single) | $32.40 | $388.80 |
| VPC Endpoints | $7.20 | $86.40 |
| **Total** | **~$228.76** | **~$2,745.12** |

### Production Environment (Projected)

| Component | Monthly Cost (USD) | Annual Cost (USD) |
|-----------|-------------------|------------------|
| MSK Cluster (3 x kafka.m5.large) | $453.60 | $5,443.20 |
| EBS Storage (1 TB total) | $100.00 | $1,200.00 |
| Data Transfer | $50.00 | $600.00 |
| CloudWatch Logs | $20.00 | $240.00 |
| CloudWatch Metrics | $10.00 | $120.00 |
| KMS | $1.00 | $12.00 |
| NAT Gateway (3 AZs) | $97.20 | $1,166.40 |
| VPC Endpoints | $21.60 | $259.20 |
| **Total** | **~$753.40** | **~$9,040.80** |

## Detailed Breakdown

### 1. MSK Cluster Costs

#### Instance Pricing (us-east-1)

| Instance Type | vCPU | Memory | Cost/Hour | Monthly (730h) | 3 Brokers/Month |
|--------------|------|--------|-----------|----------------|----------------|
| kafka.t3.small | 2 | 2 GB | $0.064 | $46.72 | **$140.16** |
| kafka.m5.large | 2 | 8 GB | $0.207 | $151.20 | $453.60 |
| kafka.m5.xlarge | 4 | 16 GB | $0.414 | $302.22 | $906.66 |
| kafka.m5.2xlarge | 8 | 32 GB | $0.828 | $604.44 | $1,813.32 |

**Current Configuration**: 3 x kafka.t3.small = **$140.16/month**

#### Storage Costs

- **GP2 (General Purpose SSD)**: $0.10 per GB-month
- **Current**: 100 GB per broker x 3 = 300 GB
- **Cost**: 300 GB x $0.10 = **$30.00/month**

#### Storage Autoscaling

- Initial: 100 GB per broker
- Max: 500 GB per broker
- Scaling triggers at 70% utilization
- **Projected at 50% capacity**: 250 GB x 3 x $0.10 = **$75.00/month**

### 2. Data Transfer Costs

| Transfer Type | Cost | Estimated Monthly |
|---------------|------|------------------|
| Inbound (to MSK) | Free | $0.00 |
| Inter-AZ (broker replication) | $0.01/GB | $5.00 |
| Outbound to EKS (same region) | Free | $0.00 |
| Outbound to Internet | $0.09/GB | $5.00 |
| **Total** | | **~$10.00** |

**Assumptions**:
- 500 GB intra-cluster replication
- Minimal internet egress

### 3. Monitoring and Logging

#### CloudWatch Logs

- **Ingestion**: $0.50 per GB
- **Storage**: $0.03 per GB-month
- **Retention**: 7 days
- **Estimated volume**: 10 GB/month
- **Cost**: (10 x $0.50) + (10 x $0.03) = **$5.30/month**

#### CloudWatch Metrics

- **Custom metrics**: $0.30 per metric/month
- **API requests**: $0.01 per 1,000 requests
- **Estimated metrics**: 10 custom metrics
- **Cost**: 10 x $0.30 = **$3.00/month**

#### Enhanced Monitoring

- **PER_BROKER level**: Included in MSK pricing
- **No additional cost**

### 4. Networking Costs

#### NAT Gateway

- **Hourly charge**: $0.045 per hour
- **Data processing**: $0.045 per GB
- **Monthly (single NAT)**: 730 x $0.045 = **$32.85/month**
- **Data processing (100 GB)**: 100 x $0.045 = **$4.50/month**
- **Total**: **$37.35/month**

**Cost Optimization**: Using single NAT Gateway in dev (vs 3 in prod)
- **Savings**: $74.70/month

#### VPC Endpoints

- **Interface Endpoint**: $0.01 per hour per AZ
- **Data processing**: $0.01 per GB
- **CloudWatch Logs Endpoint**: 3 AZs x 730 hours x $0.01 = **$21.90/month**
- **S3 Gateway Endpoint**: Free
- **Cost**: **$21.90/month**

### 5. Encryption Costs

#### KMS Keys

- **Key storage**: $1.00 per key per month
- **API requests**: $0.03 per 10,000 requests
- **Estimated requests**: 100,000/month
- **Cost**: $1.00 + (10 x $0.03) = **$1.30/month**

## Cost Optimization

### Current Optimizations (Dev Environment)

1. **T3 Instance Type**
   - Using t3.small instead of m5.large
   - **Savings**: ~$313/month

2. **Single NAT Gateway**
   - 1 NAT instead of 3
   - **Savings**: ~$75/month

3. **Minimal Storage**
   - 100 GB per broker (minimum for t3.small)
   - **Savings**: Baseline

4. **Short Log Retention**
   - 7 days instead of 30
   - **Savings**: ~$15/month

5. **S3 Gateway Endpoint**
   - Free vs Interface Endpoint
   - **Savings**: ~$22/month

**Total Monthly Savings**: ~$425/month (65% reduction vs prod-grade config)

### Additional Optimization Strategies

#### 1. Reserved Capacity (Production)

- **1-year commitment**: 30% discount
- **3-year commitment**: 50% discount
- **Potential savings**: $136 - $227/month (prod config)

#### 2. Right-sizing

```bash
# Monitor actual usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kafka \
  --metric-name CpuUser \
  --dimensions Name="Cluster Name",Value="msk-cluster-dev" \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

**If average CPU < 20%**: Consider smaller instance type

#### 3. Storage Optimization

- **Enable compression**: Reduce storage by 40-60%
- **Optimize retention**: 7 days vs 30 days
- **Topic cleanup**: Delete unused topics

```properties
# Kafka topic config
compression.type=snappy
retention.ms=604800000  # 7 days
cleanup.policy=delete
```

#### 4. Data Transfer Optimization

- **Use VPC Peering**: Free data transfer vs VPN
- **Collocate consumers**: Place in same AZ as brokers
- **Batch operations**: Reduce API calls

#### 5. Monitoring Optimization

- **Metric filters**: Only essential metrics
- **Log sampling**: Sample 10% of logs
- **Metric math**: Derive metrics instead of storing

### Cost Breakdown by Service

```
Total Monthly Cost: $228.76

██████████████████████████████████ 61% MSK Cluster ($140)
█████████████ 13% Storage ($30)
███████████ 14% NAT Gateway ($32)
████ 4% Data Transfer ($10)
███ 3% VPC Endpoints ($7)
██ 2% CloudWatch Logs ($5)
█ 1% CloudWatch Metrics ($3)
█ 1% KMS ($1)
```

## Monitoring Costs

### Cost Alerts

Set up CloudWatch billing alarms:

```bash
# Create billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "MSK-Monthly-Cost-Alert" \
  --alarm-description "Alert when MSK costs exceed $250/month" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 250 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=AmazonMSK
```

### Cost Tracking

```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Managed Streaming for Apache Kafka"]}}'
```

### Budget Recommendations

| Environment | Monthly Budget | Buffer | Alert Threshold |
|-------------|---------------|--------|----------------|
| Dev | $250 | 10% | $225 |
| Staging | $500 | 15% | $425 |
| Production | $1,000 | 20% | $800 |

## Cost Comparison

### MSK vs Self-Managed Kafka

| Component | Self-Managed | MSK | Difference |
|-----------|-------------|-----|------------|
| EC2 Instances (3 x m5.large) | $302/mo | - | - |
| MSK Service (3 brokers) | - | $454/mo | +$152/mo |
| Storage | $30/mo | $30/mo | $0 |
| Load Balancer | $20/mo | - | -$20/mo |
| Zookeeper (3 x t3.small) | $47/mo | Included | -$47/mo |
| Operational overhead | ~40h/mo | - | -$2,000/mo* |
| **Total** | **~$2,399/mo** | **$484/mo** | **-$1,915/mo** |

*Assuming $50/hour for DevOps engineer time

### MSK vs Other Managed Services

| Service | Monthly Cost (3 brokers) | Features |
|---------|------------------------|----------|
| AWS MSK | $454 | Full Kafka, AWS integrated |
| Confluent Cloud | $595 | Kafka + enterprise features |
| Azure Event Hubs | $450 | Kafka-compatible |
| Google Cloud Pub/Sub | $400 | Not Kafka |

## Recommendations

### For Dev/Test

1. ✅ Use kafka.t3.small instances
2. ✅ Single NAT Gateway
3. ✅ Minimal storage (100 GB)
4. ✅ Short retention (7 days)
5. ✅ Basic monitoring

**Estimated Cost**: **$229/month**

### For Staging

1. Use kafka.m5.large instances
2. Single NAT Gateway (acceptable risk)
3. Moderate storage (250 GB)
4. Standard retention (14 days)
5. Enhanced monitoring

**Estimated Cost**: **$540/month**

### For Production

1. Use kafka.m5.large or larger
2. NAT Gateway per AZ (high availability)
3. Adequate storage (500+ GB)
4. Business retention (30 days)
5. Full monitoring + alerting
6. Consider Reserved Instances

**Estimated Cost**: **$753/month** (or $527/month with 3-year RI)

## Cost Control Checklist

- [ ] Enable cost allocation tags
- [ ] Set up billing alerts
- [ ] Review costs weekly
- [ ] Right-size instances based on metrics
- [ ] Optimize topic retention
- [ ] Enable compression
- [ ] Use S3 gateway endpoints
- [ ] Delete unused resources
- [ ] Consider reserved capacity for prod
- [ ] Monitor storage growth

## Summary

The current dev environment configuration is optimized for cost while maintaining functionality:

- **Monthly Cost**: ~$229
- **Annual Cost**: ~$2,745
- **Cost per service**: ~$38/month

This represents a **65% cost reduction** compared to a production-grade configuration, making it ideal for development and testing purposes.

For production workloads, expect costs in the range of **$750-1,000/month** depending on throughput requirements and redundancy needs.

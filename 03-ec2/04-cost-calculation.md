# Module 4 — EC2 Cost Calculation

> Understand exactly what you pay for, how to estimate it, and how to cut it. Includes worked monthly estimates.

> ⚠️ All prices below are **illustrative examples** to teach the math. Always confirm live prices at https://aws.amazon.com/ec2/pricing/ and https://calculator.aws/.

---

## What You Actually Pay For (EC2 bill components)

```
   TOTAL EC2 COST =
       Compute (instance hours × rate)
     + EBS storage (GB-month × rate)  + EBS snapshots (GB-month)
     + Elastic IP (idle/extra public IPv4)        💰 don't forget!
     + Data transfer OUT (per GB)                 💰 in is free
     + Optional: ALB hours + LCU, NAT Gateway hours + data
```

| Component | Billed by | Notes |
|-----------|-----------|-------|
| **Instance compute** | per second (Linux, 60s min) or hour | depends on type + purchase model |
| **EBS volume** | GB-month | gp3 cheaper than gp2; charged even when instance stopped |
| **EBS snapshot** | GB-month (incremental) | backups stored in S3 |
| **Elastic IP** | per hour when idle/extra | all public IPv4 now billed |
| **Data transfer OUT** | per GB (tiered) | inter-AZ/inter-Region also costs |
| **ALB / NAT Gateway** | per hour + usage | add if used |

---

## The Compute Math

```
Monthly hours ≈ 730 (24 × 365 / 12)

Monthly compute = hourly_rate × hours_running × number_of_instances
```

**Example rates (illustrative, Linux, us-east-1):**
| Type | ~On-Demand $/hr | ~$/month (730h) |
|------|-----------------|------------------|
| t3.micro | $0.0104 | ~$7.59 |
| t3.small | $0.0208 | ~$15.18 |
| t4g.small (Graviton) | $0.0168 | ~$12.26 |
| m7g.large | $0.0816 | ~$59.57 |
| c7g.xlarge | $0.145 | ~$105.85 |

💡 **Stopped instance = $0 compute** (but you still pay for its EBS volume).

---

## The Storage Math

```
EBS monthly = size_GB × $/GB-month
```
**Example (gp3 ≈ $0.08/GB-month):**
- 30 GB gp3 root volume = 30 × 0.08 = **$2.40/month**
- 100 GB gp3 = **$8.00/month**
- gp3 includes 3,000 IOPS + 125 MB/s baseline free; extra IOPS/throughput billed separately.

**Snapshots (≈ $0.05/GB-month, incremental):** a 30 GB volume's first snapshot ~ $1.50/month; later snapshots only charge for changed blocks.

---

## Data Transfer
- **IN to EC2:** free.
- **OUT to internet:** free tier ~100 GB/month, then ~$0.09/GB (tiered down at volume).
- **Inter-AZ / inter-Region:** charged per GB — keep chatty tiers in the same AZ where sensible.

💰 Use **CloudFront** to cache and cut origin data-transfer-out costs for static/media content.

---

## Worked Estimate A — Capstone (single small box)

```
1 × t3.small (24/7)        730h × $0.0208   ≈ $15.18
30 GB gp3 root volume      30 × $0.08       ≈  $2.40
1 daily snapshot (~30 GB)                    ≈  $1.50
Elastic IP (attached/running)                ≈  $0.00 (free while attached)
Data transfer out (~10 GB)  ~10 × $0.09      ≈  $0.90
-----------------------------------------------------
Approx TOTAL                                 ≈ $19.98 / month
```
💰 **Cut it:** use **t4g.small** (Graviton) → compute ~$12.26 → total ≈ **$17/month**. Stop the box when not in use while learning → near Free-Tier costs.

---

## Worked Estimate B — Small HA Production

```
2 × m7g.large (24/7, Savings Plan ~ -40%)
   On-Demand 2 × $59.57 = $119.14 → with SP ≈ $71/mo
ALB (730h × ~$0.0225 + LCUs)                 ≈ $20/mo
2 × 30 GB gp3                                 ≈  $4.80/mo
RDS MySQL db.t3.medium Multi-AZ              ≈ $100/mo (separate service)
Data transfer out (~100 GB)                   ≈  $9/mo
NAT Gateway (if private subnets)             ≈ $33/mo + data
-----------------------------------------------------
Approx TOTAL (EC2 portion + ALB + storage)   ≈ $105–140 / month
```

---

## How to Estimate Before Building
1. **AWS Pricing Calculator** (https://calculator.aws/): add EC2, EBS, data transfer, ALB → get a shareable monthly estimate.
2. Pick Region (prices vary), instance type, hours, purchase model.
3. Add storage + transfer + any ALB/NAT.

---

## 12 Ways to Cut EC2 Cost 💰
```
1.  Right-size (Compute Optimizer) — stop over-provisioning
2.  Use Graviton (t4g/m7g/c7g) — ~20% cheaper
3.  Savings Plans / Reserved for steady baseline — up to 72%
4.  Spot for interruptible/batch — up to 90%
5.  Stop/schedule non-prod instances nights & weekends
6.  Use gp3 instead of gp2 (cheaper, faster)
7.  Delete unattached EBS volumes & old snapshots
8.  Release idle Elastic IPs / unused public IPv4
9.  Auto Scaling — scale in when idle
10. CloudFront/caching to reduce data-transfer-out
11. Keep chatty traffic in-AZ to avoid inter-AZ charges
12. Set AWS Budgets + alarms; tag for cost visibility
```

---

## Cost Monitoring Tools (recap from Phase 01)
- **AWS Budgets** → alert on thresholds.
- **Cost Explorer** → analyze/forecast + rightsizing recs.
- **Compute Optimizer** → instance rightsizing recommendations.
- **Cost allocation tags** → per-project/team cost.

---

➡️ Next: [05-ssh-and-linux-admin.md](05-ssh-and-linux-admin.md)

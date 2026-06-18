# 18 — Advanced AWS Cheat Sheet (1-Page Revision)

> Last-minute revision for architect-level topics. Pair with the phase modules.

## CloudFront (CDN)
- Global edge cache; origins = S3/ALB/custom. **OAC** locks the origin to CloudFront only.
- Lowers latency + offloads origin. Signed URLs/cookies for private content. Geo-restriction. Lambda@Edge / CloudFront Functions for edge logic. Integrates with **WAF + Shield**.

## ElastiCache
| | **Redis** | **Memcached** |
|---|---|---|
| Data | rich types, persistence, replication, pub/sub | simple key/value |
| HA | replication + failover, cluster mode | none (sharding only) |
| Use | sessions, leaderboards, caching, queues | simple cache, scale-out |
💡 Cache-aside (lazy loading) + TTL is the default pattern.

## Messaging recap
- **SQS** queue (decouple) · **SNS** fan-out (pub/sub) · **EventBridge** event routing/schemas/scheduler.
- Fan-out = SNS → many SQS. DLQ for failures. FIFO = ordered + exactly-once.

## IaC: Terraform vs CloudFormation
| | **Terraform** | **CloudFormation** |
|---|---|---|
| Scope | Multi-cloud, HCL | AWS-native, YAML/JSON |
| State | state file (remote backend) | managed by AWS |
| Reuse | modules | nested stacks / StackSets |
| Drift | `plan` | drift detection |
- **CDK** = author CFN in real languages. StackSets = deploy across accounts/Regions.

## Edge security
- **WAF** = L7 rules (managed rule groups, rate-limit, IP sets, bot control) on CloudFront/ALB/API GW.
- **Shield Standard** (free, L3/4 DDoS) · **Shield Advanced** (paid, 24/7 SRT, cost protection).

## Organizations & multi-account
- **OUs** + **SCPs** (guardrails) + consolidated billing. **Control Tower** = landing zone automation.
- Pattern: management + **security** + **log-archive** + workload accounts; centralized CloudTrail/Config/GuardDuty.

## DR strategies (RTO/RPO ↓ = cost ↑)
| Strategy | RTO | Cost |
|---|---|---|
| **Backup & Restore** | hours | 💲 |
| **Pilot Light** | 10s of min | 💲💲 |
| **Warm Standby** | minutes | 💲💲💲 |
| **Multi-Site Active-Active** | ~0 | 💲💲💲💲 |
- RPO = data loss tolerance; RTO = downtime tolerance. Multi-Region via Route 53 + replication (Aurora Global, S3 CRR, DynamoDB Global Tables).

## Scalability patterns
- Stateless tiers + ASG/ECS auto scaling · cache (ElastiCache/CloudFront) · async (SQS/EventBridge) · partition/shard data · read replicas · multi-AZ everything.

## Exam triggers 💡
- "Global low-latency static + dynamic delivery" → **CloudFront**.
- "Session store / hot cache" → **ElastiCache Redis**.
- "Reproducible infra across clouds" → **Terraform**; "AWS-native + StackSets" → **CloudFormation/CDK**.
- "Lowest RTO/RPO, global" → **Active-Active multi-Region**; "cheap DR" → **Backup & Restore**.
- "Org-wide guardrails" → **SCPs**; "automated landing zone" → **Control Tower**.
- "Protect against DDoS + L7 attacks" → **Shield (+Advanced) + WAF**.

## Gotchas ⚠️
- SCPs limit, never grant. CloudFront caching can serve stale content — set TTLs/invalidations.
- Multi-Region active-active is complex + costly — justify with real RTO/RPO needs.
- Terraform state must be remote + locked (S3 + DynamoDB) for teams.

---
*Back to [Advanced AWS README](README.md).*

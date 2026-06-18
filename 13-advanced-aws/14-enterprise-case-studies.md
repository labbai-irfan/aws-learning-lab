# Module 14 — Enterprise Case Studies

> Real-world problem patterns (anonymised) with the architecture challenge, solution chosen, trade-offs, and the lessons learned.

---

## Case Study 1 — Global HRMS SaaS: 0 → 10,000 tenants

**Background:** A startup HRMS launched on a single EC2 + RDS. Within 18 months they had 500 paying tenants and needed to 20× for an enterprise deal.

**Challenge:**
- Single DB: 500 tenants sharing one schema + tenant_id column → noisy neighbour, migration risk.
- Single AZ: one outage event cost them a $200k enterprise deal.
- No CI/CD: manual deploys, 4-hour downtime windows.

**Architecture evolution:**
```
   Before: EC2 + RDS (single AZ, single schema, no CDN)
   After:
   ├── Multi-Account (Org): Prod / Staging / Security / Log Archive
   ├── CloudFront → ALB → ECS Fargate (auto-scaling, no EC2 to patch)
   ├── Aurora (Multi-AZ, cluster mode): schema-per-tenant (100 schemas/cluster, 5 clusters)
   ├── ElastiCache Redis cluster: tenant-namespaced sessions + cache
   ├── SQS FIFO per-tenant: payroll run isolation
   ├── Terraform (module per tenant tier): pool provision < 5 min, silo < 30 min
   ├── CodePipeline: blue/green ECS deploy, auto-rollback on 5xx alarm
   └── WAF + Shield Advanced: rate limit per subdomain, OWASP rules
```

**Results:** 10,000 tenants at 99.99% uptime; deploy time cut from 4 hrs to 8 min; p99 latency halved (ElastiCache); engineering team 3× more productive (platform engineering).

**Lessons:**
- Schema-per-tenant scales to ~1,000 schemas in Aurora before sharding needed.
- ECS Fargate was the right choice — no EC2 fleet to manage at this team size.
- WAF rate limiting per-tenant stopped a credential-stuffing attack on launch day.

---

## Case Study 2 — Financial Services: Migration to Multi-Region Active-Active

**Background:** A payment platform with 99.95% SLA in one region. A 4-hour us-east-1 event cost $2M. Board required 99.99% SLA.

**Challenge:**
- RDS (single region, single master) → RPO hours, RTO 2+ hours.
- Session data in ElastiCache (ephemeral) lost on failover.
- 200ms latency to European users from us-east-1.

**Solution:**
```
   Route 53 latency routing → us-east-1 + eu-west-1
   Aurora Global Database: primary us-east-1 <1s lag → eu-west-1 (readable)
   DynamoDB Global Tables: session store (multi-master, zero RPO)
   S3 CRR: all assets replicated within 15 min (RTC enabled)
   CloudFront: edge-cached responses globally
   TGW + Direct Connect: on-prem ↔ both regions
```

**Trade-offs:**
- Aurora Global = 3× cost of single-region RDS → approved by board given SLA requirement.
- Writes still routed to us-east-1 primary (cannot do true multi-master writes with Aurora without Limitless).
- DynamoDB Global Tables: changed session design from complex objects to flat key/TTL → development effort.

**Results:** SLA achieved 99.99% in first quarter; European p99 latency dropped 60%; next outage in us-east-1 resulted in automatic Route 53 failover → 45-second RTO.

**Lessons:**
- DynamoDB Global Tables is the easiest path for truly zero-RPO session data.
- S3 CRR with RTC is essential (without it, replication lag is unpredictable).
- Load test in BOTH regions before go-live — eu-west-1 had different capacity needs than assumed.

---

## Case Study 3 — Manufacturing: Lift-and-Shift to Modernisation

**Background:** 40 on-prem servers running 15-year-old Java apps. EOL hardware in 6 months. Leadership: "just move it to AWS."

**Phases:**

**Phase 1 — Lift and Shift (3 months)**
```
   On-prem → EC2 (same OS, same app, same DB on EC2 MySQL)
   AWS Application Migration Service: replicated live, cutover in 4-hour window
   Direct Connect: on-prem ↔ AWS VPC during transition
```

**Phase 2 — Replatform (6 months)**
```
   EC2 MySQL → RDS MySQL 8.0 (Multi-AZ, automated backups)
   Monolith → containerised (Docker + ECS, no code change)
   Hand-deployed scripts → CodePipeline
   Log files → CloudWatch agent + Logs Insights
```

**Phase 3 — Modernise (12 months)**
```
   Monolith → strangler-fig pattern: extract payroll → Lambda + SQS
   File transfers → S3 + event-driven Lambda (replaced 15 cron jobs)
   On-prem Oracle reports → Redshift + QuickSight
   Authentication → Cognito (replacing LDAP)
```

**Lessons:**
- Never promise modernisation in Phase 1. Lift-and-shift creates optionality.
- RDS migration was the highest-value Phase 2 change (backups, Multi-AZ, managed patching).
- Strangler-fig: extract the most painful pieces first, not the easiest.

---

## Case Study 4 — E-Commerce: Black Friday Scaling (100× traffic in 2 hours)

**Background:** Fashion retailer, peak Black Friday traffic = 100× normal. Previous year: site down for 3 hours.

**Root causes (previous year):**
- RDS connections exhausted (no pooling, 500 tasks × 50 connections = 25,000 > max).
- EC2 ASG too slow to scale (5-minute warmup, AMI bake time).
- No CDN → all static assets hitting origin.

**Solution:**
```
   CloudFront: cache all static assets (JS/CSS/images) → 95% cache hit rate
   CloudFront Functions: URL normalisation (no origin hits for trailing slash)
   RDS Proxy: 500 ECS tasks → 50 pooled DB connections
   ECS Fargate: pre-scaled 2 hours before via EventBridge schedule + predictive scaling
   ElastiCache: product catalogue cached (30-min TTL) → 80% DB read reduction
   SQS: order processing async → checkout response < 200ms, order processed in background
   WAF: rate limit 5000 req/5min per IP (bots tried to scrape inventory)
   Shield Advanced: SRT on standby
```

**Results:** Zero downtime; p99 at peak = 210ms (vs 3s timeout previous year); RDS connections peak = 52 (vs 25,000); cost during peak = $4,200 (vs $1,200 normal, 3.5× not 100×, because CloudFront absorbed most traffic).

**Lessons:**
- CloudFront cache-hit ratio is the single biggest lever for traffic spikes.
- RDS Proxy is mandatory for ECS at scale.
- Pre-scale via EventBridge schedule; don't rely on reactive auto-scaling for a known event.

---

## Case Study 5 — Healthcare SaaS: HIPAA Compliance at Scale

**Challenge:** Achieve HIPAA compliance for a patient management SaaS serving 300 hospitals. PII/PHI in every record.

**Architecture decisions:**
```
   Multi-Account Org: each hospital = dedicated account (maximum isolation, BAA per account)
   VPC: all in private subnets; VPC endpoints for every AWS service (no internet for PHI)
   RDS: KMS CMK per hospital-account; TLS required; audit logs to CloudWatch
   S3: server-side encryption KMS; bucket policy denies non-TLS; Macie scans for PHI leakage
   CloudTrail: Org trail → immutable Log Archive (Write Once Read Many S3 policy)
   GuardDuty + Security Hub + Config: all enabled, findings in Security Tooling account
   Lambda authorizer: JWT + HIPAA audit log every access (who accessed which patient)
   WAF: on CloudFront; IP allowlist for hospital network ranges (hospital-by-hospital)
   Secrets Manager: DB credentials; rotation every 30 days; encrypted with CMK
```

**Lessons:**
- Per-customer account (silo) is the right model for regulated healthcare — no shared data layer.
- Macie caught 3 PHI leakage incidents in non-prod environments during testing.
- WAF IP allowlist per hospital: operational burden but required by HIPAA security rule.
- CloudTrail + Athena: HIPAA audit queries answered in minutes, not days.

---

## Case Study 6 — Startup: Serverless-first HRMS, $0 → $10k MRR on < $200/month infra

**Insight:** Right-sized for the stage. Serverless before EC2.

```
   Route 53 → CloudFront → S3 (React SPA) — $0
   API Gateway → Lambda (Node, Prisma) — pay per request
   RDS Aurora Serverless v2 — scales to 0 when idle (dev nights/weekends)
   SQS → Lambda (payroll, email) — no idle workers
   Cognito — 50,000 MAU free tier
   EventBridge Scheduler — replaces cron servers
```

**Cost at 1,000 users:** ~$80/month. Same architecture scaled to 50,000 users: ~$600/month. Migration trigger: when Lambda cold starts cause SLA issues → ECS Fargate.

**Lesson:** Over-engineering hurts startups. Start serverless, migrate to containers when warm start matters. The infrastructure grew with the business, not ahead of it.

---

## 💡 Cross-case patterns

| Problem | Solution seen across cases |
|---|---|
| DB connection exhaustion at scale | RDS Proxy (always) |
| Traffic spikes | CloudFront + pre-scaling (predictive/scheduled) |
| Noisy neighbour | SQS isolation + per-tenant rate limiting |
| Compliance | Silo model (per-customer account) |
| DR | Aurora Global + Route 53 failover (tested quarterly) |
| Cost explosion | Reserved Instances + right-sizing + CloudFront (absorbs load) |
| Security incident | GuardDuty → EventBridge → auto-quarantine Lambda |

➡️ Next: [Module 15 — Troubleshooting Handbook](15-troubleshooting-handbook.md)

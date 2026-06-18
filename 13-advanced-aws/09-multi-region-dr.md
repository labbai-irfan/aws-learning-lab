# Module 9 — Multi-Region Architecture & Disaster Recovery

> Active-active, active-passive, RPO/RTO targets, global routing, Aurora Global, S3 replication, and running a DR drill.

---

## 1. Why multi-region

| Reason | Architecture implication |
|---|---|
| **Regional outage** (rare but severe) | Standby or active capacity in a second region |
| **Low latency for global users** | Route users to nearest region |
| **Data residency** | Specific workloads must stay in specific regions |
| **Compliance** | Some regulations require geo-redundant backups |

---

## 2. The DR strategy matrix

```
   Cheaper / slower  ◄──────────────────────────────────►  Costlier / faster
   Backup & Restore   Pilot Light   Warm Standby   Active-Active
```

| Strategy | How | RTO | RPO | Relative cost |
|---|---|---|---|---|
| **Backup & Restore** | Snapshots + config copied to DR region. Restore on disaster. | Hours | Minutes–hours | $ |
| **Pilot Light** | Core infra running small in DR (RDS read replica, minimal ECS). Scale on disaster. | 10–30 min | Seconds–minutes | $$ |
| **Warm Standby** | Full but scaled-down stack in DR. Scale up and promote on disaster. | Minutes | Seconds | $$$ |
| **Active-Active** | Full traffic in both regions. Zero-downtime failover. | Near-zero | Near-zero | $$$$ |

### Choosing the right strategy
- Most HRMS/internal apps: **Pilot Light** (cost-effective, acceptable RTO).
- Customer-facing SaaS: **Warm Standby** or **Active-Active**.
- Financial/healthcare tier-1: **Active-Active**.

---

## 3. Global routing with Route 53

### Failover routing policy
```yaml
PrimaryRecord:
  Type: A (Alias to ALB in us-east-1)
  Failover: PRIMARY
  HealthCheck: /health on us-east-1 ALB
FailoverRecord:
  Type: A (Alias to ALB in us-west-2)
  Failover: SECONDARY       # only receives traffic when primary unhealthy
```

### Latency routing (Active-Active or blue/green)
```yaml
USEastRecord:
  Region: us-east-1
  RoutingPolicy: Latency   # Route 53 routes each user to the region with lowest latency
EUWestRecord:
  Region: eu-west-1
  RoutingPolicy: Latency
```

### Geoproximity routing
Route users to a specific region even if latency isn't the lowest — for data residency requirements.

---

## 4. Database replication across regions

### Aurora Global Database (the gold standard)
```
   Aurora Cluster (us-east-1)  ──~1s lag──►  Aurora Cluster (us-west-2) [read-only]
                                                     │ Promote in ~1 min on disaster
```
- Replication < 1 second globally.
- Cross-region read replicas serve local reads (latency routing).
- Planned failover < 1 min; unplanned ~1 min.
- Single cluster across 5 regions max.

### RDS cross-region read replica (standard)
```
   RDS Primary (us-east-1) ──async──► Read Replica (us-west-2)
   Promote replica (breaks replication) → new primary in DR
```
- Async replication → seconds-to-minutes lag → RPO seconds–minutes.
- Promote takes a few minutes.

### DynamoDB Global Tables
```
   Table in us-east-1 ◄──sync──► Table in eu-west-1 (multi-master)
```
- Multi-region, multi-master reads and writes.
- Last-writer-wins conflict resolution.
- RPO = 0 (synchronous); RTO = DNS change.

---

## 5. Data replication — storage layer

### S3 Cross-Region Replication (CRR)
- Enable on source bucket; replicate to target in another region.
- Replication time: typically seconds; **SLA: 99.99% within 15 min** with Replication Time Control (RTC).
- Encrypted objects supported; KMS keys needed in both regions.
- ⚠️ CRR replicates **new** objects; existing objects need a one-time batch replication job.

### EFS (file system)
- AWS DataSync to replicate EFS to another region.
- Or: write data to S3 and mount in DR.

---

## 6. Stateless vs stateful components in DR

| Component | DR approach |
|---|---|
| EC2 / ECS / Lambda | **Stateless** — launch in DR from same IaC template; no data to replicate |
| Configuration | Parameter Store / Secrets Manager with cross-region replication |
| RDS / Aurora | Cross-region replica / Aurora Global |
| ElastiCache Redis | **Not replicated** — warm-up from DB on restart (caches are ephemeral) |
| SQS messages | **Not replicated** — SQS is regional; use EventBridge cross-region or duplicate publishes |
| S3 | CRR |

---

## 7. Active-Active architecture pattern

```
   Users globally
        │ Route 53 latency routing
        ▼
   us-east-1                         eu-west-1
   CloudFront ──► ALB ──► ECS       CloudFront ──► ALB ──► ECS
        │                                 │
   Aurora Global (primary) ────────► Aurora Global (secondary, readable)
   ElastiCache (local)               ElastiCache (local)
   S3 bucket ◄──── CRR ────────────► S3 bucket
```

Writes in active-active:
- Route ALL writes to the **primary region** Aurora cluster (via app config or Route 53 private zone).
- In true multi-master (DynamoDB Global Tables / Aurora Limitless), writes in each region accepted.
- Handle **conflict resolution** at the application layer if writing to both.

---

## 8. Disaster Recovery drill

**The drill nobody does but every architect should:**
1. **Failover drill** (quarterly):
   - Block traffic to primary region (via health check or Route 53 weight).
   - Promote DB replica.
   - Update DNS to DR.
   - Run smoke tests.
   - Measure actual RTO.
2. **Restore drill** (annually): restore from backups to a new account/region; verify data integrity.
3. **Document**: who does what, what commands, expected timing.
4. **Measure**: actual RTO/RPO vs target. If it doesn't meet SLA, fix the architecture.

⚠️ **An untested DR plan is not a DR plan.** Every year without a drill is a year closer to a very bad day.

---

## 9. RPO/RTO for HRMS

| Tier | Components | Target RTO | Target RPO | Strategy |
|---|---|---|---|---|
| Tier 1 — Critical | Payroll, Auth | 15 min | 5 min | Warm Standby + Aurora Global |
| Tier 2 — Important | HRMS API, attendance | 1 hour | 30 min | Pilot Light + RDS CRR |
| Tier 3 — Non-critical | Reports, analytics | 4 hours | 1 hour | Backup & Restore |

---

## ✅ Multi-Region / DR checklist
- [ ] RPO/RTO targets defined per tier
- [ ] Route 53 failover health checks configured and tested
- [ ] Aurora Global Database (or RDS cross-region replica) for DB
- [ ] S3 CRR enabled for all buckets with user data
- [ ] IaC exists for DR region deployment (Terraform workspaces / separate env)
- [ ] Stateless compute — deploy from code, not AMI snapshots
- [ ] Secrets Manager / Parameter Store replicated to DR region
- [ ] DR drill scheduled quarterly; results documented
- [ ] Cost of warm standby modeled and approved

➡️ Next: [Module 10 — Scalability Design](10-scalability-design.md)

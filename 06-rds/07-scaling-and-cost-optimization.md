# Module 7 — Scaling Strategy & Cost Optimization

> How to scale RDS (vertically, horizontally, storage) and how to cut the bill without cutting resilience.

---

## 1. Scaling strategies

### a) Vertical scaling (scale up/down)
Change the **instance class** to add CPU/RAM (`db.t3.medium` → `db.r6g.large`).
- With **Multi-AZ**, AWS modifies the standby first then **fails over** → minimal downtime.
- Single-AZ → a few minutes of downtime during the resize.
- 🛠️ `aws rds modify-db-instance --db-instance-identifier hrms-db --db-instance-class db.r6g.large --apply-immediately`
- ⚠️ Apply during a window unless urgent; `--apply-immediately` causes the failover/restart now.

### b) Horizontal read scaling (scale out)
Add **read replicas** for read-heavy workloads (reporting, dashboards, search).
- Up to 15 replicas; route `SELECT`s to them ([Module 5](05-prisma-and-connection-pooling.md)).
- ⚠️ Replicas scale **reads only** — writes always hit the single primary. If **writes** are the bottleneck, you need vertical scaling, sharding, or **Aurora**.

### c) Storage scaling
- **Storage autoscaling**: set `--max-allocated-storage`; RDS grows storage automatically (grows only, never shrinks).
- **IOPS/throughput** (gp3): provision IOPS/throughput independently of size when you hit I/O limits.
- ⚠️ You **can't reduce** allocated storage — to shrink, dump→restore into a smaller instance.

### d) Connection scaling
- **RDS Proxy** to handle connection spikes without a bigger instance.
- Tune `max_connections` via parameter group, but RAM is the real limit — pooling beats raising the cap.

### e) When you outgrow RDS
- Writes saturate the primary → **Aurora** (3–5× throughput), **vertical max-out**, **sharding**, or **CQRS / caching (ElastiCache)** to offload reads.

```
   Read-bound?  -> add read replicas / ElastiCache
   Write-bound? -> scale up instance / Aurora / shard
   Connection-bound? -> RDS Proxy / pooling
   Storage/IOPS-bound? -> gp3 IOPS / io2 / autoscaling
```

---

## 2. Cost model — what you actually pay for
1. **Instance hours** (by class; Multi-AZ ≈ 2×).
2. **Storage** (GB-month) + **provisioned IOPS** (io1/io2 or gp3 extra).
3. **Backup storage** beyond your DB size (within size = free).
4. **Data transfer** (cross-AZ replica traffic, cross-region copies, egress).
5. **Read replicas** (each = another instance you pay for).
6. **Extras**: Performance Insights (long retention), Enhanced Monitoring, RDS Proxy.

---

## 3. Cost optimization levers 💰

| Lever | Saving | Notes |
|---|---|---|
| **Reserved Instances** (1/3-yr) | up to ~60% | For steady prod. Commit once sizing is stable. |
| **Graviton** (`db.*g`) | ~20% + better perf | Default to ARM for MySQL/PG/MariaDB. |
| **gp3 over gp2/io1** | meaningful | gp3 decouples IOPS from size; cheaper baseline. |
| **Right-size** | varies | Use CloudWatch CPU/memory/connections to downsize over-provisioned instances. |
| **Stop dev/test instances** | ~100% off-hours | Single-AZ instances can be **stopped up to 7 days**; or schedule start/stop. |
| **Single-AZ for non-prod** | ~50% | Multi-AZ only where HA matters. |
| **Trim backup retention** | storage $ | Keep what compliance needs, not more. |
| **Delete orphan snapshots** | storage $ | Old manual snapshots accumulate silently. |
| **Replica only when needed** | one instance | Don't run idle replicas. |
| **Aurora I/O-Optimized** | for I/O-heavy | Predictable price when I/O charges dominate. |

💡 **Biggest wins in practice:** Reserved Instances for prod + Graviton + right-sizing + stopping non-prod. These together often halve the bill.

### Right-sizing signal
- CPU consistently < 40% and memory comfortable → downsize one step.
- `FreeableMemory` chronically low / heavy swap → upsize (or add buffer pool tuning).
- Connections far below `max_connections` → instance is fine; don't over-provision for connections, use pooling.

🛠️ Estimate before you build: https://calculator.aws/

---

## 4. Example: cost-aware HRMS sizing

| Environment | Instance | Multi-AZ | Storage | Pricing | Rationale |
|---|---|---|---|---|---|
| Dev | `db.t4g.micro` | No | 20 GB gp3 | On-demand, stop off-hours | Cheapest, disposable |
| Staging | `db.t4g.small` | No | 20 GB gp3 | On-demand | Mirrors prod schema |
| Prod | `db.r6g.large` | **Yes** | 100 GB gp3 autoscale→500 | **3-yr Reserved** | HA + steady load |
| Prod replica | `db.t4g.large` | No | (mirrors) | On-demand/RI | Reporting only |

---

## 5. Cost guardrails
- **Tag everything** (`Env`, `App`, `Owner`) → cost allocation reports.
- **AWS Budgets** alert on RDS spend anomalies.
- **Cost Explorer** monthly review: top instances, idle replicas, snapshot storage growth.
- **Trusted Advisor / Compute Optimizer** flags idle and over-provisioned RDS.

➡️ Next: [Module 8 — Security Deep Dive](08-security-guide.md)

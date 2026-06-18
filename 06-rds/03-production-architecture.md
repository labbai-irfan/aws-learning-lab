# Module 3 — Production Database Architecture

> How a real, resilient RDS architecture is laid out — networking, HA, read scaling, security, and the diagrams to draw in an interview.

---

## 1. The reference production architecture

```
                          ┌──────────── AWS Region (us-east-1) ────────────┐
   Internet ─► Route 53 ─► │  ALB (public subnets)                          │
                           │      │                                         │
                           │      ▼  EC2 / ECS app tier (private subnets)   │
                           │   ┌──────────────┐   ┌──────────────┐          │
                           │   │ App AZ-a     │   │ App AZ-b     │  (ASG)    │
                           │   │ Node+Prisma  │   │ Node+Prisma  │          │
                           │   └──────┬───────┘   └──────┬───────┘          │
                           │          │ writes (3306)    │ reads            │
                           │          ▼                  ▼                  │
                           │   ┌───────────────── DB tier (private DB subnets)
                           │   │  PRIMARY (AZ-a)  ══sync══►  STANDBY (AZ-b) │ Multi-AZ
                           │   │      │ async                                │
                           │   │      ▼                                      │
                           │   │  READ REPLICA (AZ-c)  ◄── reporting/BI      │
                           │   └───────────────────────────────────────────┘
                           │   Backups+PITR (S3) · Secrets Manager · KMS     │
                           └──────────────┬──────────────────────────────────┘
                                          │ cross-region snapshot copy / replica
                                          ▼
                          ┌──────── DR Region (us-west-2) ────────┐
                          │  Encrypted snapshot copies / replica   │
                          └────────────────────────────────────────┘
```

### The tiers
1. **Edge:** Route 53 → ALB (public subnets).
2. **App tier:** EC2/ECS in **private** subnets, Auto Scaling across ≥2 AZs.
3. **Data tier:** RDS in **dedicated private DB subnets** (the DB subnet group), Multi-AZ + read replica.
4. **Support:** Secrets Manager (credentials), KMS (encryption), CloudWatch (monitoring), S3 (backups).

---

## 2. Network layout (VPC)

| Subnet tier | Subnets | Routes | Holds |
|---|---|---|---|
| Public | 2× (AZ-a, AZ-b) | IGW | ALB, NAT gateway |
| Private-app | 2× (AZ-a, AZ-b) | NAT (egress only) | EC2/ECS app instances |
| Private-db | ≥2× (AZ-a, AZ-b, AZ-c) | **no internet route** | RDS instances |

- The **DB subnet group** must span **at least 2 AZs** (RDS requires it, even single-AZ). For Multi-AZ cluster, 3 AZs.
- 🔒 DB subnets have **no route to IGW or NAT** — database can't reach the internet and vice versa.

### Security group chain
```
ALB-SG    : inbound 443 from 0.0.0.0/0
App-SG    : inbound 443/3000 from ALB-SG
DB-SG     : inbound 3306 from App-SG  ← only the app can reach the DB
```
⚠️ Reference **security groups as sources**, not CIDR ranges — it auto-tracks instances as the ASG scales.

---

## 3. High availability design

| Failure | Mitigation |
|---|---|
| Single instance crash | Multi-AZ auto-failover (60–120s) |
| Whole AZ outage | Multi-AZ standby in another AZ; app ASG spans AZs |
| Read overload | Read replicas absorb `SELECT` traffic |
| Region outage | Cross-region read replica / snapshot copies → promote (DR) |
| Accidental data loss | PITR + snapshots |
| Credential leak | Secrets Manager rotation; SG isolation |

**Connection strategy for HA:**
- Writes → **primary endpoint** (`hrms-db.xxxx.rds.amazonaws.com`).
- Reads → **reader/replica endpoint(s)**.
- App driver must **retry on failover** and **not cache DNS** beyond ~5s.

---

## 4. Read/write splitting pattern

```
   App ──writes──► Primary endpoint   (INSERT/UPDATE/DELETE, transactions)
       └─reads───► Replica endpoint   (SELECT reports, dashboards)
```
- In Prisma/Node: maintain **two clients** (one to primary, one to replica) or use a proxy. See [Module 5](05-prisma-and-connection-pooling.md).
- ⚠️ Beware **replica lag**: don't read your own just-committed write from a replica (read-after-write should hit the primary).

---

## 5. Where RDS Proxy fits

**Amazon RDS Proxy** is a managed connection pooler that sits between the app and RDS:
```
   Many app instances ─► RDS Proxy ─► (pooled) ─► RDS primary/standby
```
- Solves **connection storms** from serverless (Lambda) or large ASGs that exhaust `max_connections`.
- Provides **faster failover** (holds connections, repoints to new primary) and integrates with **IAM auth + Secrets Manager**.
- 💡 Strongly recommended when the app tier is **Lambda** or scales to many instances. For a small fixed EC2 fleet, the app-side pool may be enough.

---

## 6. Environments & isolation
- Separate **dev / staging / prod** — ideally separate AWS accounts (Organizations) or at least separate VPCs and DB instances.
- Never point staging at the prod database.
- Refresh staging data by **restoring a prod snapshot** (then scrub PII).

---

## 7. Production readiness checklist
- [ ] Multi-AZ enabled
- [ ] ≥1 read replica for reporting (if read-heavy)
- [ ] Private DB subnets, no public access
- [ ] DB-SG inbound only from App-SG
- [ ] Encryption at rest (KMS) + TLS in transit
- [ ] Secrets Manager credentials with rotation
- [ ] Automated backups ≥7d + deletion protection ON
- [ ] Cross-region snapshot copy for DR
- [ ] Performance Insights ON, CloudWatch alarms set
- [ ] Custom parameter group (buffer pool, slow log, max_connections)
- [ ] Tested failover and tested restore

➡️ Next: [Module 4 — Migration from Local MySQL](04-migration-from-local-mysql.md)

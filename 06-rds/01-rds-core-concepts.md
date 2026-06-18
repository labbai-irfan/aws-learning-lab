# Module 1 — Amazon RDS Core Concepts

> Every core RDS topic in one place: Overview, engines, Multi-AZ, Read Replicas, Parameter Groups, Backups, Snapshots, PITR, Failover, Monitoring, and Security.

**Legend:** 🛠️ run this · 💰 cost · ⚠️ gotcha · 🔒 security · 💡 tip

---

## 1. RDS Overview

**Amazon RDS (Relational Database Service)** is a *managed* relational database. AWS runs the database engine for you — OS patching, engine upgrades, backups, replication, failover, and monitoring are handled by the platform. You keep control of *schema, queries, data, and tuning*.

### Managed vs self-hosted (RDS vs MySQL on EC2)

| Responsibility | MySQL on EC2 (self-managed) | Amazon RDS (managed) |
|---|---|---|
| OS install & patching | You | **AWS** |
| Engine install & minor upgrades | You | **AWS** (you approve windows) |
| Backups | You (cron + scripts) | **AWS** (automated + PITR) |
| Multi-AZ replication & failover | You (build it) | **AWS** (one checkbox) |
| Read replicas | You | **AWS** (one click) |
| Monitoring | You | **CloudWatch + Performance Insights** |
| Schema, indexes, queries | You | **You** |
| OS / root shell access | Yes | **No** (managed, no SSH) |

⚠️ **The biggest mental shift:** with RDS you have **no SSH / no OS access**. You configure the engine through **parameter groups**, not `my.cnf`. You cannot install arbitrary OS packages or DB plugins — only those exposed through **option groups**.

### RDS deployment options
- **RDS (standard)** — the classic single-engine managed DB (this course's focus).
- **Aurora** — AWS's cloud-native MySQL/PostgreSQL-compatible engine; separate storage layer, up to 15 replicas, faster failover. More expensive, more capable. Covered briefly in [Module 2](02-engines-mysql-postgres-mariadb.md).
- **RDS Custom** — when you need OS/DB-level access (e.g., for legacy Oracle/SQL Server apps).
- **RDS on Outposts** — RDS on-premises hardware.

### The 6 engines RDS supports
MySQL · PostgreSQL · MariaDB · Oracle · SQL Server · Aurora (MySQL/PostgreSQL compatible).
This course focuses on the three open-source engines: **MySQL, PostgreSQL, MariaDB**.

### Key building blocks (the vocabulary)
- **DB Instance** — the database server (compute + storage + engine). Identified by a **DB instance identifier**.
- **DB Instance Class** — the hardware size: `db.t3.micro` (burstable) → `db.m6g` (general) → `db.r6g` (memory-optimized).
- **Endpoint** — DNS name + port your app connects to, e.g. `hrms.abc123.us-east-1.rds.amazonaws.com:3306`. **Always connect to the endpoint, never an IP** — IPs change on failover.
- **DB Subnet Group** — the set of (usually private) subnets across AZs where RDS can place instances.
- **Parameter Group** — engine configuration (like `my.cnf`).
- **Option Group** — optional engine features/plugins.
- **Security Group** — virtual firewall controlling who reaches the DB port.

---

## 2. DB Instance Classes & Storage

### Instance class families
| Family | Prefix | Use |
|---|---|---|
| Burstable | `db.t3`, `db.t4g` | Dev/test, small prod, spiky low load. CPU credits. |
| General purpose | `db.m6g`, `db.m7g` | Balanced CPU/RAM for most web apps. |
| Memory optimized | `db.r6g`, `db.r7g`, `db.x2g` | Large datasets, caching-heavy, analytics. |

💡 `g` = AWS Graviton (ARM) — ~20% cheaper and often faster than Intel equivalents. Default to Graviton for MySQL/PostgreSQL/MariaDB.

### Storage types
| Type | Description | Use |
|---|---|---|
| **gp3** (General Purpose SSD) | Baseline 3,000 IOPS / 125 MB/s, scalable independently | **Default for most workloads** |
| **gp2** (older) | IOPS scale with size (3 IOPS/GB) | Legacy; prefer gp3 |
| **io1 / io2** (Provisioned IOPS SSD) | Up to 256,000 IOPS, lowest latency | High-throughput OLTP |
| **Magnetic** | Legacy HDD | Don't use |

- **Storage Autoscaling** — set a max; RDS grows storage automatically when free space runs low. ⚠️ It only grows, never shrinks.
- ⚠️ You **cannot reduce** allocated storage after creation. To shrink, dump → restore into a smaller instance.

🛠️ Create a basic instance:
```bash
aws rds create-db-instance \
  --db-instance-identifier hrms-db \
  --db-instance-class db.t3.medium \
  --engine mysql --engine-version 8.0.39 \
  --allocated-storage 50 --max-allocated-storage 200 \
  --storage-type gp3 \
  --master-username admin --manage-master-user-password \
  --db-subnet-group-name hrms-subnets \
  --vpc-security-group-ids sg-0abc123 \
  --backup-retention-period 7 \
  --multi-az \
  --no-publicly-accessible
```

---

## 3. Multi-AZ Deployments

**Multi-AZ = high availability.** RDS maintains a **synchronous standby replica** in a *different Availability Zone*. Every committed write goes to both primary and standby before acknowledgment.

```
        AZ-a                          AZ-b
   +-------------+   synchronous   +-------------+
   |  PRIMARY    | ==============> |  STANDBY    |
   |  (active)   |   replication   | (passive)   |
   +-------------+                 +-------------+
        ^                                 |
        | app connects to ENDPOINT        | on failure, DNS
        |  (always points to primary)     | flips to standby
        +---------------------------------+
```

Key facts:
- The standby is **not readable** (it's for failover, not read scaling). For reads, use **read replicas**.
- **Failover is automatic** on: primary failure, AZ outage, instance type change, OS patching, manual reboot-with-failover.
- Failover time: typically **60–120 seconds** (the endpoint DNS is repointed to the standby).
- Multi-AZ roughly **doubles cost** (you pay for the standby) but adds no read capacity.

### Multi-AZ Instance vs Multi-AZ Cluster
- **Multi-AZ DB Instance** (1 standby) — classic, standby not readable.
- **Multi-AZ DB Cluster** (2 readable standbys across 3 AZs) — faster failover (~35s) and the standbys *can* serve reads. Available for MySQL/PostgreSQL on newer versions.

⚠️ Multi-AZ is **not a backup** and **not disaster recovery** — both replicas are in the same Region. For DR across Regions, use cross-region read replicas or cross-region snapshot copies ([Module 6](06-backup-and-disaster-recovery.md)).

---

## 4. Read Replicas

**Read replicas = read scaling.** RDS creates **asynchronous** copies of your primary that serve **read-only** traffic. Offload reporting, analytics, and heavy `SELECT`s from the primary.

```
   +-----------+    async     +-------------+
   |  PRIMARY  | -----------> | Read Replica 1 | (app reporting)
   | (R/W)     | -----------> | Read Replica 2 | (analytics)
   +-----------+ -----------> | Read Replica 3 | (cross-region DR)
```

Key facts:
- Up to **15 read replicas** per primary (5 for older MySQL/MariaDB; 15 for newer).
- **Asynchronous** → expect **replica lag** (monitor `ReplicaLag`). Reads can be slightly stale.
- Replicas have **their own endpoints** — your app must explicitly route reads to them.
- Can be in the **same AZ, different AZ, or different Region** (cross-region replica = DR + low-latency local reads).
- A replica can be **promoted** to a standalone primary (breaks replication) — useful for DR failover or migration.
- Replicas can have **different instance classes** and even their own read replicas (MySQL).

| | Multi-AZ | Read Replica |
|---|---|---|
| Purpose | High availability / failover | Read scaling |
| Replication | Synchronous | Asynchronous |
| Readable? | No | **Yes** |
| Same Region? | Yes (different AZ) | Same or cross-Region |
| Automatic failover? | Yes | No (manual promote) |

🛠️ Create a read replica:
```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier hrms-db-replica \
  --source-db-instance-identifier hrms-db \
  --db-instance-class db.t3.medium
```

💡 Combine both: **Multi-AZ primary for HA + read replicas for scale.** That's the standard production shape.

---

## 5. Parameter Groups

A **parameter group** is RDS's equivalent of `my.cnf` / `postgresql.conf`. It's how you tune engine settings without OS access.

- **Default parameter group** — read-only; you cannot edit it. To customize, create a **custom parameter group** and attach it.
- Two parameter apply types:
  - **dynamic** — apply immediately (no reboot), e.g. `max_connections`.
  - **static** — require an instance **reboot**, e.g. `innodb_buffer_pool_size` only when set as a fixed value.
- Values can use **formulas** referencing instance memory, e.g. `{DBInstanceClassMemory*3/4}` for `innodb_buffer_pool_size`.

Common MySQL parameters to know:
| Parameter | Purpose |
|---|---|
| `max_connections` | Max concurrent connections (default is a formula of RAM) |
| `innodb_buffer_pool_size` | Memory for caching data/indexes — biggest perf lever |
| `slow_query_log` + `long_query_time` | Capture slow queries |
| `time_zone` | Server time zone (default UTC) |
| `character_set_server` / `collation_server` | Default charset (use `utf8mb4`) |
| `general_log` | Log all queries (debug only — heavy) |

🛠️ Create and apply:
```bash
aws rds create-db-parameter-group \
  --db-parameter-group-name hrms-mysql8 \
  --db-parameter-group-family mysql8.0 \
  --description "HRMS MySQL 8 tuning"

aws rds modify-db-parameter-group \
  --db-parameter-group-name hrms-mysql8 \
  --parameters "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
               "ParameterName=long_query_time,ParameterValue=2,ApplyMethod=immediate"

aws rds modify-db-instance \
  --db-instance-identifier hrms-db \
  --db-parameter-group-name hrms-mysql8 --apply-immediately
```
⚠️ Attaching a new parameter group shows status `pending-reboot` for static params — they don't take effect until you reboot.

**Option Groups** (related): enable optional engine features/plugins — e.g., MySQL `MEMCACHED`, MariaDB audit plugin, Oracle/SQL Server options. Many MySQL setups don't need a custom option group.

---

## 6. Backups (Automated Backups)

RDS **automated backups** let you restore to any point in your retention window.

- **Retention:** 0–35 days (0 disables automated backups — never do this in prod). Default 7.
- **Backup window:** a daily 30-min window where a full storage snapshot is taken. Transaction logs are captured continuously (every ~5 min) → enables PITR.
- Backups are stored in **S3** (managed by AWS, you don't see the bucket).
- 💰 Backup storage equal to your DB size is **free**; beyond that you pay per GB-month.
- ⚠️ Automated backups are **deleted when you delete the instance** (unless you take a final snapshot). Snapshots are manual and persist.
- Multi-AZ: backups are taken from the **standby**, so no I/O hit on the primary.

🛠️ Enable / change retention:
```bash
aws rds modify-db-instance --db-instance-identifier hrms-db \
  --backup-retention-period 7 \
  --preferred-backup-window 03:00-03:30 --apply-immediately
```

---

## 7. Snapshots

A **DB snapshot** is a **manual, user-initiated** full backup that lives until *you* delete it.

| | Automated backup | Manual snapshot |
|---|---|---|
| Triggered by | RDS (daily) | You (on demand) |
| Lifetime | Retention window (max 35d) | **Until you delete it** |
| Enables PITR? | Yes | No (restore to that exact point only) |
| Deleted with instance? | Yes | **No** (persists) |
| Cross-region/account copy? | Via snapshot copy | Yes |

Key operations:
- **Take a snapshot** before risky changes (schema migration, major upgrade).
- **Restore** a snapshot → always creates a **brand-new instance** (you never restore in place). Update your app's endpoint afterward.
- **Copy** a snapshot to another Region (DR) or another account.
- **Share** a snapshot with another AWS account.
- **Encrypted** snapshots stay encrypted; copies can re-encrypt with a different KMS key.

🛠️
```bash
aws rds create-db-snapshot \
  --db-instance-identifier hrms-db \
  --db-snapshot-identifier hrms-db-before-migration

aws rds copy-db-snapshot \
  --source-db-snapshot-identifier hrms-db-before-migration \
  --target-db-snapshot-identifier hrms-db-dr-copy \
  --source-region us-east-1 --region us-west-2 \
  --kms-key-id alias/rds-dr-key

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier hrms-db-restored \
  --db-snapshot-identifier hrms-db-before-migration
```

---

## 8. Point-in-Time Recovery (PITR)

**PITR** lets you restore to **any second** within your backup retention window (down to ~5 minutes of the present), by replaying transaction logs onto the latest snapshot.

```
  daily snapshot        transaction logs (every ~5 min)
  ----O--------------------|----|----|----|----|----> now
      |<--------- choose any point in here -------->|
                         restore to 14:32:07
```

- Use it to recover from a **bad write / accidental `DELETE` / dropped table** — restore to the second *before* the mistake.
- Restores to a **new instance** (never in place). The "latest restorable time" is usually ~5 minutes ago.
- Requires automated backups enabled (retention > 0).

🛠️
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier hrms-db \
  --target-db-instance-identifier hrms-db-pitr \
  --restore-time 2026-06-17T14:32:07Z
```
💡 Workflow after the "oops `DELETE`": PITR to a new instance → extract the lost rows → re-insert into prod (or cut over to the restored instance). Don't drop prod first.

---

## 9. Failover

**Failover** = promoting the standby (Multi-AZ) to primary when the primary becomes unhealthy.

What triggers it:
- Primary instance or underlying host failure
- AZ outage
- Storage failure
- Manual: `reboot --force-failover`
- During patching / instance class modification (with Multi-AZ, AWS fails over to minimize downtime)

How it works:
1. RDS detects the primary is unhealthy.
2. The **CNAME endpoint** is repointed from the old primary to the standby.
3. Standby becomes the new primary; a new standby is provisioned in the background.

⚠️ **Application implications:**
- The endpoint DNS stays the same, but the IP behind it changes → ensure your app/driver **doesn't cache DNS forever** (set a low JVM/driver DNS TTL; reconnect on error).
- In-flight connections **drop** — your app must **retry** transactions. Use connection pools that detect dead connections.
- Typical downtime: **60–120s** (instance Multi-AZ) or **~35s** (Multi-AZ cluster).

🛠️ Test failover deliberately (recommended before go-live):
```bash
aws rds reboot-db-instance --db-instance-identifier hrms-db --force-failover
```
Watch the `RDS-EVENT-0006`/`0049` events and confirm your app reconnects.

---

## 10. Monitoring

Three layers:

1. **CloudWatch metrics** (free, 1-min) — instance-level:
   - `CPUUtilization`, `FreeableMemory`, `FreeStorageSpace`
   - `DatabaseConnections`, `ReadIOPS`/`WriteIOPS`, `ReadLatency`/`WriteLatency`
   - `ReplicaLag` (read replicas), `BurstBalance` (gp2/t-class credits)
2. **Enhanced Monitoring** — OS-level metrics (per-process CPU, memory, disk) at up to 1-second granularity (small extra cost).
3. **Performance Insights** — query-level: which SQL statements consume the most **DB load (AAS — average active sessions)**, top waits, top users. 7 days of history free; longer is paid. **The single best tool for "why is my DB slow?"**

Plus:
- **RDS Events** — subscribe via SNS to failover, backup, low-storage, and maintenance events.
- **Slow query log / error log** — publish to **CloudWatch Logs** for retention and querying.

🛠️ Example alarm (low free storage):
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name hrms-db-low-storage \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-db \
  --statistic Average --period 300 --threshold 5000000000 \
  --comparison-operator LessThanThreshold --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:111122223333:dba-alerts
```

The metrics that page you at 3am: **FreeStorageSpace low, CPU pegged at 100%, DatabaseConnections near max_connections, ReplicaLag climbing.** See [Module 9](09-monitoring-guide.md).

---

## 11. Security

Security is layered — network, access, encryption, and audit.

### Network isolation
- 🔒 Put RDS in **private subnets**; set `--no-publicly-accessible`. The app tier (EC2) reaches it; the internet cannot.
- **Security group**: allow inbound 3306 (MySQL/MariaDB) or 5432 (PostgreSQL) **only from the app's security group** (not `0.0.0.0/0`).

```
   App SG (EC2)  --allow 3306-->  DB SG  --[only source = App SG]
   Internet ----X (no route to private subnet)
```

### Authentication & access
- **Master user** is created at launch — use it to bootstrap, then create least-privilege app users.
- 🔒 Prefer **IAM database authentication** (short-lived token instead of a static password) or **Secrets Manager** with automatic rotation (`--manage-master-user-password` stores the master secret in Secrets Manager and rotates it).
- Grant the app user only what it needs (`SELECT/INSERT/UPDATE/DELETE` on its schema), not `GRANT ALL`.

### Encryption
- **At rest:** enable **KMS encryption** at creation. ⚠️ You **cannot encrypt an existing unencrypted instance** in place — you must snapshot → copy snapshot with encryption → restore. Encryption covers the instance, backups, snapshots, and read replicas.
- **In transit:** enforce **TLS/SSL**. Download the **RDS CA bundle** and require SSL (`require_secure_transport=ON` for MySQL).

### Audit & compliance
- Publish **audit/error/slow logs** to CloudWatch Logs.
- Enable the **MariaDB/MySQL audit plugin** (via option group) for connection/query auditing.
- Use **AWS Config / CloudTrail** for API-level audit of who changed the DB.

🔒 Minimum production security checklist:
- [ ] Private subnets, `publicly-accessible = false`
- [ ] SG inbound restricted to app SG only
- [ ] Encryption at rest (KMS) enabled at creation
- [ ] TLS enforced in transit
- [ ] Credentials in Secrets Manager (rotated) or IAM auth — never hardcoded
- [ ] Automated backups ≥ 7 days + deletion protection on
- [ ] Logs exported to CloudWatch; alarms on CPU/storage/connections

---

## ✅ Module 1 Recap
- RDS = **managed** relational DB; no OS/SSH access — configure via **parameter groups**.
- **Multi-AZ** = HA (synchronous standby, auto failover, not readable). **Read replicas** = read scaling (async, readable, can be cross-region).
- **Automated backups** (retention-based, enable PITR) vs **snapshots** (manual, persist forever).
- **PITR** restores to any second in the window — to a **new** instance.
- Monitor with **CloudWatch + Performance Insights**; secure with **private subnets + SG + KMS + TLS + Secrets Manager**.

➡️ Next: [Module 2 — Engines: MySQL, PostgreSQL, MariaDB](02-engines-mysql-postgres-mariadb.md)

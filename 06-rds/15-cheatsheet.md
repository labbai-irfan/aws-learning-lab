# 15 — RDS Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-rds-core-concepts.md).

## What RDS is
Managed relational DB: AWS handles provisioning, patching, backups, and failover. **Engines:** MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, and **Aurora** (AWS's MySQL/PostgreSQL-compatible engine).

## Multi-AZ vs Read Replicas (the classic confusion)
| | **Multi-AZ** | **Read Replica** |
|---|---|---|
| Purpose | **High availability / failover** | **Read scaling** |
| Replication | Synchronous | Asynchronous |
| Standby usable? | No (passive, auto-failover) | Yes (serves reads) |
| Cross-Region? | (Multi-AZ = within Region) | Yes (also DR) |
| Failover | Automatic (DNS flips, ~60–120s) | Manual promote |
💡 Multi-AZ = **availability**; Read Replicas = **performance**. You can use both.

## Storage
- **gp3/gp2** general SSD · **io1/io2** high-IOPS for critical OLTP · **magnetic** legacy.
- Storage autoscaling grows capacity automatically.

## Backups & recovery
| Feature | Note |
|---|---|
| **Automated backups** | Daily snapshot + transaction logs → **PITR** (point-in-time, to ~5 min) |
| Retention | 0–35 days (0 disables) |
| **Manual snapshots** | Kept until you delete; shareable/copyable cross-Region |
| Restore | Always creates a **new** instance |

## Security
- Put RDS in **private subnets**; SG allows DB port (3306/5432) only from the app SG.
- **Encryption at rest** = KMS, enabled **at creation** (or restore an encrypted snapshot copy).
- **TLS** in transit; **IAM database authentication** (tokens instead of passwords); creds in **Secrets Manager** (auto-rotate).

## Aurora extras
- Storage auto-grows to 128 TB, 6 copies across 3 AZs; up to 15 low-lag read replicas.
- **Aurora Serverless v2** = auto-scaling capacity for spiky/variable loads.
- **Global Database** = cross-Region replication for DR + low-latency global reads.

## Connections & performance
- **RDS Proxy** = connection pooling (great for Lambda/serverless — avoids connection storms).
- Watch: `CPUUtilization`, `FreeableMemory`, `DatabaseConnections`, `Read/WriteLatency`, `FreeStorageSpace`.

## HRMS / Prisma note
- Migrate local MySQL → RDS via dump/restore or DMS; point Prisma `DATABASE_URL` at the RDS endpoint; use **RDS Proxy** if running serverless. ([04 — Migration](04-migration-from-local-mysql.md), [05 — Prisma & Pooling](05-prisma-and-connection-pooling.md))

## Exam triggers 💡
- "DB must survive an AZ outage automatically" → **Multi-AZ**.
- "Reads are the bottleneck" → **Read Replicas**.
- "Restore to 2:14 pm yesterday" → **PITR** (automated backups).
- "Too many DB connections from Lambda" → **RDS Proxy**.
- "Cross-Region DR + fast global reads" → **Aurora Global Database**.
- "Rotate DB password automatically" → **Secrets Manager**.
- "Spiky, unpredictable load, pay per use" → **Aurora Serverless v2**.

## Gotchas ⚠️
- Can't enable encryption on an existing unencrypted instance — **copy snapshot with encryption**, restore.
- Multi-AZ standby does **not** serve reads (that's a replica's job).
- Restores/replicas are **new endpoints** — update your app config.
- Backups retention `0` disables PITR.

---
*Back to [RDS README](README.md).*

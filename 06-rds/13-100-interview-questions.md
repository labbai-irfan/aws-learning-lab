# Module 13 — 100 RDS Interview Questions (with model answers)

> Grouped by theme. Answers are concise — expand with examples from the HRMS project in interviews.

---

## A. Fundamentals (1–15)
1. **What is Amazon RDS?** A managed relational DB service; AWS handles provisioning, patching, backups, replication, and failover while you own schema/queries/data.
2. **RDS vs running MySQL on EC2?** RDS automates ops (backups, Multi-AZ, patching) but gives no OS/SSH access; EC2 gives full control but you build/operate everything.
3. **Which engines does RDS support?** MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, and Aurora (MySQL/PG-compatible).
4. **What is a DB instance class?** The compute size (CPU/RAM/network), e.g. `db.t3.micro`, `db.r6g.large`.
5. **What is the endpoint and why connect to it (not an IP)?** The DNS name+port; IPs change on failover, the endpoint follows the active primary.
6. **What is a DB subnet group?** The set of subnets (≥2 AZs) where RDS can place instances; should be private.
7. **gp2 vs gp3 vs io2?** gp2 ties IOPS to size; gp3 decouples IOPS/throughput from size (modern default); io2 is high-IOPS low-latency provisioned.
8. **Can you shrink storage?** No — only grow. To shrink, dump/restore into a smaller instance.
9. **What is Graviton and why use it?** AWS ARM CPUs (`db.*g`) — ~20% cheaper and often faster.
10. **RDS vs Aurora?** Aurora = cloud-native distributed storage, faster failover, more replicas, serverless option, higher cost; RDS = standard engines, cheaper, simpler.
11. **What is RDS Custom?** RDS variant giving OS/DB access for legacy apps needing it.
12. **What is the maintenance window?** A weekly window when AWS applies patches/minor upgrades.
13. **Minor vs major version upgrade?** Minor = low-risk, can auto-apply; major = manual, test first, snapshot before.
14. **What is deletion protection?** A flag preventing accidental instance deletion.
15. **What does "managed" NOT include?** Schema design, indexing, query tuning, data modeling — still yours.

## B. Multi-AZ & Failover (16–30)
16. **What is Multi-AZ?** Synchronous standby in another AZ for HA with automatic failover.
17. **Is the standby readable?** No (instance deployment) — use read replicas for reads.
18. **Sync vs async replication here?** Multi-AZ = synchronous; read replicas = asynchronous.
19. **What triggers failover?** Host/AZ failure, storage failure, instance modification, patching, forced reboot.
20. **Failover time?** ~60–120s (instance), ~35s (Multi-AZ cluster).
21. **How does the app find the new primary?** Endpoint CNAME repoints to the standby automatically.
22. **App-side requirements for clean failover?** Low DNS TTL, transaction retry logic, pool that drops dead connections, or RDS Proxy.
23. **Multi-AZ instance vs cluster?** Cluster has 2 readable standbys across 3 AZs and faster failover.
24. **Does Multi-AZ add read capacity?** No.
25. **Does Multi-AZ protect against accidental DELETE?** No — that's PITR/snapshots.
26. **Does Multi-AZ protect against Region failure?** No — same Region; use cross-region replica/snapshots.
27. **Where are backups taken in Multi-AZ?** From the standby, avoiding primary I/O impact.
28. **Cost of Multi-AZ?** ~2× (you pay for the standby).
29. **How to test failover?** `reboot-db-instance --force-failover`.
30. **What happens to in-flight connections at failover?** They drop; the app must reconnect/retry.

## C. Read Replicas (31–42)
31. **Purpose of read replicas?** Read scaling and offloading reporting/analytics.
32. **Replication type?** Asynchronous → expect ReplicaLag.
33. **Max replicas?** Up to 15 (modern engines).
34. **Cross-region replica use cases?** Local low-latency reads + DR.
35. **Can a replica be promoted?** Yes — becomes a standalone primary, breaking replication.
36. **Replica vs Multi-AZ?** Replica = async, readable, scaling; Multi-AZ = sync, not readable, HA.
37. **What is replica lag and how to reduce it?** Delay applying primary changes; reduce by sizing the replica properly, limiting long queries, smoothing write bursts.
38. **Can you write to a replica?** No (read-only) unless promoted.
39. **How to route reads to replicas in code?** Separate connection/client per endpoint or a read-replica routing layer.
40. **Read-after-write consistency concern?** Reading from a lagging replica may miss just-written data — route such reads to primary.
41. **Can replicas have different instance classes?** Yes.
42. **How to scale writes (replicas don't help)?** Vertical scale, Aurora, sharding, or caching/CQRS.

## D. Parameter & Option Groups (43–50)
43. **What is a parameter group?** Engine config (like my.cnf) managed without OS access.
44. **Why custom parameter group?** Default is read-only; create a custom one to tune.
45. **Static vs dynamic parameters?** Static needs a reboot; dynamic applies immediately.
46. **Important MySQL params to tune?** `innodb_buffer_pool_size`, `max_connections`, `slow_query_log`, charset, `time_zone`.
47. **What is an option group?** Enables optional engine features/plugins (e.g., audit plugin).
48. **Parameter formulas?** Values like `{DBInstanceClassMemory*3/4}` scale with instance size.
49. **How to enforce TLS via parameters?** `require_secure_transport=ON` (MySQL) / `rds.force_ssl=1` (PG).
50. **Why might a parameter not take effect?** It's static and the instance hasn't been rebooted (pending-reboot).

## E. Backups, Snapshots, PITR (51–66)
51. **Automated backups vs snapshots?** Automated = RDS-managed, retention-bound, enable PITR, deleted with instance; snapshots = manual, persist until deleted.
52. **Backup retention range?** 0–35 days (0 disables; never in prod).
53. **What enables PITR?** Automated backups (retention>0) + continuous transaction logs.
54. **PITR granularity?** Any second within the window, up to ~5 min ago.
55. **Restore behavior?** Always creates a new instance; repoint the app afterward.
56. **Restored instance config gotcha?** Comes with default parameter group/SG — reattach yours.
57. **Cross-region snapshot copy + KMS?** Keys are regional → re-encrypt with a target-Region key.
58. **How to recover from a bad DELETE?** PITR to just before it, extract rows, re-insert (don't drop prod).
59. **Snapshot before what events?** Schema migrations and major upgrades.
60. **Backup storage cost?** Free up to DB size; beyond is GB-month.
61. **AWS Backup role?** Centralized cross-region/cross-account backup policy by tag.
62. **What's the backup window?** Daily 30-min window for the full backup; logs continuous.
63. **Can you make a snapshot public?** Yes but never should — exposes all data.
64. **Difference: copy vs share snapshot?** Copy = new snapshot (possibly cross-region/re-encrypt); share = grant another account access.
65. **Export snapshot to S3?** Yes (Parquet) for analytics/long-term retention.
66. **What is the "latest restorable time"?** ~5 minutes ago — the newest PITR target.

## F. Migration (67–76)
67. **Two main migration approaches?** mysqldump (downtime) and DMS (near-zero downtime, full load + CDC).
68. **Why --set-gtid-purged=OFF?** Avoid GTID errors importing into RDS.
69. **SUPER privilege issue?** RDS forbids SUPER → strip DEFINER clauses from dumps.
70. **What does DMS CDC need?** Source binlog in ROW format with retention.
71. **How to validate a migration?** Row counts, checksums, app integration tests, charset/FK checks; DMS data validation.
72. **Common charset pitfall?** latin1 → utf8mb4 corruption; convert explicitly.
73. **Why migrate from EC2 to RDS?** Offload ops, get Multi-AZ/PITR/monitoring out of the box.
74. **Schema vs data in DMS?** DMS moves data well but pre-create schema (SCT or `mysqldump --no-data`).
75. **How to cut over with minimal downtime?** DMS keeps sync; stop writes, drain CDC, repoint app.
76. **Where to run the dump/import?** From EC2 in the same Region/AZ, not a laptop.

## G. Prisma & Connection Pooling (77–86)
77. **What is connection pooling and why care on RDS?** Reusing DB connections; RDS max_connections is RAM-bound — too many connections error out.
78. **Prisma connection_limit default and override?** Default `cpus*2+1`; set explicitly in the URL.
79. **Connection budget rule?** `app_instances × connection_limit < max_connections` with headroom.
80. **What is RDS Proxy and when to use it?** Managed pooler; use for Lambda/large fleets and faster failover.
81. **Lambda + Prisma pitfall?** Each concurrent function = own pool → connection storm; use RDS Proxy + small limit.
82. **migrate dev vs deploy?** `dev` is interactive/local (can reset); `deploy` is prod-safe and non-interactive.
83. **Read/write splitting in Prisma?** Two clients or the read-replica extension; keep read-after-write on primary.
84. **Secure credentials with Prisma?** Fetch from Secrets Manager at startup; never commit `.env`.
85. **Enforce TLS in Prisma?** `sslaccept=strict` with the RDS CA bundle.
86. **Graceful shutdown?** `await prisma.$disconnect()` on SIGTERM to release connections.

## H. Monitoring & Performance (87–93)
87. **CloudWatch vs Performance Insights?** CloudWatch = instance health; PI = which SQL causes load (AAS).
88. **Top metrics to alarm on?** CPU, FreeStorageSpace, FreeableMemory, DatabaseConnections, ReplicaLag.
89. **How to find a slow query?** Enable slow query log + PI Top SQL → EXPLAIN → add index/rewrite.
90. **What does EXPLAIN type=ALL mean?** Full table scan — likely a missing index.
91. **Enhanced Monitoring vs CloudWatch?** Enhanced = OS-level per-process, 1s granularity.
92. **What is AAS?** Average Active Sessions; > vCPU count means queuing/bottleneck.
93. **How to get notified of failover?** RDS event subscription → SNS.

## I. Security (94–100)
94. **How to network-secure RDS?** Private subnets, no public access, SG inbound only from app SG.
95. **Encryption at rest?** KMS, enabled at creation; covers backups/snapshots/replicas.
96. **Encrypt an existing unencrypted DB?** Snapshot → copy with encryption → restore.
97. **IAM database authentication?** Short-lived tokens instead of static passwords; grant `rds-db:connect`.
98. **Secrets Manager integration?** `--manage-master-user-password` stores+rotates the master secret.
99. **Least-privilege app user?** Grant only needed DML on its schema; don't use the master user.
100. **#1 RDS security mistake?** Public accessibility + open `0.0.0.0/0` security group.

➡️ Next: [Module 14 — 50 Production Scenarios](14-50-scenario-questions.md)

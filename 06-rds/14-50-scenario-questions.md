# Module 14 — 50 Production Scenarios

> Real situations. Read the scenario, decide your move, then check the recommended answer.

---

### Availability & Failover
1. **Prod MySQL is single-AZ; CFO wants 99.95% uptime.** → Enable Multi-AZ (synchronous standby, auto-failover). Test with forced failover; add app retry logic.
2. **App throws errors for 90s every time AWS patches the DB.** → That's failover; lower DNS TTL, add transaction retries, or front with RDS Proxy to hold connections.
3. **After a failover, the app kept hitting the old primary IP.** → Driver cached DNS; set short `networkaddress.cache.ttl`, reconnect on error, use the endpoint not an IP.
4. **You need the standby to also serve reads.** → Multi-AZ instance standby isn't readable; use a read replica, or switch to Multi-AZ DB Cluster (readable standbys).
5. **Whole AZ went down; was the DB safe?** → If Multi-AZ, it failed over to the other AZ automatically; single-AZ would be down.

### Read Scaling
6. **Reporting dashboards slow the OLTP primary to a crawl.** → Add a read replica; route reporting `SELECT`s to it.
7. **Replica lag spikes to minutes during nightly batch.** → Replica undersized or write burst; upsize replica, throttle/spread the batch, avoid huge transactions.
8. **A report shows data that's a few seconds stale.** → Expected (async replica). For fresh reads, hit the primary.
9. **Writes are the bottleneck, not reads.** → Replicas won't help; scale up instance, consider Aurora or sharding, add caching.
10. **Need low-latency reads in Europe for a US DB.** → Cross-region read replica in eu-west-1.

### Backups, Snapshots, PITR
11. **An engineer ran `DELETE FROM payroll` without WHERE 15 min ago.** → PITR to just before it on a new instance, extract rows, re-insert; don't drop prod.
12. **You deleted an instance and lost its automated backups.** → Automated backups go with the instance; always take a final snapshot. Restore from any prior manual snapshot.
13. **Compliance needs 7-year retention.** → Export snapshots to S3 (Parquet) / lifecycle to Glacier via AWS Backup; automated retention maxes at 35d.
14. **Need a sanitized copy of prod for staging.** → Restore the latest prod snapshot to a new instance, scrub PII, point staging at it.
15. **PITR fails for a time 40 days ago.** → Outside retention (max 35d). Use the nearest snapshot instead; raise retention going forward.
16. **Cross-region snapshot copy errors on encryption.** → KMS keys are regional; specify a target-Region KMS key in the copy.
17. **Restored instance is suddenly slow and single-AZ.** → Restores use default param group, default SG, single-AZ; reattach your param group, SG, enable Multi-AZ/backups.

### Migration
18. **Migrate a 5 GB local MySQL with a 1-hour window.** → mysqldump `--single-transaction --set-gtid-purged=OFF`, import from an EC2 in-Region, repoint app.
19. **Migrate a 2 TB DB with zero downtime.** → AWS DMS full load + CDC; pre-create schema; validate; cut over after CDC drains.
20. **Import fails: "Access denied; you need SUPER".** → Strip `DEFINER=` clauses from the dump.
21. **Imported data shows ??? instead of accents.** → Charset mismatch; convert source to utf8mb4 before/at import.
22. **`LOAD DATA LOCAL INFILE` blocked on RDS.** → Enable `local_infile` in the parameter group.
23. **After migration, app users can't log in.** → Single-DB dumps don't carry users/grants; recreate app users on RDS.

### Prisma / Connections
24. **App fails under load with "Too many connections".** → Add pooling (`connection_limit`), ensure `instances × limit < max_connections`, or add RDS Proxy.
25. **Serverless app exhausts DB connections during spikes.** → RDS Proxy + `connection_limit=1`; multiplexes safely.
26. **Migrations sometimes wiped staging data.** → Someone ran `migrate dev`/`db push --force-reset`; use `migrate deploy` in CI only.
27. **DB password leaked from a committed `.env`.** → Rotate via Secrets Manager, remove from history, fetch creds at runtime, restrict SG.
28. **Read-after-write bug: user updates profile, sees old data.** → Reads hitting a lagging replica; route read-after-write to the primary client.
29. **Connections leak and climb until restart.** → Missing `$disconnect`/unclosed connections; fix lifecycle, add `pool_timeout`, graceful shutdown.

### Performance
30. **CPU pinned at 100% during business hours.** → PI Top SQL → find scans → add indexes/rewrite; if truly maxed, scale up class.
31. **Queries slow only on big tables.** → Missing/!selective indexes; EXPLAIN, add composite index, avoid `SELECT *`.
32. **FreeableMemory keeps dropping, swap rising.** → `innodb_buffer_pool_size` too high or too many connections; reduce, or move to `db.r*`.
33. **ReadLatency high though CPU is fine.** → I/O bound; move to gp3 with more IOPS or io2.
34. **t3 instance randomly slow then fine.** → Burst credits (BurstBalance/CPUCreditBalance) exhausted; move to gp3 + non-burstable class.
35. **Storage hit 0% and DB went read-only.** → Enable storage autoscaling, grow allocated storage, find growth (binlogs/temp/data).

### Security
36. **Security audit flags the DB as publicly accessible.** → Set `publicly-accessible=false`, move to private subnets, restrict SG to app SG.
37. **SG allows 3306 from 0.0.0.0/0.** → Replace with source = app SG only; use SSM/bastion for DBA access.
38. **Need encryption on an existing unencrypted prod DB.** → Snapshot → copy with KMS encryption → restore → cut over.
39. **Auditors want to know who can decrypt backups.** → Customer-managed KMS key with a tight key policy; review CloudTrail.
40. **App connects without TLS over the network.** → Enforce `require_secure_transport=ON`, ship CA bundle, `sslaccept=strict`.
41. **Want passwordless DB auth for EC2.** → IAM database authentication; grant role `rds-db:connect`, create IAM-auth DB user.
42. **Someone almost deleted prod via console.** → Enable deletion protection + require final snapshot; tighten IAM.

### Cost
43. **RDS bill doubled after enabling HA.** → Multi-AZ ≈ 2×; keep it for prod, use single-AZ for dev/test.
44. **Steady prod on on-demand pricing.** → Buy Reserved Instances (1/3-yr) after sizing stabilizes; ~up to 60% off.
45. **Dev DBs run 24/7 but used 9–5.** → Stop instances off-hours / schedule start-stop; single-AZ dev.
46. **Old snapshots piling up storage cost.** → Lifecycle/delete orphan manual snapshots; use AWS Backup retention rules.
47. **Over-provisioned db.r6g.2xlarge at 15% CPU.** → Right-size down a step or two; verify memory/connections headroom first.
48. **High I/O charges (Aurora).** → Consider Aurora I/O-Optimized for predictable pricing.

### DR
49. **Region us-east-1 outage; need to recover in another Region.** → Promote the cross-region read replica (or restore a copied snapshot), repoint Route 53/app, rebuild HA.
50. **Leadership asks "what's our RPO/RTO?" and nobody knows.** → Define targets, run a DR game day (restore/promote in isolated VPC), measure actual RTO/RPO, write the runbook.

➡️ Next: [Capstone Project — HRMS MySQL on RDS](project/README.md)

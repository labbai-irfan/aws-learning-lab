# Module 10 — RDS Troubleshooting Guide

> The errors you'll actually hit, the root cause, and the fix. Organized by symptom.

**Legend:** 🔎 diagnose · 🛠️ fix · ⚠️ gotcha

---

## Connectivity

### "Can't connect to RDS" / connection timeout
🔎 Most common cause is **network/SG**, not the DB.
- Is the instance **publicly accessible** and are you outside the VPC? For private instances connect from EC2 in the VPC / via bastion/VPN.
- **Security group**: does DB-SG allow your source on 3306/5432?
- **Subnet/route**: is the client in a subnet that can route to the DB subnet?
- **NACLs**: do they allow the ephemeral return ports?
🛠️ From the app instance: `nc -zv <endpoint> 3306` (or `telnet`). If it hangs → network/SG. If it connects but auth fails → credentials.

### "Access denied for user"
🔎 Wrong user/password, or host restriction (`'user'@'10.0.%'` vs `'%'`).
🛠️ Verify creds (Secrets Manager), confirm the user's host pattern, re-`GRANT` if needed. Check `require_secure_transport` — connecting without TLS when it's forced = denied.

### "Too many connections" / `P1001`
🔎 `DatabaseConnections` at `max_connections`. Connection leak or no pooling.
🛠️ Add pooling (Prisma `connection_limit`), put **RDS Proxy** in front, fix leaked connections (always close), raise `max_connections` only as a stopgap (RAM-bound). See [Module 5](05-prisma-and-connection-pooling.md).

---

## Performance

### High CPU (near 100%)
🔎 Performance Insights → Top SQL. Usually a missing index → full table scans.
🛠️ `EXPLAIN` the top query, add the index, rewrite. If genuinely under-provisioned, scale up the instance class.

### Slow queries / high latency
🔎 Enable slow query log; check `Using filesort`/`Using temporary`/`type=ALL` in EXPLAIN. Check `ReadLatency` for I/O bottleneck.
🛠️ Indexes, query rewrite, increase `innodb_buffer_pool_size` (parameter group), add IOPS (gp3/io2), add a read replica / cache for reads.

### Out of memory / swapping
🔎 `FreeableMemory` low, `SwapUsage` rising.
🛠️ `innodb_buffer_pool_size` set too high relative to RAM? Reduce, or scale to a memory-optimized class (`db.r*`). Reduce per-connection buffers, reduce connection count.

### Replica lag climbing
🔎 `ReplicaLag` rising — replica can't keep up.
🛠️ Replica often undersized vs primary → match/upsize the replica class; reduce long-running replica queries; large write bursts on primary cause temporary lag. Don't read-after-write from a lagging replica.

---

## Storage

### "Storage full" / instance in `storage-full` state
🔎 `FreeStorageSpace` ≈ 0. The DB may become read-only/unavailable.
🛠️ Enable **storage autoscaling**, or `modify-db-instance --allocated-storage` to grow. Investigate growth: binlogs, large temp tables, unpurged data. ⚠️ You can grow but **never shrink** storage in place.

### Storage keeps growing unexpectedly
🔎 Binary logs, slow-query/general logs, bloated temp tables, or `binlog_retention_hours` too high.
🛠️ Tune log retention, purge old data, archive to S3.

---

## Backups / Restore / Failover

### Restore "didn't work" — config missing
⚠️ A restored instance creates a **new instance** with the **default** parameter/option group, default SG, and **may default to single-AZ / backups off**. Re-apply your parameter group, SG, Multi-AZ, backup retention, then repoint the app.

### PITR can't reach the time I want
🔎 The time is outside retention, or earlier than `EarliestRestorableTime`, or automated backups were disabled (retention 0).
🛠️ Keep retention ≥7d; you can only PITR within the window and not closer than ~5 min to now.

### Cross-region snapshot copy fails
⚠️ **KMS keys are regional.** Re-encrypt with a key in the **target** Region during copy (`--kms-key-id <target-region-key>`).

### App didn't recover after failover
🔎 Driver cached DNS or didn't retry.
🛠️ Lower DNS TTL/JVM `networkaddress.cache.ttl`, add transaction **retry logic**, use a pool that detects dead connections or **RDS Proxy** (holds connections through failover). Test with `reboot-db-instance --force-failover`.

---

## Migration-specific (see [Module 4](04-migration-from-local-mysql.md))
- **`ERROR ... SUPER privilege`** on import → strip `DEFINER=` clauses.
- **GTID errors** → `mysqldump --set-gtid-purged=OFF`.
- **Garbled characters** → charset mismatch; convert source to `utf8mb4`.
- **`LOAD DATA LOCAL INFILE` blocked** → enable `local_infile` parameter.

---

## Upgrades
- **Major version upgrade failed pre-check** → review the pre-upgrade log in CloudWatch; fix deprecated syntax/objects; rehearse on a restored clone first.
- ⚠️ Take a **snapshot before any major upgrade**.

---

## Quick triage flow
```
Can't connect?        -> SG / subnet / public-access / TLS
Slow?                 -> Performance Insights -> Top SQL -> EXPLAIN -> index
Errors under load?    -> connections maxed -> pooling / RDS Proxy
Storage full?         -> autoscaling / grow / find the growth
After failover down?  -> DNS TTL + retry logic + RDS Proxy
Restore weird?        -> reattach param group / SG / Multi-AZ
```

➡️ Next: [Module 11 — Hands-on Labs](11-labs.md)

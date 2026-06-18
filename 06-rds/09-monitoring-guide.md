# Module 9 — Monitoring & Performance

> The metrics, tools, and alarms that keep RDS healthy — and how to find the slow query when it's 3am.

---

## 1. The three monitoring tools

| Tool | Granularity | Answers |
|---|---|---|
| **CloudWatch metrics** | 1 min, free | Is the instance healthy? (CPU, memory, storage, connections, IOPS) |
| **Enhanced Monitoring** | up to 1 sec | OS-level: per-process CPU/mem, load avg, disk — beyond the hypervisor view |
| **Performance Insights** | per query | *Which SQL* is causing load? Top waits, top SQL, top users |

💡 **CloudWatch tells you the DB is slow; Performance Insights tells you why.**

---

## 2. Key CloudWatch metrics & what they mean

| Metric | Watch for | Likely cause |
|---|---|---|
| `CPUUtilization` | sustained >80% | inefficient queries, missing indexes, undersized instance |
| `FreeableMemory` | dropping near 0 | buffer pool too large, too many connections, memory-heavy sorts |
| `FreeStorageSpace` | < ~10% | growth, binlogs, temp tables — **autoscale or alarm** |
| `DatabaseConnections` | near `max_connections` | connection leak, no pooling → add RDS Proxy |
| `ReadLatency`/`WriteLatency` | rising (ms) | I/O bottleneck → more IOPS / io2 |
| `ReadIOPS`/`WriteIOPS` | at provisioned ceiling | hitting gp3/io limits |
| `ReplicaLag` | climbing | replica undersized / write spike on primary |
| `BurstBalance` | nearing 0 (t-class/gp2) | burst credits exhausted → larger class / gp3 |
| `SwapUsage` | > 0 and rising | memory pressure |
| `DiskQueueDepth` | high | storage saturated |

---

## 3. Performance Insights (PI)
- Central metric: **DB Load** measured in **AAS (Average Active Sessions)**. If AAS > vCPU count, sessions are queuing → bottleneck.
- Slice DB Load by **Wait** (CPU vs lock vs I/O), **Top SQL**, **User**, **Host**.
- Workflow: spot the spike → top SQL → copy the statement → `EXPLAIN` it → add index / rewrite.
- 7 days history free; up to 2 years paid.

```
   DB Load (AAS)
    | ███ lock waits  ← contention
    | ▓▓▓ CPU         ← heavy compute / missing index
    | ░░░ I/O         ← under-provisioned storage
    +------------------------- time
```

---

## 4. Finding & fixing slow queries (MySQL)
1. Enable slow query log via parameter group:
   - `slow_query_log=1`, `long_query_time=2`, optionally `log_queries_not_using_indexes=1`.
2. Ship logs to **CloudWatch Logs** (`Log exports`).
3. Analyze top offenders (PI Top SQL or `mysqldumpslow` on the log).
4. `EXPLAIN` the query → look for `type=ALL` (full scan), high `rows`, `Using filesort`/`Using temporary`.
5. Add the right **index**, rewrite the query, or add caching.

```sql
SQL> EXPLAIN SELECT * FROM employees WHERE email = 'a@b.com';
-- type=ALL, rows=50000  -> missing index
SQL> CREATE INDEX idx_employees_email ON employees(email);
```

---

## 5. Alarms that should page you

🛠️ Examples:
```bash
# CPU sustained high
aws cloudwatch put-metric-alarm --alarm-name hrms-db-cpu \
  --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-db \
  --statistic Average --period 300 --threshold 80 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 3 \
  --alarm-actions arn:aws:sns:us-east-1:111122223333:dba-alerts

# Connections near max
aws cloudwatch put-metric-alarm --alarm-name hrms-db-connections \
  --namespace AWS/RDS --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-db \
  --statistic Maximum --period 60 --threshold 250 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:111122223333:dba-alerts
```
Minimum alarm set: **CPU, FreeStorageSpace, FreeableMemory, DatabaseConnections, ReplicaLag**, and **RDS events** (failover, low storage, backup failure) via SNS.

## 6. RDS Event subscriptions
```bash
aws rds create-event-subscription \
  --subscription-name hrms-db-events \
  --sns-topic-arn arn:aws:sns:us-east-1:111122223333:dba-alerts \
  --source-type db-instance --source-ids hrms-db \
  --event-categories availability failover low-storage maintenance
```

---

## 7. Monitoring checklist
- [ ] Performance Insights ON
- [ ] Enhanced Monitoring ON (1–5s) for prod
- [ ] Slow query + error logs → CloudWatch Logs
- [ ] Alarms: CPU, storage, memory, connections, replica lag
- [ ] Event subscription for failover/low-storage/backup-failed
- [ ] Dashboard with the key metrics per instance
- [ ] Periodic `EXPLAIN` review of top SQL from PI

➡️ Next: [Module 10 — Troubleshooting Guide](10-troubleshooting-guide.md)

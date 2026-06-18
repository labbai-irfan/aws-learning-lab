# Module 10 — Incident Examples

> Realistic incidents walked end-to-end: the alert, the CloudWatch investigation, the root cause, the fix, and the prevention. This is what CloudWatch is *for*.

Each follows: 🚨 **Alert** → 🔎 **Investigate** → 🎯 **Root cause** → 🛠️ **Fix** → 🛡️ **Prevent**.

---

## Incident 1 — API 5xx spike after a deploy
🚨 `hrms-api-5xx-high` (Sev1): 5xx rate 6% for 5 min.
🔎 Dashboard shows 5xx started at 14:02 — same time as a CodeDeploy event (EventBridge annotation). Logs Insights:
```
filter statusCode >= 500 | stats count(*) by route, errorMessage | sort count desc
```
→ all errors on `/api/payroll`, message `Cannot read property 'id' of undefined`.
🎯 Root cause: new build introduced a null-deref on a code path the tests missed.
🛠️ Roll back the deployment; 5xx returns to 0; alarm clears.
🛡️ Add canary on `/api/payroll`; composite alarm `5xx AND latency`; auto-rollback on 5xx>2% post-deploy.

## Incident 2 — Site slow, users complaining, CPU "fine"
🚨 `hrms-api-latency-p99-high` (Sev2): p99 4.2s.
🔎 EC2 CPU 45% (looks fine). RDS dashboard: `DatabaseConnections` near max, `CPUUtilization` 95%. Performance Insights Top SQL → one unindexed `SELECT ... WHERE email=?` dominating DB load.
🎯 Root cause: missing index → full table scans saturating the DB; app threads block waiting on DB → high latency despite low app CPU.
🛠️ `CREATE INDEX idx_employees_email ON employees(email);` → DB CPU drops, p99 back to 180ms.
🛡️ Alarm on RDS CPU + connections; enable slow query log → metric filter → alarm; review Top SQL weekly.

## Incident 3 — Disk full, app crashing intermittently
🚨 `hrms-ec2-disk-high` (Sev2) then `StatusCheckFailed`.
🔎 Agent `disk_used_percent` climbed to 98%. Logs show `ENOSPC: no space left on device`. The growth: an app log file never rotated + verbose DEBUG logging.
🎯 Root cause: local logging filled the root volume.
🛠️ Rotate/truncate logs, ship to CloudWatch instead of disk, expand volume.
🛡️ logrotate; ship logs to CloudWatch (not local disk); alarm at 80% disk; set log level to INFO.

## Incident 4 — Database storage almost full
🚨 `hrms-db-low-storage` (Sev1): `FreeStorageSpace` < 5 GB.
🔎 RDS metric trend shows steady storage growth; binlogs + an unpurged audit table. Risk: RDS goes read-only at 0.
🎯 Root cause: data growth without autoscaling; retention of binlogs too long.
🛠️ Enable storage autoscaling / grow allocated storage now; tune binlog retention; archive old audit rows to S3.
🛡️ Storage autoscaling on; alarm at 15%; capacity review monthly.

## Incident 5 — Memory leak (the metric EC2 didn't show)
🚨 `hrms-ec2-mem-high` (Sev2), only visible because the **agent** publishes memory.
🔎 `mem_used_percent` ramps over hours then the process OOM-kills and restarts (sawtooth). Logs: `JavaScript heap out of memory`.
🎯 Root cause: unbounded in-memory cache in the Node app.
🛠️ Cap the cache / fix the leak; bump instance temporarily.
🛡️ Memory alarm (you only had this because the agent was installed!); restart-on-OOM auto-remediation; load test for leaks.

## Incident 6 — Failover happened, app didn't reconnect
🚨 RDS failover event (Sev1) + `5xx-high`.
🔎 EventBridge shows `RDS-EVENT-0049` (Multi-AZ failover) at 03:14. App logs: `ECONNREFUSED` to the old primary IP for ~3 min.
🎯 Root cause: driver cached DNS; no retry on failover.
🛠️ Restart app to pick up new endpoint IP; add retry logic.
🛡️ Lower DNS TTL, add transaction retries, consider RDS Proxy; test forced failover in staging.

## Incident 7 — Alert storm hides the real issue
🚨 200 emails in 10 minutes; on-call misses the one that matters.
🔎 A single AZ blip flapped dozens of per-instance alarms OK↔ALARM.
🎯 Root cause: noisy per-instance alarms, no aggregation, threshold too tight.
🛠️ Silence/ack; identify the real impact via the user-impact row.
🛡️ Composite alarms on user impact; `M-of-N` datapoints; severity routing; delete non-actionable alarms ([Module 9](09-alerting-system.md)).

## Incident 8 — Surprise $4k CloudWatch bill
🚨 Cost anomaly alert (Sev3).
🔎 Cost Explorer → CloudWatch Logs ingestion spiked. A service was logging full request/response bodies at DEBUG, 50 GB/day, retention "never expire".
🎯 Root cause: verbose logging + no retention.
🛠️ Drop log level to INFO, stop logging bodies, set 30-day retention, export cold logs to S3.
🛡️ Budget alarm on CloudWatch spend; log-level governance; retention enforced via policy/IaC ([Module 12](12-troubleshooting-guide.md)).

## Incident 9 — "Everything is green" but checkout is broken
🚨 No infra alarm fired; customers report failed payments.
🔎 Infra all green; but **business metric** `PaymentSuccessRate` dropped to 60% (custom metric). Logs: 3rd-party payment API returning 502.
🎯 Root cause: external dependency down; infra healthy, business broken.
🛠️ Failover to backup payment provider / queue and retry.
🛡️ Alarm on **business metrics** + synthetic canary of the checkout flow — infra-only monitoring misses this.

## Incident 10 — Queue backing up, jobs delayed
🚨 `JobAgeSeconds` / SQS `ApproximateAgeOfOldestMessage` > 15 min (Sev2).
🔎 Producers normal, consumers down (deploy failed silently). Worker log group went quiet (no new streams).
🎯 Root cause: worker fleet crashed on startup; nothing consuming.
🛠️ Fix worker config, redeploy; backlog drains.
🛡️ Alarm on **queue age** and on **"no logs in N minutes"** (absence-of-data alarm); health check on workers.

---

## 💡 Patterns across all incidents
- **Page on user/business impact, debug with infra metrics + logs.**
- The agent-only metrics (**memory, disk**) catch a whole class of incidents — install it.
- **Logs Insights + a correlation id** is how you find root cause fast.
- **Absence of data** (no logs, no metrics) is itself a signal — alarm on it.
- Most prevention = one alarm + one dashboard widget you didn't have before.

➡️ Next: [Module 11 — Monitoring Playbooks](11-monitoring-playbooks.md)

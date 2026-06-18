# Module 11 — Monitoring Playbooks

> Copy-paste runbooks for on-call. Each is triggered by a specific alarm and gives the exact first moves. Link these from every alert ([Module 9](09-alerting-system.md)).

**Format:** Trigger → Impact → Diagnose → Mitigate → Resolve → Escalate.

---

## Playbook: High API 5xx rate
- **Trigger:** `hrms-api-5xx-high` (Sev1).
- **Impact:** Users getting errors. Revenue/functionality affected.
- **Diagnose:**
  1. Open the prod dashboard → user-impact row. Did 5xx start at a deploy (EventBridge annotation)?
  2. Logs Insights: `filter statusCode>=500 | stats count(*) by route, errorMessage | sort count desc`.
  3. Check downstream: RDS connections/CPU, dependency health.
- **Mitigate:** If deploy-correlated → **roll back**. If one route → feature-flag it off. If DB-driven → see DB playbook.
- **Resolve:** Confirm 5xx → 0 and alarm OK. Capture root cause.
- **Escalate:** > 15 min or revenue-critical → page secondary + incident commander.

## Playbook: High latency (p99)
- **Trigger:** `hrms-api-latency-p99-high` (Sev2).
- **Diagnose:** App CPU vs DB load. Performance Insights Top SQL. Logs `stats pct(ms,99) by route`.
- **Mitigate:** Scale out ASG; add/restore an index; enable cache; shed load on heavy route.
- **Resolve:** p99 back under SLO. **Escalate:** if it becomes user-facing errors → Sev1.

## Playbook: EC2 host unhealthy / status check failed
- **Trigger:** `StatusCheckFailed` / ALB `UnHealthyHostCount`.
- **Diagnose:** System vs instance status check? Agent metrics (CPU/mem/disk). Recent logs before it went quiet.
- **Mitigate:** System check → EC2 **recover** (often automatic). Instance check → reboot / replace via ASG.
- **Resolve:** Host healthy in target group. **Escalate:** multiple hosts → capacity/AZ event.

## Playbook: Disk full
- **Trigger:** `disk_used_percent > 85%`.
- **Diagnose:** `du -sh /var/log/* /tmp/*`. Runaway log file? Core dumps? Old artifacts?
- **Mitigate:** Rotate/truncate logs; clear temp; expand EBS volume (`modify-volume` + grow FS).
- **Resolve:** < 70%. **Prevent:** logrotate, ship logs to CloudWatch, alarm at 80%.

## Playbook: High memory / OOM
- **Trigger:** `mem_used_percent > 85%`.
- **Diagnose:** Sawtooth (leak) vs steady high (undersized)? App logs for OOM. Per-process via Enhanced/agent.
- **Mitigate:** Restart process (auto-remediation), scale up temporarily.
- **Resolve/Prevent:** Fix the leak; right-size; memory alarm (needs the agent!).

## Playbook: RDS storage low
- **Trigger:** `hrms-db-low-storage` (Sev1).
- **Impact:** DB goes **read-only** at 0 — imminent outage.
- **Diagnose:** Storage trend; binlogs; large tables/temp; runaway inserts.
- **Mitigate:** Enable **storage autoscaling** or grow `--allocated-storage` now; tune binlog retention.
- **Resolve:** Free space recovered. **Prevent:** autoscaling on, alarm at 15%, monthly capacity review.

## Playbook: RDS high CPU / connections
- **Trigger:** RDS `CPUUtilization>80%` or `DatabaseConnections` near max.
- **Diagnose:** Performance Insights Top SQL; missing indexes; connection leak / no pooling.
- **Mitigate:** Add index / kill the runaway query; add RDS Proxy / fix pool; scale up class.
- **Resolve/Prevent:** index review, pooling, alarms (ties to [Phase 06](../06-rds/10-troubleshooting-guide.md)).

## Playbook: RDS failover
- **Trigger:** RDS failover event (Sev1) often with `5xx`.
- **Diagnose:** Confirm failover in events; app logs for `ECONNREFUSED`/stale DNS.
- **Mitigate:** Ensure app reconnects (restart if DNS cached); verify writes succeed on new primary.
- **Prevent:** Low DNS TTL, retry logic, RDS Proxy; test forced failover.

## Playbook: Alert storm / flapping
- **Trigger:** Burst of alarm emails.
- **Diagnose:** Is there real user impact (check user-impact row) or just noise?
- **Mitigate:** Ack/silence noisy children; act only on the composite/user-impact alarm.
- **Prevent:** Composite alarms, M-of-N, severity routing, delete non-actionable alarms.

## Playbook: No data / silence (absence alarm)
- **Trigger:** Metric/log stops arriving (agent down, app dead, region issue).
- **Diagnose:** Is the resource running? Agent status? IAM/network to CloudWatch?
- **Mitigate:** Restart agent/app; fix instance role/endpoint.
- **Prevent:** `treat-missing-data=breaching` on critical alarms; "no logs in N min" alarm.

## Playbook: CloudWatch cost spike
- **Trigger:** Budget/cost-anomaly alert.
- **Diagnose:** Cost Explorer → Logs ingestion vs custom metrics vs Insights scans. Which log group/service?
- **Mitigate:** Lower log level; stop logging bodies; set retention; reduce high-res metrics/dashboards.
- **Prevent:** Retention policy as IaC, log-level governance, budget alarm.

---

## 🧰 On-call quick reference
```
Site errors?      -> 5xx playbook (rollback first if deploy-correlated)
Slow?             -> latency playbook -> usually DB / missing index
Host down?        -> status-check playbook (recover/replace)
Disk/Mem high?    -> resource playbook (rotate logs / fix leak)
DB storage low?   -> autoscale/grow NOW (read-only risk)
Too many alerts?  -> act on user-impact only, then de-noise
Silence?          -> absence-of-data: is it even running?
Bill spike?       -> log level + retention
```
Every alert links here. After every incident: **write the postmortem, add the missing alarm/widget.**

➡️ Next: [Module 12 — Troubleshooting Guide](12-troubleshooting-guide.md)

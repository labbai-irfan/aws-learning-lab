# Module 8 — Production Monitoring Setup

> A complete, layered monitoring stack for a real web app: backend (EC2/API), database (RDS), and application (business/app-level). This is the blueprint the capstone implements.

---

## 1. The four layers (what "good" monitoring covers)

```
   ┌─ USER / BUSINESS  : signups, orders, login success %, revenue        (Layer 4)
   ├─ APPLICATION      : API error rate, p99 latency, route health        (Layer 3)
   ├─ BACKEND/INFRA    : EC2 CPU/mem/disk, ALB 5xx, healthy hosts         (Layer 2)
   └─ DATABASE         : RDS CPU, connections, storage, replica lag       (Layer 1)
```
💡 **Monitor top-down for alerting, debug bottom-up.** Page on user impact (Layer 3–4); use Layers 1–2 to find the cause.

### The "four golden signals" (Google SRE) mapped to CloudWatch
| Signal | Question | CloudWatch source |
|---|---|---|
| **Latency** | How slow? | ALB `TargetResponseTime` p99, app `LatencyMs` |
| **Traffic** | How much load? | ALB `RequestCount`, app `RequestCount` |
| **Errors** | How many failing? | ALB `5XX`, metric-filter `ErrorCount` |
| **Saturation** | How full? | EC2 CPU/mem, RDS connections/storage |

---

## 2. Backend Monitoring (EC2 / API)

**Goal:** know the host and the reverse proxy/app process are healthy.

Setup:
1. **CloudWatch agent** on every EC2 (instance role + config) — ships app logs and adds **memory + disk** metrics EC2 lacks ([Module 3](03-logs-and-log-groups.md)).
2. **Detailed monitoring** (1-min) on the instances.
3. **ALB metrics** for the fleet view: `RequestCount`, `HTTPCode_Target_5XX_Count`, `TargetResponseTime`, `UnHealthyHostCount`, `RejectedConnectionCount`.
4. **EC2 auto-recovery alarm** on `StatusCheckFailed_System` → `recover` action.

Backend alarm set:
| Metric | Threshold (example) | Severity |
|---|---|---|
| EC2 `CPUUtilization` | > 80% for 10 min | Sev2 |
| agent `mem_used_percent` | > 85% | Sev2 |
| agent `disk_used_percent` (/) | > 85% | Sev2 |
| `StatusCheckFailed_System` | >= 1 | Sev1 (+recover) |
| ALB `UnHealthyHostCount` | >= 1 | Sev1 |
| ALB `HTTPCode_Target_5XX_Count` rate | > 1% | Sev1 |
| ALB `TargetResponseTime` p99 | > 1s | Sev2 |

Logs: ship Nginx access/error + app stdout to `/hrms/api`; metric filter for `level=error`.

---

## 3. Database Monitoring (RDS)

**Goal:** catch DB saturation before it stalls the app. (Ties directly to [Phase 06 Module 9](../06-rds/09-monitoring-guide.md).)

Setup:
1. **Performance Insights** ON (which SQL causes load — AAS).
2. **Enhanced Monitoring** (1–5s OS metrics).
3. **Export** error + slow query logs to CloudWatch Logs (`/aws/rds/instance/hrms-db/...`).
4. **RDS event subscription** → SNS for failover/low-storage/backup-failed.

DB alarm set:
| Metric | Threshold | Severity |
|---|---|---|
| `FreeStorageSpace` | < 15% (or < 5 GB) | Sev1 |
| `CPUUtilization` | > 80% for 10 min | Sev2 |
| `DatabaseConnections` | > 80% of max_connections | Sev2 |
| `FreeableMemory` | < 10% | Sev2 |
| `ReadLatency`/`WriteLatency` | > 20 ms sustained | Sev2 |
| `ReplicaLag` | > 30 s | Sev2 |
| RDS failover event | any | Sev1 |

Insights query for the slow query that's hurting: see [Module 7](07-logs-insights.md) (slow query log) + Performance Insights Top SQL.

---

## 4. Application Monitoring (business & app-level)

**Goal:** measure what users actually experience and what the business cares about — infra can be green while checkout is broken.

Emit **custom metrics** (via EMF or `PutMetricData`) from the app:
| Metric (`HRMS/App`) | Meaning |
|---|---|
| `RequestCount` (by route) | Traffic |
| `ErrorCount` (by route) | Failures the app saw (caught exceptions, 4xx/5xx) |
| `LatencyMs` (by route, p99) | User-felt latency |
| `LoginSuccessRate` | Auth health |
| `PayrollRunCount` / business KPIs | Business signal |
| `QueueDepth` / `JobAgeSeconds` | Async backlog |

Implementation pattern (Node/Express middleware):
```js
// emit EMF so CloudWatch extracts metrics from a log line (no extra API calls)
logger.info({ _aws: { CloudWatchMetrics: [{ Namespace: "HRMS/App",
  Dimensions: [["route"]], Metrics: [{ Name: "LatencyMs", Unit: "Milliseconds" },
                                     { Name: "ErrorCount", Unit: "Count" }] }] },
  route, LatencyMs: ms, ErrorCount: isError ? 1 : 0, statusCode, requestId });
```

App alarms:
| Metric | Threshold | Severity |
|---|---|---|
| `ErrorCount` rate (5xx %) | > 1% over 5 min | Sev1 |
| `LatencyMs` p99 | > 1s | Sev2 |
| `LoginSuccessRate` | < 95% | Sev1 |
| business KPI (e.g. signups) | anomaly band | Sev2 |

💡 Add **synthetic canaries** (CloudWatch Synthetics) that hit `/health` and a critical user flow every minute — they catch "site down" even when no real traffic is flowing.

---

## 5. End-to-end correlation
Tie layers together with a **requestId / correlationId** logged everywhere, so one Logs Insights filter follows a request from ALB → app → DB query. Put all four layers on **one dashboard** ([Module 4](04-dashboards.md)) and route alarms through the **alerting system** ([Module 9](09-alerting-system.md)).

---

## ✅ Production setup checklist
- [ ] CloudWatch agent on all EC2 (mem/disk + logs)
- [ ] Detailed monitoring (1-min) enabled
- [ ] ALB, EC2, RDS alarms with severity tiers
- [ ] RDS Performance Insights + event subscription
- [ ] Custom app metrics (EMF) for errors/latency/business KPIs
- [ ] Structured JSON logs + retention set per log group
- [ ] Metric filters for `level=error`
- [ ] Synthetic canary on critical flow
- [ ] One prod dashboard (4 layers) + playbook links
- [ ] Alarms → SNS → on-call (Module 9)

➡️ Next: [Module 9 — Alerting System](09-alerting-system.md)

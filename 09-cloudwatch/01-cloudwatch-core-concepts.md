# Module 1 — CloudWatch Core Concepts

> Every core CloudWatch topic in one place: Metrics, Logs, Log Groups, Dashboards, Alarms, Events, and Insights. Deep dives follow in later modules.

**Legend:** 🛠️ run this · 💰 cost · ⚠️ gotcha · 🔒 security · 💡 tip · 🚨 on-call signal

---

## What CloudWatch is

**Amazon CloudWatch** is AWS's **observability** platform. It collects and acts on three signal types:
- **Metrics** — time-series numbers (CPU %, request count, latency).
- **Logs** — text/structured events (app logs, access logs, OS logs).
- **Events** — state changes ("instance stopped", "deploy finished") via **EventBridge**.

On top of those it provides **Dashboards** (visualize), **Alarms** (react to metrics), and **Logs Insights** (query logs).

```
   Three pillars of observability
   ┌── Metrics  → "is it healthy?" (aggregate numbers)
   ├── Logs     → "what exactly happened?" (event detail)
   └── Traces   → "where did the time go?" (X-Ray, request path)
   CloudWatch covers metrics + logs natively; X-Ray adds traces.
```

---

## 1. Metrics (the 60-second version)
A **metric** is a time-ordered set of data points. Each lives in a **namespace** (e.g. `AWS/EC2`, `AWS/RDS`, or your own `HRMS/App`) and is identified by **dimensions** (name/value pairs like `InstanceId=i-123`).

- **Statistics:** Average, Sum, Minimum, Maximum, SampleCount, percentiles (p90, p99).
- **Resolution:** standard = 1-minute; **high-resolution** = 1-second.
- **Custom metrics:** your app pushes its own numbers via `PutMetricData`.
- **Metric math & anomaly detection:** combine/transform metrics; ML-based normal bands.

🛠️ Push a custom metric:
```bash
aws cloudwatch put-metric-data --namespace "HRMS/App" \
  --metric-name SignupCount --value 1 --unit Count \
  --dimensions Service=auth,Env=prod
```
→ Full detail in [Module 2](02-metrics.md).

---

## 2. Logs & Log Groups (the 60-second version)
- A **Log Group** is a container for logs from one source (e.g. `/hrms/api`, `/aws/rds/instance/hrms-db/error`). **Retention** is set per log group.
- A **Log Stream** is a sequence of log events from a single source instance (e.g. one EC2 host or container).
- The **CloudWatch agent** (or SDK/`awslogs` driver) ships logs from EC2/containers.
- **Metric filters** extract metrics from log patterns (e.g. count `ERROR`). **Subscription filters** stream logs to Lambda/Kinesis/OpenSearch in real time.

```
   Log Group  /hrms/api
     ├── Log Stream  i-aaa  (host A)   ── event ── event ── event
     ├── Log Stream  i-bbb  (host B)   ── event ── event
     └── Log Stream  i-ccc  (host C)   ── event
   retention = 30 days · metric filter: count "ERROR" -> HRMS/App ErrorCount
```
→ Full detail in [Module 3](03-logs-and-log-groups.md).

---

## 3. Dashboards (the 60-second version)
A **dashboard** is a customizable page of **widgets** (line/stacked/number/gauge/text/logs-table). Defined in the console or as **JSON** (version-control it). Can be **cross-account and cross-region**. Use them as the single "is prod OK?" pane of glass.
→ Full detail in [Module 4](04-dashboards.md).

---

## 4. Alarms (the 60-second version)
An **alarm** watches **one metric** (metric alarm) or **other alarms** (composite alarm) and transitions between states:
- **OK** — within threshold
- **ALARM** — breached
- **INSUFFICIENT_DATA** — not enough data points

Each state change can trigger **actions**: notify **SNS**, run an **Auto Scaling** action, recover/stop/reboot an EC2 instance, or trigger a **Systems Manager** action.
- **Anomaly detection alarms** alert on deviation from a learned band instead of a fixed threshold.
- **Composite alarms** reduce noise ("alarm only if CPU high AND latency high").
→ Full detail in [Module 5](05-alarms.md).

---

## 5. Events / EventBridge (the 60-second version)
**EventBridge** (the evolution of "CloudWatch Events") routes **events** to **targets** via **rules**:
- **Event-pattern rules** — react to state changes (EC2 state, RDS failover, S3 upload, deploy).
- **Scheduled rules** — cron/rate ("every 5 min", "0 8 * * ? *") to trigger Lambda/automation.
- **Targets** — Lambda, SNS, SQS, Step Functions, SSM, ECS, and more.
→ Full detail in [Module 6](06-events.md).

---

## 6. Logs Insights (the 60-second version)
A purpose-built **query language** to search and analyze logs interactively:
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as errors by bin(5m)
| sort @timestamp desc
```
Great for ad-hoc incident investigation and building dashboard widgets. Works best with **structured (JSON) logs**.
→ Full detail in [Module 7](07-logs-insights.md).

---

## How the pieces connect (a single request's observability)

```
  1. Request hits ALB        → AWS/ApplicationELB metrics (RequestCount, 5XX, latency)
  2. App handles it          → /hrms/api log event (JSON: level, route, ms, status)
  3. Metric filter on logs   → HRMS/App ErrorCount, HRMS/App LatencyMs
  4. Alarm on 5XX/latency    → SNS → on-call
  5. Logs Insights query     → find the failing route + stack trace
  6. EventBridge on deploy   → annotate dashboard / trigger rollback
```

---

## Cost model (know this — CloudWatch bills can surprise you 💰)
- **Metrics:** custom metrics billed per metric/month; high-resolution costs more. API `PutMetricData`/`GetMetricData` calls billed.
- **Logs:** **ingestion per GB** (the usual big line item), **storage per GB-month**, and **Logs Insights per GB scanned**.
- **Dashboards:** first 3 free, then per dashboard/month.
- **Alarms:** per alarm/month (high-resolution and anomaly cost more).
- ⚠️ The two classic surprises: **verbose `DEBUG` logging** (ingestion) and **infinite retention** (storage). Set retention and log at the right level. See [Module 12](12-troubleshooting-guide.md).

---

## Security & access 🔒
- Use **IAM** to scope who can read logs/metrics and who can change alarms.
- **Encrypt log groups** with KMS; logs can contain PII/secrets — don't log them.
- Cross-account observability: use a **monitoring account** with sharing for fleet-wide dashboards.
- CloudWatch agent on EC2 needs an **instance role** with `CloudWatchAgentServerPolicy`.

---

## ✅ Module 1 Recap
- Three signals: **metrics** (numbers), **logs** (events), **events** (state changes).
- **Log Groups** hold **log streams**; retention is per group; **metric filters** bridge logs→metrics.
- **Dashboards** visualize, **alarms** react, **Logs Insights** queries, **EventBridge** routes & schedules.
- Watch cost: **log ingestion + retention** dominate the bill.

➡️ Next: [Module 2 — Metrics Deep Dive](02-metrics.md)

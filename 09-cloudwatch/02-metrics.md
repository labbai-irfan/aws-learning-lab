# Module 2 — Metrics Deep Dive

> Namespaces, dimensions, statistics, resolution, custom metrics, and metric math.

---

## 1. Anatomy of a metric
```
   Namespace        MetricName       Dimensions                Datapoint
   AWS/EC2          CPUUtilization   InstanceId=i-0abc         42.5 % @ 14:32:00
   AWS/RDS          DatabaseConnections  DBInstanceIdentifier=hrms-db   180 @ 14:32
   HRMS/App         OrderLatencyMs   Service=checkout,Env=prod 230 @ 14:32
```
- **Namespace** — a container; AWS services use `AWS/<Service>`. Use your own (e.g. `HRMS/App`) for custom metrics.
- **Dimensions** — up to 30 name/value pairs that uniquely identify a metric. ⚠️ Each unique dimension **combination is a separate (billable) metric**.
- **Timestamp + Value + Unit** — the data point.

---

## 2. Statistics & percentiles
When you graph/alarm a metric you pick a **statistic** over a **period**:

| Statistic | Use |
|---|---|
| `Average` | Typical value (e.g. avg CPU) |
| `Sum` | Totals (e.g. request count) |
| `Minimum` / `Maximum` | Extremes (e.g. max latency) |
| `SampleCount` | Number of data points |
| `p90` / `p95` / `p99` | Tail latency — **what slow users feel** |

💡 For latency, **percentiles beat averages**. An average of 100ms can hide a p99 of 4s. Alarm on **p99**, not avg.

---

## 3. Resolution & retention
- **Standard resolution:** 1-minute granularity.
- **High resolution:** 1-second granularity (custom metrics with `StorageResolution=1`). 💰 Costs more; use only where you need sub-minute reaction.
- **Retention (automatic rollup):** 1-sec data kept 3h → 1-min for 15 days → 5-min for 63 days → 1-hour for **15 months**. ⚠️ You can't query 1-second data from last week — it's already rolled up.

---

## 4. Where metrics come from
1. **AWS services** publish automatically (EC2 basic = 5-min; **detailed monitoring** = 1-min, small cost).
2. **CloudWatch agent** — OS-level metrics EC2 doesn't expose by default: **memory, disk usage, swap** (the hypervisor can't see inside the guest).
3. **Custom metrics** via `PutMetricData` (SDK/CLI) or **EMF** (Embedded Metric Format — emit metrics *inside* a log line).

⚠️ **The famous gap:** EC2 does **not** publish memory or disk-used metrics by default — you must install the CloudWatch agent.

🛠️ Enable detailed (1-min) monitoring:
```bash
aws ec2 monitor-instances --instance-ids i-0abc123
```

🛠️ Custom metric (CLI):
```bash
aws cloudwatch put-metric-data --namespace "HRMS/App" \
  --metric-name CheckoutLatencyMs --value 230 --unit Milliseconds \
  --dimensions Service=checkout,Env=prod
```

### Embedded Metric Format (EMF) — the scalable way
Emit a structured log line and CloudWatch auto-extracts metrics — no extra API calls:
```json
{ "_aws": { "CloudWatchMetrics": [{ "Namespace": "HRMS/App",
   "Dimensions": [["Service"]], "Metrics": [{"Name":"LatencyMs","Unit":"Milliseconds"}] }] },
  "Service": "checkout", "LatencyMs": 230, "requestId": "abc" }
```
💡 EMF is ideal for high-cardinality app metrics from Lambda/containers.

---

## 5. Metric math
Combine metrics into derived ones in graphs and alarms:
```
   Error rate %   = 100 * (m_5xx / m_requests)
   Free mem %     = 100 * (m_freeable / m_total)
   Anomaly band   = ANOMALY_DETECTION_BAND(m_cpu, 2)
   Fill gaps      = FILL(m_metric, 0)
```
Functions: `SUM`, `AVG`, `RATE`, `DIFF`, `FILL`, `ANOMALY_DETECTION_BAND`, plus arithmetic. Alarm directly on the math expression (e.g. error-rate > 1%).

🛠️ Read metrics with math (`get-metric-data`):
```bash
aws cloudwatch get-metric-data --start-time 2026-06-17T13:00:00Z \
  --end-time 2026-06-17T14:00:00Z --metric-data-queries '[
   {"Id":"reqs","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"RequestCount"},"Period":300,"Stat":"Sum"},"ReturnData":false},
   {"Id":"errs","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"HTTPCode_Target_5XX_Count"},"Period":300,"Stat":"Sum"},"ReturnData":false},
   {"Id":"rate","Expression":"100*(errs/reqs)","Label":"5xx %"}]'
```

---

## 6. Metrics worth knowing by service 🚨

| Service | Key metrics |
|---|---|
| **EC2** | `CPUUtilization`, `StatusCheckFailed`, `NetworkIn/Out`, (+ agent: `mem_used_percent`, `disk_used_percent`) |
| **ALB** | `RequestCount`, `HTTPCode_Target_5XX_Count`, `TargetResponseTime`, `UnHealthyHostCount`, `RejectedConnectionCount` |
| **RDS** | `CPUUtilization`, `FreeStorageSpace`, `FreeableMemory`, `DatabaseConnections`, `ReadLatency/WriteLatency`, `ReplicaLag` |
| **Lambda** | `Invocations`, `Errors`, `Throttles`, `Duration`, `ConcurrentExecutions` |
| **SQS** | `ApproximateAgeOfOldestMessage`, `ApproximateNumberOfMessagesVisible` |

---

## ✅ Recap
- Metric = namespace + name + dimensions + datapoints; each dimension combo is a billable metric.
- Use **percentiles** for latency, **detailed monitoring** for 1-min, the **agent** for memory/disk.
- **EMF** scales custom metrics; **metric math** builds rates/anomaly bands you can alarm on.

➡️ Next: [Module 3 — Logs & Log Groups](03-logs-and-log-groups.md)

# 17 — CloudWatch & Monitoring Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-cloudwatch-core-concepts.md).

## The observability trio
```
METRICS  → numbers over time (CloudWatch)      "p99 = 1.2s"
LOGS     → events (CloudWatch Logs)            "query failed"
TRACES   → request journeys (X-Ray, Module 16) "1.1s was in RDS"
```

## Metrics
- **Namespace** = group (`AWS/EC2`); **dimension** = filter (InstanceId); **metric** = the series.
- **Standard** resolution = 1 min; **high-resolution** = 1 sec.
- ⚠️ EC2 default metrics do **not** include **memory** or **disk** — need the **CloudWatch agent**.
- **Custom metrics** via `PutMetricData` (e.g., business KPIs).

## Alarms
| State | Meaning |
|---|---|
| OK / ALARM / INSUFFICIENT_DATA | normal / threshold breached / not enough data |
- Actions: **SNS** notify, Auto Scaling, EC2 action, Systems Manager.
- **Composite alarms** combine several alarms (reduce noise).
- Use **anomaly detection** for dynamic baselines.

## Logs
- **Log group** → **log streams** → events. Set **retention** (default = never expire → cost).
- Ship from EC2/on-prem via the **CloudWatch agent**; Lambda/ECS log natively.
- **Logs Insights** = query language for logs:
```
fields @timestamp, @message | filter @message like /ERROR/ | stats count() by bin(5m)
```
- **Metric filters** turn log patterns into metrics (then alarm on them). **Subscription filters** stream logs to Lambda/Kinesis/OpenSearch.

## Dashboards & events
- **Dashboards** = custom metric/log widgets (cross-Region/account).
- **EventBridge** (CloudWatch Events) = event bus; rules match events → targets (Lambda, SNS, SQS, Step Functions); supports **scheduled** (cron) rules.

## Tracing & unified view
- **X-Ray** = distributed tracing (segments/subsegments, service map, sampling) — [Module 16](16-x-ray.md).
- **ServiceLens / Application Signals** = traces + metrics + logs in one map; **Container Insights** for ECS/EKS; **Lambda Insights** for functions.

## CloudWatch vs CloudTrail (classic)
- **CloudWatch** = operational (metrics/logs/alarms — *is it healthy?*).
- **CloudTrail** = audit (API calls — *who did what?*).

## Exam triggers 💡
- "Alert when CPU > 80% for 5 min" → **metric alarm → SNS**.
- "Monitor memory/disk on EC2" → **CloudWatch agent** (not default).
- "Find error spikes in logs" → **Logs Insights** / **metric filter + alarm**.
- "Run something on a schedule" → **EventBridge scheduled rule**.
- "Which service is slow across microservices?" → **X-Ray / ServiceLens**.
- "Who deleted the bucket?" → **CloudTrail** (not CloudWatch).

## Gotchas ⚠️
- No memory/disk metric without the agent.
- Log groups default to **never expire** — set retention to control cost.
- Alarms need enough datapoints; tune evaluation periods to avoid flapping.
- High-resolution metrics & dense custom metrics cost more.

---
*Back to [CloudWatch & Monitoring README](README.md).*

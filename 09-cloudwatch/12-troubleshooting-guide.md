# Module 12 — CloudWatch Troubleshooting Guide

> Problems with CloudWatch *itself* — missing metrics, logs not arriving, alarms misbehaving, and runaway costs.

**Legend:** 🔎 diagnose · 🛠️ fix · ⚠️ gotcha

---

## Missing metrics

### "I don't see memory / disk metrics for EC2"
⚠️ Expected — EC2 publishes only hypervisor-visible metrics (CPU, network, disk *I/O*), **not** memory or disk-*used*.
🛠️ Install the **CloudWatch agent** with an instance role (`CloudWatchAgentServerPolicy`); configure `mem`/`disk` collection ([Module 3](03-logs-and-log-groups.md)).

### "My metrics are only every 5 minutes"
🔎 Basic monitoring.
🛠️ Enable **detailed monitoring** (`monitor-instances`) for 1-min; for custom metrics use `StorageResolution=1` for 1-sec.

### "Custom metric isn't showing up"
🔎 Wrong namespace/dimensions, or it hasn't been queried into existence yet (metrics appear after first `PutMetricData`).
🛠️ Verify exact namespace + dimension names (case-sensitive); check IAM allows `cloudwatch:PutMetricData`; remember each unique dimension combo is a separate metric.

### "Old high-resolution data is gone"
⚠️ Retention rollup: 1-sec→3h, 1-min→15d, 5-min→63d, 1-hour→15mo. You can't get 1-second data from last week.

---

## Logs not arriving

### "Nothing in my log group"
🔎 Walk the chain: agent running? IAM permissions? correct log group/stream names? network/endpoint reachable?
🛠️
- Agent status: `amazon-cloudwatch-agent-ctl -a status`; logs in `/opt/aws/amazon-cloudwatch-agent/logs/`.
- Instance role needs `logs:CreateLogStream`, `logs:PutLogEvents`, `logs:CreateLogGroup`.
- In a private subnet with no NAT → add a **VPC endpoint** for `logs`.
- Lambda not logging → its execution role lacks `logs:*` on its log group.

### "Logs arrive but I can't query fields in Insights"
🔎 Logs aren't JSON → fields aren't auto-extracted.
🛠️ Emit structured JSON, or use `parse` in the query.

### "Duplicate or out-of-order events"
⚠️ Retries/multiple agents writing the same stream. Use one stream per source (`{instance_id}`); make log shipping idempotent.

---

## Alarm problems

### "Alarm stuck in INSUFFICIENT_DATA"
🔎 Metric has no recent data (resource stopped/scaled, wrong dimensions, period > publish interval).
🛠️ Fix dimensions; set period ≥ metric resolution; set `treat-missing-data` deliberately (`breaching` for "must always report" metrics like a health check).

### "Alarm flaps OK↔ALARM"
🛠️ Increase **datapoints-to-alarm** (`M of N`), lengthen period, alarm on a smoothed statistic (avg/p99 over multiple periods).

### "Alarm didn't fire during a real outage"
🔎 Missing-data treated as `notBreaching`, or threshold/percentile wrong, or you alarmed on raw count not rate.
🛠️ Use `treat-missing-data=breaching` for critical health metrics; alarm on **rates/percentiles**; add a **composite/user-impact** alarm and a **synthetic canary**.

### "Alarm fires but no notification"
🔎 SNS subscription unconfirmed, wrong topic ARN, or SNS access policy blocks CloudWatch.
🛠️ Confirm the email/endpoint subscription; verify `--alarm-actions` ARN; check the SNS topic policy allows `cloudwatch.amazonaws.com` to publish.

---

## EventBridge problems

### "Rule doesn't trigger"
🔎 Event pattern doesn't match (check real event shape), wrong event bus, or target permission missing.
🛠️ Use the **Sandbox / test event** to validate the pattern; ensure the **target resource policy / role** allows EventBridge to invoke it; confirm the event source is on the **default** bus vs a custom bus.

### "Scheduled rule runs at the wrong time"
⚠️ `cron()` in EventBridge is **UTC**. Convert, or use **EventBridge Scheduler** which supports time zones.

---

## Cost runaway 💰

### "CloudWatch bill exploded"
🔎 Cost Explorer → break down by usage type: **Logs ingestion (GB)**, custom metrics, Logs Insights (GB scanned), dashboards, alarms.
🛠️ Common fixes:
- Drop log level (no DEBUG / no request bodies in prod).
- **Set retention** on every log group (default is never-expire).
- Archive cold logs to **S3** (cheaper) via export/Firehose.
- Reduce **high-resolution** metrics/alarms to standard where 1-min is fine.
- Consolidate dashboards (first 3 free).
- Narrow Logs Insights time ranges; query specific groups.
🛡️ Put a **Budget alarm** on CloudWatch spend; enforce retention via IaC.

---

## Quick triage flow
```
No mem/disk metric?  -> install the agent
No logs?             -> agent running? IAM? names? VPC endpoint?
Can't query fields?  -> log JSON / use parse
INSUFFICIENT_DATA?   -> dimensions/period/treat-missing-data
Flapping alarm?      -> M-of-N datapoints
Missed outage?       -> rate/percentile + treat-missing breaching + canary
No notification?     -> confirm SNS sub + topic policy
Rule silent?         -> test pattern + target permissions
Bill spike?          -> log level + retention + Insights scan range
```

➡️ Next: [Module 13 — 100 Interview Questions](13-100-interview-questions.md)

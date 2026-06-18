# Module 3 — Logs & Log Groups

> Log groups, log streams, the CloudWatch agent, retention, metric filters, and subscription filters.

---

## 1. The hierarchy
```
   Log Group   /hrms/api              (one per app/source; retention set here)
     ├─ Log Stream  i-aaa             (one per instance/container/host)
     │     14:32:01 {"level":"info","route":"/login","ms":42}
     │     14:32:02 {"level":"error","route":"/pay","ms":1900,"err":"timeout"}
     ├─ Log Stream  i-bbb
     └─ Log Stream  ecs/task/abc123
```
- **Log Group** = logical container; **retention, encryption, metric filters, subscriptions** are configured at this level.
- **Log Stream** = the actual sequence of events from one source.
- **Log Event** = one timestamped record (ideally structured JSON).

🛠️ Create a group with retention:
```bash
aws logs create-log-group --log-group-name /hrms/api
aws logs put-retention-policy --log-group-name /hrms/api --retention-in-days 30
```
⚠️ **Default retention is "Never expire"** → logs accumulate forever and the bill grows. **Always set retention.**

---

## 2. Getting logs in

| Source | How |
|---|---|
| EC2 / on-prem | **CloudWatch agent** (`amazon-cloudwatch-agent`) tails files → log group |
| ECS / Fargate | `awslogs` log driver in the task definition |
| EKS | Fluent Bit / Container Insights |
| Lambda | Automatic → `/aws/lambda/<fn>` |
| RDS | Enable log exports (error/slow/general/audit) → `/aws/rds/...` |
| App code | SDK `PutLogEvents`, or write to stdout + agent |

### CloudWatch agent on EC2
1. Attach an instance role with `CloudWatchAgentServerPolicy`.
2. Install: `sudo yum install amazon-cloudwatch-agent -y`.
3. Configure (agent JSON) to tail app logs + collect memory/disk metrics:
```json
{
  "logs": { "logs_collected": { "files": { "collect_list": [
    { "file_path": "/var/log/hrms/api.log", "log_group_name": "/hrms/api",
      "log_stream_name": "{instance_id}", "retention_in_days": 30 }
  ]}}},
  "metrics": { "metrics_collected": {
    "mem": { "measurement": ["mem_used_percent"] },
    "disk": { "measurement": ["used_percent"], "resources": ["/"] } } }
}
```
4. Start: `sudo amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/.../config.json`.

💡 **Log structured JSON, not free text.** `{"level":"error","route":"/pay","ms":1900}` is queryable in Logs Insights; `"something broke"` is not.

---

## 3. Metric filters (logs → metrics)
Turn a log pattern into a numeric metric you can graph and alarm on.

🛠️ Count `ERROR` lines into a metric:
```bash
aws logs put-metric-filter --log-group-name /hrms/api \
  --filter-name api-errors \
  --filter-pattern '{ $.level = "error" }' \
  --metric-transformations \
    metricName=ApiErrorCount,metricNamespace=HRMS/App,metricValue=1,defaultValue=0
```
- Pattern syntax: `?ERROR` (text), `{ $.statusCode >= 500 }` (JSON), `[ip, user, ..., status=5*, size]` (space-delimited).
- 💡 Set `defaultValue=0` so the metric reports 0 (not "no data") when there are no errors — makes alarms reliable.

Now alarm on `HRMS/App ApiErrorCount` (see [Module 5](05-alarms.md)).

---

## 4. Subscription filters (real-time streaming)
Stream matching log events out of CloudWatch in real time to:
- **Lambda** — custom processing / alerting on a log pattern instantly.
- **Kinesis Data Streams / Firehose** — to S3, OpenSearch, Splunk, Datadog.
- **OpenSearch** — full-text log analytics dashboards.

🛠️
```bash
aws logs put-subscription-filter --log-group-name /hrms/api \
  --filter-name to-lambda --filter-pattern '{ $.level = "error" }' \
  --destination-arn arn:aws:lambda:us-east-1:ACCT:function:error-notifier
```

---

## 5. Retention, export & lifecycle
- **Retention:** 1 day → 10 years per log group. Pick by value: app logs 30–90d, audit logs longer.
- **Export to S3:** for cheap long-term archive / compliance (`create-export-task`).
- **Logs → S3 via Firehose:** continuous archival pipeline.
- 💰 Storage in CloudWatch Logs is pricier than S3 — archive cold logs to S3/Glacier.

---

## 6. Security 🔒
- **Encrypt** log groups with a KMS key (`associate-kms-key`).
- **Never log secrets/PII** (passwords, tokens, full card numbers). Scrub before logging.
- Scope IAM: who can `GetLogEvents` / `StartQuery` vs who can `DeleteLogGroup`.
- Data protection policies can **mask** sensitive patterns in logs automatically.

---

## ✅ Recap
- Log Group (retention/filters/encryption) → Log Streams → events.
- Ship logs via the **agent** (EC2), log drivers (containers), or native (Lambda/RDS).
- **Metric filters** make alarms from logs; **subscription filters** stream logs live.
- **Always set retention**; log structured JSON; encrypt; never log secrets.

➡️ Next: [Module 4 — Dashboards](04-dashboards.md)

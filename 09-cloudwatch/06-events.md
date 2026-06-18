# Module 6 — Events (EventBridge)

> "CloudWatch Events" is now **Amazon EventBridge**. React to AWS state changes and run scheduled automation.

---

## 1. The model
```
   Event source ──► Event Bus ──► Rule (pattern OR schedule) ──► Target(s)
   (EC2 state,                     {"source":["aws.rds"],          Lambda / SNS /
    RDS failover,                   "detail-type":["RDS DB         SQS / Step Functions /
    S3 upload,                      Instance Event"]}              SSM / ECS task ...
    deploy, custom app event)
```
- **Event** — a JSON record describing a change ("EC2 instance entered stopped").
- **Event bus** — default bus (AWS events), custom buses (your apps), partner buses (SaaS).
- **Rule** — matches events by **pattern**, or fires on a **schedule**.
- **Target** — what runs in response (up to 5 per rule).

---

## 2. Event-pattern rules (react to changes)
🛠️ Notify on any RDS failover/availability event:
```bash
aws events put-rule --name rds-availability \
  --event-pattern '{
    "source": ["aws.rds"],
    "detail-type": ["RDS DB Instance Event"]
  }'
aws events put-targets --rule rds-availability \
  --targets "Id"="sns","Arn"="arn:aws:sns:us-east-1:ACCT:ops-alerts"
```
Common patterns:
- **EC2 state change** → auto-tag, notify, or clean up.
- **RDS events** → failover/low-storage/backup notifications.
- **S3 object created** → trigger processing Lambda.
- **CodeDeploy/CodePipeline** → annotate dashboards, post to Slack on deploy.
- **GuardDuty finding / Health event** → security/ops routing.
- **Custom app events** (`PutEvents`) → decouple microservices.

---

## 3. Scheduled rules (cron/rate)
Run automation on a schedule (the modern replacement for cron servers):
```bash
# Every 5 minutes
aws events put-rule --name synthetic-healthcheck \
  --schedule-expression "rate(5 minutes)"

# 8:00 AM UTC daily
aws events put-rule --name daily-report \
  --schedule-expression "cron(0 8 * * ? *)"
```
Use cases: synthetic health checks, nightly cleanup, cost reports, snapshot triggers, scaling pre-warm. 💡 **EventBridge Scheduler** (newer) adds one-time schedules, time zones, and flexible windows.

---

## 4. Events vs Alarms — when to use which
| | **Alarm** | **EventBridge rule** |
|---|---|---|
| Watches | A **metric** crossing a threshold | A **state-change event** / a schedule |
| Example | "CPU > 80% for 5 min" | "instance entered stopped" / "every 5 min" |
| Output | OK/ALARM + actions | Route event to targets |
| Use for | Quantitative thresholds | Reacting to discrete events & scheduling |

💡 They combine: an **alarm state change is itself an event** — route alarm events through EventBridge to enrich/format before notifying.

---

## 5. Auto-remediation pattern
```
   EventBridge rule (StatusCheckFailed event / alarm ALARM)
        └─► Lambda  ─► restart PM2 / drain+replace instance / scale ASG
        └─► SNS     ─► notify on-call that auto-remediation ran
```
Keep auto-remediation **idempotent** and **bounded** (don't loop), and always **notify** so humans know a robot acted. See [Module 11 playbooks](11-monitoring-playbooks.md).

---

## ✅ Recap
- EventBridge routes **events** (and **schedules**) to **targets** via **rules**.
- Pattern rules react to AWS/app state changes; schedule rules replace cron.
- Alarms = metric thresholds; Events = discrete changes + scheduling; they compose for alerting and auto-remediation.

➡️ Next: [Module 7 — Logs Insights](07-logs-insights.md)

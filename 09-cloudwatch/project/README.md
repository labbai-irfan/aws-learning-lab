# Capstone Project — Full Observability for the HRMS App

> Build a complete CloudWatch monitoring stack for the Phase 06 **HRMS** application: backend (EC2 + Node API), database (RDS MySQL), and application (business metrics) — with a 4-layer dashboard, severity-tiered alarms, an alerting system, Logs Insights, and one auto-remediation.

**Time:** 6+ hours · **Cost:** small if you set retention and tear down.

---

## 🎯 What you'll build

```
   ALB ─► EC2 (Node API + CW agent, PM2) ─► RDS MySQL (Multi-AZ)
     │ ALB metrics      │ logs + mem/disk + app EMF metrics   │ PI + metrics + events
     └──────────────────┴──────────────────┬─────────────────┘
                                            ▼
        CloudWatch:  HRMS-Prod dashboard (4 layers)
                     alarms (Sev1/2/3) + composite "user-impact"
                     Logs Insights (/hrms/api, /hrms/nginx)
                                            ▼
        SNS:  ops-page (Sev1) ─► PagerDuty/Slack
              ops-notify (Sev2) ─► Slack/email
              ops-ticket (Sev3) ─► email
              EventBridge ─► Lambda (auto-restart api) ─► notify
```

---

## Step 1 — Instrument the backend (EC2)
1. Attach instance role with `CloudWatchAgentServerPolicy`.
2. Install + configure the **CloudWatch agent** ([Module 3](../03-logs-and-log-groups.md)) to:
   - Collect `mem_used_percent`, `disk_used_percent`.
   - Ship `/var/log/hrms/api.log` → `/hrms/api` and Nginx logs → `/hrms/nginx`.
3. Enable **detailed (1-min) monitoring** on the instance.
4. Set retention: `aws logs put-retention-policy --log-group-name /hrms/api --retention-in-days 30`.

## Step 2 — Instrument the application (custom metrics)
Add Express middleware emitting **EMF** so each request publishes `RequestCount`, `ErrorCount`, `LatencyMs` by `route`, plus business metrics (`LoginSuccessRate`, `PayrollRunCount`). See [Module 8 §4](../08-production-monitoring-setup.md#4-application-monitoring-business--app-level) and [app-instrumentation.js](app-instrumentation.js).

## Step 3 — Instrument the database (RDS)
- Enable **Performance Insights** + **Enhanced Monitoring**.
- Export **error + slow query logs** to CloudWatch (`/aws/rds/instance/hrms-db/...`).
- Create an **RDS event subscription** → `ops-page` for failover/low-storage.

## Step 4 — Metric filters (logs → metrics)
```bash
aws logs put-metric-filter --log-group-name /hrms/api \
  --filter-name api-errors --filter-pattern '{ $.level = "error" }' \
  --metric-transformations metricName=ApiErrorCount,metricNamespace=HRMS/App,metricValue=1,defaultValue=0
```

## Step 5 — Dashboard (4 layers)
Deploy [dashboard.json](dashboard.json):
```bash
aws cloudwatch put-dashboard --dashboard-name HRMS-Prod --dashboard-body file://dashboard.json
```
Rows: **user impact → backend → database → live error logs → alarm grid**.

## Step 6 — Alerting system (SNS by severity)
```bash
for t in ops-page ops-notify ops-ticket; do aws sns create-topic --name $t; done
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:ACCT:ops-notify --protocol email --notification-endpoint oncall@company.com
# Connect ops-page/ops-notify to Slack via AWS Chatbot.
```

## Step 7 — Alarms (deploy the set)
Run [alarms.sh](alarms.sh) to create the Sev1/Sev2 alarms for ALB, EC2, RDS, and app metrics, plus the **composite** user-impact alarm:
```
ALARM(hrms-api-5xx-high) AND ALARM(hrms-api-latency-high) -> ops-page
```

## Step 8 — Auto-remediation (one safe case)
EventBridge rule on "API process down" (metric filter `ApiDown`) → Lambda runs SSM `pm2 restart` and publishes to `ops-notify`. Keep it idempotent + rate-limited ([Module 9 §6](../09-alerting-system.md)).

## Step 9 — Synthetic canary
Create a CloudWatch Synthetics canary hitting `/health` and the login flow every minute → alarm on canary failure (catches "down" with no traffic).

## Step 10 — Run a game day
Trigger each [incident](../10-incident-examples.md) (deploy a bad build, fill disk, slow query, force failover). For each: confirm the **right** alarm fires at the **right** severity, the dashboard shows it, and the [playbook](../11-monitoring-playbooks.md) resolves it. Measure MTTA/MTTR.

---

## ✅ Acceptance criteria
- [ ] Agent shipping mem/disk + logs; retention set on all groups
- [ ] App EMF metrics (errors/latency/business) flowing
- [ ] RDS PI + log exports + event subscription
- [ ] Metric filter `ApiErrorCount` with `defaultValue=0`
- [ ] `HRMS-Prod` 4-layer dashboard deployed from JSON
- [ ] SNS topics per severity; Slack/email wired
- [ ] Sev1/Sev2 alarms + composite user-impact alarm
- [ ] Auto-remediation Lambda (notifies when it acts)
- [ ] Synthetic canary on a critical flow
- [ ] Game day passed; playbooks validated; MTTR measured

## 🧹 Teardown
```bash
aws cloudwatch delete-dashboards --dashboard-names HRMS-Prod
# delete alarms created by alarms.sh, EventBridge rule, canary, and SNS topics
# cap retention on all /hrms/* and /aws/rds/* log groups
```

## 📁 Files in this project
- [dashboard.json](dashboard.json) — the 4-layer HRMS-Prod dashboard
- [alarms.sh](alarms.sh) — creates the severity-tiered alarm set + composite
- [app-instrumentation.js](app-instrumentation.js) — Express EMF metrics + structured logging middleware

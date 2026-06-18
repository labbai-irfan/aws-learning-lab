# Module 9 — Alerting System

> Turn alarms into the right notification, to the right person, at the right urgency — without drowning the team in noise.

---

## 1. The pipeline
```
   Metric/Log ─► Alarm ─► (SNS topic by severity) ─► subscribers
                    │                                  ├─ Email (Sev2/3)
                    │                                  ├─ Slack/Teams (chatbot/webhook Lambda)
                    │                                  ├─ PagerDuty/Opsgenie (Sev1 page)
                    └─► EventBridge ─► Lambda ─► auto-remediation (+notify)
```

## 2. Severity tiers (route by urgency)
| Sev | Meaning | Examples | Channel | Response |
|---|---|---|---|---|
| **Sev1** | User-facing outage | 5xx>1%, healthy hosts=0, DB down, p99>5s | **Page** (PagerDuty) | Immediate, 24/7 |
| **Sev2** | Degradation / nearing limits | CPU>80%, storage<15%, replica lag, p99>1s | Slack + email | Same business day |
| **Sev3** | Informational | cost anomaly, cert expiring, low disk trend | Ticket/email | Backlog |

💡 One **SNS topic per severity** (`ops-page`, `ops-notify`, `ops-ticket`); subscribe the right endpoints to each. Alarms publish to the topic matching their severity.

🛠️ Create topics + email sub:
```bash
aws sns create-topic --name ops-page
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:ACCT:ops-page \
  --protocol email --notification-endpoint oncall@company.com
```

## 3. Slack/Teams integration
- **AWS Chatbot** connects SNS → Slack/Teams natively (no code).
- Or an **SNS → Lambda → webhook** to format rich messages (include alarm name, metric, value, dashboard + playbook links).
```
   Alarm ─► SNS ─► Lambda ─► Slack webhook
   "🚨 Sev1 hrms-api-5xx-high  value=3.2%  [Dashboard] [Playbook]"
```

## 4. Reduce noise (the make-or-break of alerting)
| Tactic | Effect |
|---|---|
| **Composite alarms** | Page only on real impact (5xx AND latency) — [Module 5](05-alarms.md) |
| **M-of-N datapoints** | Ignore single-spike blips |
| **Severity routing** | Sev2/3 don't wake anyone |
| **Maintenance windows** | Suppress alarms during deploys (composite `AND NOT deploy-in-progress`) |
| **Anomaly detection** | Right threshold per time-of-day |
| **Dedup/grouping** | PagerDuty/Opsgenie collapse related alerts |
| **Actionable only** | If an alarm needs no action, delete it — every alert must be fixable |

🚨 **Rule:** every page must be **urgent, real, and actionable**. If on-call ignores an alarm, fix or delete it — alert fatigue causes missed real incidents.

## 5. On-call essentials
- **Escalation policy:** primary → secondary → manager after N minutes unacked.
- **Runbook link in every alert** → on-call knows the first move ([Module 11](11-monitoring-playbooks.md)).
- **Dashboard link in every alert** → context in one click.
- **Acknowledge + resolve** tracked for MTTA/MTTR metrics.

## 6. Auto-remediation (let robots handle the boring ones)
```
   Alarm: StatusCheckFailed_System ─► EC2 recover action          (self-heal)
   Alarm: API process down (metric filter) ─► EventBridge ─► Lambda ─► SSM RunCommand "pm2 restart"
                                                          └─► SNS notify "auto-restarted api on i-123"
```
⚠️ Always **notify** when automation acts, keep it **idempotent**, and **rate-limit** so a flapping condition doesn't loop.

## 7. Measuring the alerting system
- **MTTA** (mean time to acknowledge), **MTTR** (mean time to resolve).
- **Alert volume / on-call** per week — trending up = noise problem.
- **False-positive rate** — tune or delete offenders monthly.

---

## ✅ Recap
- Route alarms by **severity** to the right channel (page vs notify vs ticket).
- Cut noise with **composite alarms, M-of-N, maintenance windows, anomaly detection**.
- Every alert: **actionable**, with **dashboard + playbook links**.
- Auto-remediate safe cases; always notify; measure MTTA/MTTR.

➡️ Next: [Module 10 — Incident Examples](10-incident-examples.md)

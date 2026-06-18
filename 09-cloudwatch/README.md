# Phase 09 — Amazon CloudWatch Complete Learning Repository

> A hands-on, production-focused course on **Amazon CloudWatch** — from your first metric to a full observability stack monitoring a backend API, an RDS database, and an application, with dashboards, alarms, log insights, and an on-call alerting system.

Authored as a structured program by an **AWS Monitoring Specialist**. Builds on [Phase 03 — EC2](../03-ec2/README.md), [Phase 05 — S3](../05-s3/README.md), and [Phase 06 — RDS](../06-rds/README.md). Every module has explanations, diagrams, real AWS CLI commands, and practice.

---

## 🎯 Who This Is For
- Backend / DevOps engineers who need to **know when production breaks — before customers do**.
- Anyone running EC2 + RDS apps (Phases 2–4) who wants real monitoring and alerting.
- Candidates preparing for **AWS SysOps / DevOps / Solutions Architect** interviews.

**Prerequisites:** An AWS account, a running app to monitor (the Phase 06 HRMS stack is ideal), and basic CLI comfort.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | CloudWatch Core Concepts (all topics) | [01-cloudwatch-core-concepts.md](01-cloudwatch-core-concepts.md) | 3 hrs |
| 2 | Metrics Deep Dive | [02-metrics.md](02-metrics.md) | 2 hrs |
| 3 | Logs & Log Groups | [03-logs-and-log-groups.md](03-logs-and-log-groups.md) | 2 hrs |
| 4 | Dashboards | [04-dashboards.md](04-dashboards.md) | 1 hr |
| 5 | Alarms | [05-alarms.md](05-alarms.md) | 2 hrs |
| 6 | Events (EventBridge) | [06-events.md](06-events.md) | 1 hr |
| 7 | Logs Insights | [07-logs-insights.md](07-logs-insights.md) | 2 hrs |
| 8 | Production Monitoring Setup (backend · DB · app) | [08-production-monitoring-setup.md](08-production-monitoring-setup.md) | 3 hrs |
| 9 | Alerting System | [09-alerting-system.md](09-alerting-system.md) | 2 hrs |
| 10 | Incident Examples | [10-incident-examples.md](10-incident-examples.md) | 2 hrs |
| 11 | Monitoring Playbooks | [11-monitoring-playbooks.md](11-monitoring-playbooks.md) | 2 hrs |
| 12 | Troubleshooting Guide | [12-troubleshooting-guide.md](12-troubleshooting-guide.md) | 1 hr |
| 13 | 100 Interview Questions | [13-100-interview-questions.md](13-100-interview-questions.md) | 2 hrs |
| 14 | 100 MCQs | [14-100-mcqs.md](14-100-mcqs.md) | 2 hrs |
| 15 | Hands-on Labs | [15-labs.md](15-labs.md) | 3 hrs |
| 16 | AWS X-Ray (distributed tracing & ServiceLens) | [16-x-ray.md](16-x-ray.md) | 2 hrs |
| 17 | Cheat Sheet (1-page revision) | [17-cheatsheet.md](17-cheatsheet.md) | 30 min |
| 18 | **Capstone Project:** Full observability for HRMS | [project/README.md](project/README.md) | 6+ hrs |

**Total:** ~37 hours.

---

## 📚 Topics Covered

**Core CloudWatch building blocks** (Modules 1–7)
- **Metrics** (namespaces, dimensions, statistics, resolution, custom metrics, math)
- **Logs** & **Log Groups** (agents, streams, retention, metric filters, subscriptions)
- **Dashboards** (widgets, JSON, cross-account/region)
- **Alarms** (metric/composite, states, anomaly detection, actions)
- **Events / EventBridge** (rules, schedules, targets)
- **Logs Insights** (query language, structured logs)

**Production monitoring** (Modules 8–9)
- Backend monitoring · Database monitoring · Application monitoring · Alerting system

**Operations & practice** (Modules 10–16)
- Incident examples · Monitoring playbooks · Troubleshooting · Interview Qs · MCQs · Labs · Capstone

---

## ⚡ CloudWatch Mental Model (60-second overview)

```
   AWS services + your apps  ──emit──►   ┌──────────── CloudWatch ────────────┐
   (EC2, RDS, ALB, Lambda,              │  METRICS  (numbers over time)        │
    custom app metrics)                 │     │            ▲                   │
                                        │     │            │ metric filter     │
   App / OS / access logs  ──agent──►   │  LOGS (Log Groups → Log Streams)     │
                                        │     │            │                   │
                                        │     ▼            ▼                   │
                                        │  ALARMS ◄── DASHBOARDS ── LOGS        │
                                        │     │          (view)     INSIGHTS   │
                                        └─────┼──────────────────────(query)───┘
                                              ▼
                            EVENTS/EventBridge ─► SNS ─► Email/Slack/PagerDuty
                                              └─► Lambda (auto-remediation)
```

**In words:** Everything emits **metrics** (numbers) and **logs** (text). **Log Groups** organize logs; **metric filters** turn log patterns into metrics; **Logs Insights** queries them. **Dashboards** visualize. **Alarms** watch metrics and fire **actions**. **EventBridge** reacts to events and routes to **SNS** (notify humans) or **Lambda** (auto-fix).

---

## 🔑 The sections you asked for — where to find them

| Requested topic | Module |
|---|---|
| Production Monitoring Setup | [08-production-monitoring-setup.md](08-production-monitoring-setup.md) |
| Backend Monitoring | [08-production-monitoring-setup.md](08-production-monitoring-setup.md#2-backend-monitoring-ec2--api) |
| Database Monitoring | [08-production-monitoring-setup.md](08-production-monitoring-setup.md#3-database-monitoring-rds) |
| Application Monitoring | [08-production-monitoring-setup.md](08-production-monitoring-setup.md#4-application-monitoring-business--app-level) |
| Alerting System | [09-alerting-system.md](09-alerting-system.md) |
| Incident Examples | [10-incident-examples.md](10-incident-examples.md) |
| Monitoring Playbooks | [11-monitoring-playbooks.md](11-monitoring-playbooks.md) |
| Troubleshooting Guide | [12-troubleshooting-guide.md](12-troubleshooting-guide.md) |
| Interview Questions | [13-100-interview-questions.md](13-100-interview-questions.md) |

---

## 🛠️ What You'll Build (Capstone)

Full observability for the Phase 06 **HRMS** app:
```
   ALB ─► EC2 (Node API + CW agent) ─► RDS MySQL
     │            │ logs+metrics            │ metrics
     └────────────┴──────────┬─────────────┘
                             ▼
              CloudWatch: dashboards + alarms + Logs Insights
                             ▼
              SNS ─► Email + Slack  (sev-based alerting)
                  └► Lambda (auto-restart / scale)
```
Full build in [project/README.md](project/README.md).

---

## 📌 Conventions
- 🛠️ = run this command · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip · 🚨 = on-call signal
- `$` = shell · `CW>` = CloudWatch console · metric format = `Namespace / MetricName`

---

## 📖 Official References
- CloudWatch docs: https://docs.aws.amazon.com/cloudwatch/
- Logs Insights query syntax: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html
- CloudWatch agent: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html
- Pricing: https://aws.amazon.com/cloudwatch/pricing/

---

*Start with [01-cloudwatch-core-concepts.md](01-cloudwatch-core-concepts.md).* 🚀

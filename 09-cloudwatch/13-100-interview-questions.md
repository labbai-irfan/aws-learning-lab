# Module 13 — 100 CloudWatch Interview Questions (with model answers)

> Grouped by theme. Answers are concise — expand with examples from the capstone and incidents in interviews.

---

## A. Fundamentals (1–12)
1. **What is CloudWatch?** AWS's observability service for metrics, logs, and events, plus dashboards, alarms, and Logs Insights.
2. **Metrics vs logs vs traces?** Metrics = aggregate numbers ("is it healthy?"); logs = discrete event detail ("what happened?"); traces = request path/timing (X-Ray).
3. **What is a namespace?** A container for metrics, e.g. `AWS/EC2` or custom `HRMS/App`.
4. **What is a dimension?** A name/value pair identifying a metric (e.g. `InstanceId=i-123`); each unique combo is a separate billable metric.
5. **Basic vs detailed monitoring?** Basic = 5-min; detailed = 1-min (small cost).
6. **What's high-resolution?** 1-second granularity custom metrics/alarms.
7. **Standard metric retention?** Rolled up: 1-sec→3h, 1-min→15d, 5-min→63d, 1-hr→15mo.
8. **What does CloudWatch NOT monitor on EC2 by default?** Memory and disk-used — need the agent.
9. **Why install the CloudWatch agent?** Memory/disk metrics + ship logs; the hypervisor can't see inside the guest.
10. **What's a custom metric?** Your own metric via `PutMetricData` or EMF.
11. **What is EMF?** Embedded Metric Format — emit metrics inside a structured log line, auto-extracted.
12. **What's metric math?** Combine/transform metrics (rates, anomaly bands) in graphs/alarms.

## B. Metrics & statistics (13–22)
13. **Average vs Sum vs p99 — when?** Average for typical, Sum for totals, p99 for tail latency users feel.
14. **Why percentiles for latency?** Averages hide slow outliers; p99 reflects worst real experiences.
15. **What is SampleCount?** Number of datapoints in the period.
16. **Period vs evaluation periods?** Period = aggregation window; evaluation periods = how many windows the alarm checks.
17. **How to get memory metrics?** Install the agent and configure `mem_used_percent`.
18. **How to push a metric from code?** SDK `PutMetricData` or EMF log line.
19. **Cost driver for custom metrics?** Number of unique metrics (dimension combos) and resolution/API calls.
20. **What's anomaly detection?** ML-learned normal band; alarm on deviation, good for seasonal metrics.
21. **Cross-account metrics?** Use a monitoring account with CloudWatch cross-account observability.
22. **Key ALB metrics?** RequestCount, 5XX count, TargetResponseTime, UnHealthyHostCount.

## C. Logs & Log Groups (23–38)
23. **Log group vs log stream?** Group = container (retention/filters set here); stream = events from one source.
24. **Default log retention?** Never expire — always set it.
25. **How do logs get to CloudWatch?** Agent (EC2), log drivers (containers), native (Lambda/RDS), SDK.
26. **What's a metric filter?** Turns a log pattern into a metric you can alarm on.
27. **Why `defaultValue=0` on a metric filter?** So the metric reports 0 (not no-data) when the pattern is absent → reliable alarms.
28. **What's a subscription filter?** Real-time stream of matching log events to Lambda/Kinesis/OpenSearch.
29. **Structured vs plain logs — why care?** JSON auto-parses into queryable fields in Insights.
30. **How to archive logs cheaply?** Export to S3 / Firehose to S3; CloudWatch storage is pricier.
31. **How to encrypt logs?** KMS key on the log group.
32. **What permissions does the agent need?** Instance role with `CloudWatchAgentServerPolicy` (logs + metrics).
33. **Logs from a private subnet with no NAT?** Add a VPC endpoint for `logs`.
34. **How to mask PII in logs?** Log data protection policies; better, don't log secrets/PII.
35. **Where do Lambda logs go?** `/aws/lambda/<fn>` automatically.
36. **RDS logs in CloudWatch?** Enable log exports (error/slow/general/audit).
37. **How to alarm on an error string?** Metric filter on the pattern → alarm on the metric.
38. **Why retention discipline?** Storage cost + compliance; biggest part of CW bill is ingestion+storage.

## D. Dashboards (39–46)
39. **What's a dashboard?** A page of widgets visualizing metrics/logs/alarms.
40. **Why dashboards as JSON?** Version control, IaC deploy, avoid console drift.
41. **Cross-region dashboard?** Yes — set region per widget.
42. **How to organize a prod dashboard?** Top-down: user impact → backend → DB → logs → alarms.
43. **How many free dashboards?** First 3.
44. **What's a logs-table widget?** Renders a Logs Insights query result live.
45. **Automatic dashboards?** Per-service default dashboards AWS provides.
46. **Container/Lambda Insights?** Curated performance dashboards for ECS/EKS/Lambda.

## E. Alarms (47–62)
47. **Alarm states?** OK, ALARM, INSUFFICIENT_DATA.
48. **What is M-of-N?** Require M breaching datapoints of N evaluated → reduces flapping.
49. **treat-missing-data options?** breaching, notBreaching, ignore, missing.
50. **When set missing=breaching?** Critical health metrics that must always report (canary).
51. **Composite alarm?** Boolean combination of alarms (AND/OR/NOT) to cut noise.
52. **Anomaly detection alarm?** Alarms on deviation from a learned band.
53. **Alarm actions?** SNS, Auto Scaling, EC2 recover/reboot/stop, SSM, (Lambda via SNS/EventBridge).
54. **EC2 auto-recovery?** Alarm on StatusCheckFailed_System + recover action moves to healthy hardware.
55. **Why alarm on rate not count?** Counts lack baseline; 50 errors is fine at 1M req, terrible at 100.
56. **How to prevent alert fatigue?** Composite alarms, severity routing, M-of-N, delete non-actionable alarms.
57. **Alarm fires but no email?** Unconfirmed SNS sub / topic policy / wrong ARN.
58. **Alarm stuck INSUFFICIENT_DATA?** No data for the dimensions/period; fix or set missing-data.
59. **How to suppress alarms during deploys?** Maintenance window / composite `AND NOT deploy-in-progress`.
60. **Best web-app alarm set?** ALB 5xx/latency/unhealthy, EC2 cpu/mem/disk/status, RDS storage/cpu/connections/lag, app error rate, composite user-impact.
61. **High-res alarm cost?** More than standard; use only when sub-minute reaction matters.
62. **Difference: alarm vs Logs Insights?** Alarm = continuous metric threshold; Insights = ad-hoc investigation.

## F. Events / EventBridge (63–72)
63. **What is EventBridge?** Event bus routing events/schedules to targets via rules (was CloudWatch Events).
64. **Pattern vs scheduled rule?** Pattern matches state-change events; scheduled fires on cron/rate.
65. **Targets?** Lambda, SNS, SQS, Step Functions, SSM, ECS, etc.
66. **Alarm vs event — when?** Alarm for metric thresholds; event for discrete state changes/scheduling.
67. **Cron timezone gotcha?** EventBridge `cron()` is UTC; Scheduler supports time zones.
68. **Auto-remediation pattern?** Event/alarm → Lambda/SSM fixes it → SNS notifies.
69. **Use case for scheduled rules?** Health checks, cleanup, reports, snapshot triggers.
70. **Custom events?** App `PutEvents` to a custom bus for decoupling.
71. **React to a deploy?** CodePipeline/CodeDeploy event → annotate dashboard / Slack.
72. **Rule not firing?** Pattern mismatch / wrong bus / target permission.

## G. Production monitoring & alerting (73–88)
73. **Four golden signals?** Latency, traffic, errors, saturation.
74. **Four monitoring layers?** Database, backend/infra, application, business/user.
75. **Monitor top-down or bottom-up?** Page on user/business impact, debug with infra.
76. **Backend monitoring essentials?** Agent (mem/disk + logs), detailed monitoring, ALB metrics, status-check recovery.
77. **Database monitoring essentials?** Performance Insights, enhanced monitoring, log exports, event subscription, storage/cpu/connections/lag alarms.
78. **Application monitoring essentials?** Custom metrics (errors, p99, business KPIs), structured logs, canaries.
79. **Why monitor business metrics?** Infra can be green while checkout is broken.
80. **What's a synthetic canary?** Scripted check (Synthetics) hitting endpoints/flows on a schedule — catches "down" with no traffic.
81. **Severity tiers?** Sev1 page (outage), Sev2 notify (degradation), Sev3 ticket (info).
82. **How to route alerts?** SNS topic per severity → page/Slack/email accordingly.
83. **Slack integration?** AWS Chatbot or SNS→Lambda→webhook.
84. **What makes a good alert?** Urgent, real, actionable, with dashboard + playbook links.
85. **MTTA/MTTR?** Mean time to acknowledge / resolve — measure the alerting system.
86. **Correlation id?** A shared id logged across tiers to trace one request end-to-end.
87. **Absence-of-data alarm?** Alarm when a metric/log stops (agent/app dead) — silence is a signal.
88. **How tie a request from ALB→app→DB?** Log a requestId everywhere; filter on it in Insights.

## H. Logs Insights & troubleshooting (89–94)
89. **Insights query shape?** `fields | filter | stats | sort | limit` pipeline.
90. **Insights cost model?** Per GB scanned — narrow the time range/log group.
91. **Find error rate over time?** `filter level="error" | stats count(*) by bin(5m)`.
92. **Parse plain-text logs?** `parse @message "..." as f1, f2`.
93. **Insights vs metric filter?** Insights = investigate; metric filter = continuous detection/alarm.
94. **Pin a query to a dashboard?** Save as a logs widget.

## I. Cost & best practices (95–100)
95. **Biggest CloudWatch cost driver?** Log ingestion (GB) + storage (retention).
96. **How to cut log cost?** Right log level, no bodies, set retention, archive to S3.
97. **Custom metric cost control?** Limit dimension cardinality; standard resolution where fine.
98. **Why set retention on every log group?** Default never-expire grows storage cost forever.
99. **CloudWatch vs X-Ray?** CloudWatch = metrics/logs; X-Ray = distributed tracing.
100. **CloudWatch vs third-party (Datadog/Prometheus)?** CloudWatch is native/managed and integrates with AWS actions; third-party adds richer APM/tracing and multi-cloud — often used together via subscription/streams.

➡️ Next: [Module 14 — 100 MCQs](14-100-mcqs.md)

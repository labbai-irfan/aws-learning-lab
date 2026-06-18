# Module 15 — Hands-on Labs

> Do these in order. 💰 Most are free-tier-ish; delete dashboards/alarms and set log retention at the end to avoid charges.

**Setup once:** an EC2 instance (the Phase 06 app host is ideal), an instance role, and the AWS CLI.

---

## Lab 1 — Install the CloudWatch agent (memory + disk + logs)
**Goal:** see the metrics EC2 hides and ship app logs.
```bash
sudo yum install amazon-cloudwatch-agent -y
# write the config (see Module 3), then:
sudo amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
```
✅ **Verify:** `CWAgent` namespace shows `mem_used_percent` and `disk_used_percent`; `/hrms/api` log group receives events.

## Lab 2 — Push a custom metric
```bash
aws cloudwatch put-metric-data --namespace "HRMS/App" \
  --metric-name SignupCount --value 1 --unit Count --dimensions Env=prod
```
✅ **Verify:** metric appears under `HRMS/App`. Push a few values and graph the Sum.

## Lab 3 — Metric filter from logs
```bash
aws logs put-metric-filter --log-group-name /hrms/api \
  --filter-name api-errors --filter-pattern '{ $.level = "error" }' \
  --metric-transformations metricName=ApiErrorCount,metricNamespace=HRMS/App,metricValue=1,defaultValue=0
```
✅ **Verify:** write an error log line; `HRMS/App ApiErrorCount` increments.

## Lab 4 — Create an alarm + SNS notification
```bash
aws sns create-topic --name ops-notify
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:ACCT:ops-notify \
  --protocol email --notification-endpoint you@example.com   # confirm the email!

aws cloudwatch put-metric-alarm --alarm-name hrms-api-errors \
  --namespace HRMS/App --metric-name ApiErrorCount --statistic Sum \
  --period 300 --threshold 5 --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 --treat-missing-data notBreaching \
  --alarm-actions arn:aws:sns:us-east-1:ACCT:ops-notify
```
✅ **Verify:** generate 6 errors → alarm goes ALARM → email arrives.

## Lab 5 — Build a dashboard (as JSON)
```bash
aws cloudwatch put-dashboard --dashboard-name HRMS-Prod --dashboard-body file://dashboard.json
```
✅ **Verify:** dashboard shows user-impact, backend, DB, and a logs widget (use the [project dashboard.json](project/dashboard.json)).

## Lab 6 — Logs Insights queries
Run in the console (Logs Insights) on `/hrms/api`:
```
fields @timestamp, level, route, ms | filter level="error" | sort @timestamp desc | limit 20
filter ispresent(ms) | stats pct(ms,99) as p99 by route | sort p99 desc
```
✅ **Verify:** results return; pin one as a dashboard widget.

## Lab 7 — Composite alarm (cut noise)
Create child alarms `5xx-high` and `latency-high`, then:
```bash
aws cloudwatch put-composite-alarm --alarm-name hrms-user-impact \
  --alarm-rule "ALARM(\"5xx-high\") AND ALARM(\"latency-high\")" \
  --alarm-actions arn:aws:sns:us-east-1:ACCT:ops-page
```
✅ **Verify:** only the composite pages; children stay action-less.

## Lab 8 — EventBridge scheduled health check
```bash
aws events put-rule --name synthetic-healthcheck --schedule-expression "rate(5 minutes)"
aws events put-targets --rule synthetic-healthcheck \
  --targets "Id"="hc","Arn"="arn:aws:lambda:us-east-1:ACCT:function:healthcheck"
```
✅ **Verify:** Lambda runs every 5 min; emits a `HealthCheck` custom metric you can alarm on.

## Lab 9 — EventBridge pattern rule (RDS failover → Slack)
```bash
aws events put-rule --name rds-failover \
  --event-pattern '{"source":["aws.rds"],"detail-type":["RDS DB Instance Event"]}'
aws events put-targets --rule rds-failover \
  --targets "Id"="sns","Arn"="arn:aws:sns:us-east-1:ACCT:ops-page"
```
✅ **Verify:** force an RDS failover (Phase 06 Lab) → notification fires.

## Lab 10 — EC2 auto-recovery alarm
```bash
aws cloudwatch put-metric-alarm --alarm-name ec2-autorecover \
  --namespace AWS/EC2 --metric-name StatusCheckFailed_System \
  --dimensions Name=InstanceId,Value=i-0abc --statistic Maximum \
  --period 60 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:automate:us-east-1:ec2:recover
```
✅ **Verify:** alarm created with the `recover` action (self-heals on hardware failure).

## Lab 11 — Cause and observe an incident
- Run a CPU/memory stress or a slow query; watch the dashboard light up; investigate with Logs Insights; follow the matching [playbook](11-monitoring-playbooks.md).
✅ **Verify:** you can go alert → dashboard → logs → root cause in minutes.

---

## 🧹 Teardown
```bash
aws cloudwatch delete-alarms --alarm-names hrms-api-errors hrms-user-impact ec2-autorecover 5xx-high latency-high
aws cloudwatch delete-dashboards --dashboard-names HRMS-Prod
aws events remove-targets --rule synthetic-healthcheck --ids hc
aws events delete-rule --name synthetic-healthcheck
aws logs put-retention-policy --log-group-name /hrms/api --retention-in-days 7  # cap cost
```
💰 Confirm no never-expire log groups remain.

➡️ Next: [Capstone — Full observability for HRMS](project/README.md)

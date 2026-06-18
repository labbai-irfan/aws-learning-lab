# Module 5 — Alarms

> Metric alarms, composite alarms, anomaly detection, states, actions, and how to tune out the noise.

---

## 1. Alarm states
```
   OK                — metric within threshold
   ALARM             — threshold breached for the configured datapoints
   INSUFFICIENT_DATA — not enough data (new alarm, gaps, stopped resource)
```
Every **state transition** can trigger actions (notify, scale, recover). You can set different actions for entering ALARM vs returning to OK.

---

## 2. Anatomy of a metric alarm
```
   Metric:        AWS/RDS FreeStorageSpace (DBInstanceIdentifier=hrms-db)
   Statistic:     Average    Period: 300s
   Threshold:     < 5 GB
   Datapoints:    3 out of 3   (must breach 3 consecutive periods)
   Missing data:  treat as "breaching" | "notBreaching" | "ignore" | "missing"
   Actions:       ALARM -> SNS dba-alerts ;  OK -> SNS dba-alerts
```
Key knobs:
- **Period** — evaluation window (e.g. 60s, 300s).
- **Evaluation periods / datapoints-to-alarm** — `M of N`: require M breaching datapoints out of N to fire → smooths spikes.
- **Treat missing data** — critical for resources that stop/scale (see gotchas).
- **Comparison operator** — `>`, `>=`, `<`, anomaly band operators.

🛠️ Create an alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name hrms-db-low-storage \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=hrms-db \
  --statistic Average --period 300 --threshold 5000000000 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 3 --datapoints-to-alarm 2 \
  --treat-missing-data notBreaching \
  --alarm-actions arn:aws:sns:us-east-1:ACCT:dba-alerts \
  --ok-actions arn:aws:sns:us-east-1:ACCT:dba-alerts
```

---

## 3. Alarm actions
| Action | Use |
|---|---|
| **SNS** | Notify humans (email/SMS/Slack/PagerDuty via subscription) |
| **Auto Scaling** | Add/remove instances on load |
| **EC2 actions** | `recover` (on StatusCheckFailed_System), `reboot`, `stop`, `terminate` |
| **Systems Manager** | OpsItem / Incident Manager / run a runbook automation |
| **Lambda (via SNS/EventBridge)** | Auto-remediation |

💡 **EC2 auto-recovery:** an alarm on `StatusCheckFailed_System` with the `recover` action moves the instance to healthy hardware automatically — free self-healing for single instances.

---

## 4. Composite alarms (kill the noise)
A **composite alarm** combines other alarms with boolean logic:
```
   ALARM("hrms-api-5xx-high") AND ALARM("hrms-api-latency-high")
   => page on-call (real user impact)

   ALARM("cpu-high") AND NOT ALARM("deploy-in-progress")
   => only alert if high CPU isn't an expected deploy
```
- Reduces alert storms: notify on the **composite**, keep child alarms action-less.
- 🛠️ `aws cloudwatch put-composite-alarm --alarm-name hrms-user-impact --alarm-rule "ALARM('5xx') AND ALARM('latency')" ...`

---

## 5. Anomaly detection alarms
Instead of a fixed threshold, CloudWatch learns the metric's normal **band** (by hour/day seasonality) and alarms on deviation:
```
   ANOMALY_DETECTION_BAND(m_requests, 2)   # 2 std-dev band
   alarm when metric is outside the band
```
💡 Great for metrics with daily/weekly cycles (traffic, signups) where a static threshold is wrong at 3am vs noon. ⚠️ Needs ~2 weeks of data to train; costs more than a standard alarm.

---

## 6. Tuning alarms — avoid alert fatigue 🚨
| Problem | Fix |
|---|---|
| Flapping (OK↔ALARM) | Increase `M of N` datapoints; longer period |
| Spiky false alarms | Alarm on a sustained statistic (avg/p99 over N periods) |
| Stopped/scaled resource → false ALARM | Set `treat-missing-data` appropriately |
| Too many emails | Composite alarms; severity tiers; route low-sev to Slack not pager |
| Threshold wrong by time of day | Anomaly detection |
| No baseline | Alarm on **rates** (5xx %) not raw counts |

**Severity model** (used in [Module 9](09-alerting-system.md)):
- **Sev1 (page)** — user-facing outage: 5xx rate, p99 latency, healthy hosts = 0, DB down.
- **Sev2 (notify)** — degradation/approaching limits: CPU>80%, storage<15%, replica lag.
- **Sev3 (ticket)** — informational: cost anomaly, cert expiry soon.

---

## 7. Best-practice alarm set (web app)
- ALB: `HTTPCode_Target_5XX_Count` rate, `TargetResponseTime` p99, `UnHealthyHostCount`
- EC2: `CPUUtilization`, `StatusCheckFailed` (+recover), agent `mem_used_percent`, `disk_used_percent`
- RDS: `FreeStorageSpace`, `CPUUtilization`, `DatabaseConnections`, `FreeableMemory`, `ReplicaLag`
- App: custom `ApiErrorCount` (from metric filter), queue `ApproximateAgeOfOldestMessage`
- Composite: `5xx-high AND latency-high` → page

---

## ✅ Recap
- Alarms have 3 states; tune with **M-of-N datapoints** and **treat-missing-data**.
- Actions: SNS, Auto Scaling, EC2 recover/reboot, SSM, Lambda.
- **Composite** alarms cut noise; **anomaly detection** handles seasonal metrics.
- Alarm on **rates and percentiles**, build **severity tiers**, avoid fatigue.

➡️ Next: [Module 6 — Events (EventBridge)](06-events.md)

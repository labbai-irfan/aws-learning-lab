# Module 4 — Dashboards

> Build the "is production OK?" pane of glass: widgets, JSON-as-code, and cross-account/region views.

---

## 1. What a dashboard is
A **dashboard** is a saved page of **widgets** rendering metrics, logs, and alarms. Defined in the console or as **JSON** (so you can version-control and deploy it via IaC).

Widget types:
| Widget | Shows |
|---|---|
| Line / Stacked area | Metric trends over time |
| Number (single value) | Current value (e.g. active connections) |
| Gauge | Value vs range (e.g. CPU 0–100) |
| Text (markdown) | Headers, runbook links, legends |
| Logs table | Live Logs Insights query results |
| Alarm status | Red/green alarm grid |

---

## 2. Design principles (so the dashboard is actually useful)
💡 Organize **top-down, by the questions you ask during an incident**:
```
   Row 1  USER IMPACT     : ALB RequestCount · 5XX rate · p99 latency · healthy hosts
   Row 2  BACKEND         : EC2 CPU/mem/disk · API error count · queue depth
   Row 3  DATABASE        : RDS CPU · connections · FreeStorage · ReplicaLag
   Row 4  LOGS            : live "ERROR" Logs Insights table
   Row 5  ALARMS          : alarm-status grid (one glance = is anything red?)
```
- One dashboard per service/environment; a top-level "prod overview".
- Put **business metrics first** (the user-impact row) — that's what tells you if customers hurt.
- Add a **text widget** linking to the relevant [playbook](11-monitoring-playbooks.md).
- Use a consistent time range; annotate deploys via EventBridge.

---

## 3. Dashboard as JSON (version-controlled)
🛠️ Create/update from a JSON body:
```bash
aws cloudwatch put-dashboard --dashboard-name HRMS-Prod \
  --dashboard-body file://dashboard.json
```
Example widget (5xx rate via metric math):
```json
{
  "type": "metric", "x": 0, "y": 0, "width": 12, "height": 6,
  "properties": {
    "title": "ALB 5XX rate %",
    "region": "us-east-1",
    "metrics": [
      [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/hrms/abc", { "id": "r", "visible": false } ],
      [ ".", "HTTPCode_Target_5XX_Count", ".", ".", { "id": "e", "visible": false } ],
      [ { "expression": "100*(e/r)", "label": "5xx %", "id": "rate" } ]
    ],
    "stat": "Sum", "period": 300,
    "yAxis": { "left": { "min": 0 } }
  }
}
```
💡 Keep `dashboard.json` in your repo and deploy it with your app — dashboards drift if hand-edited in the console.

---

## 4. Cross-account & cross-region
- A **monitoring account** (CloudWatch cross-account observability) can render metrics/logs/alarms from many **source accounts** on one dashboard — ideal for fleets/Organizations.
- A single dashboard can mix widgets from **multiple regions** (set `region` per widget).

---

## 5. Beyond hand-built dashboards
- **Automatic dashboards** — AWS provides per-service default dashboards (EC2, RDS, Lambda…).
- **Container Insights / Lambda Insights** — curated dashboards for ECS/EKS/Lambda performance.
- **Metrics Explorer** — tag-based, auto-updating views (e.g. "all EC2 tagged Env=prod").

---

## 6. Cost & tips 💰
- First **3 dashboards free**, then per-dashboard/month.
- 💡 Prefer **fewer, denser dashboards** over many thin ones.
- Logs-table widgets re-run Logs Insights queries (scan cost) — keep their time window tight.

---

## ✅ Recap
- Dashboards = widgets answering incident questions, organized user-impact → backend → DB → logs → alarms.
- Manage them **as JSON in version control**; support cross-account/region.
- Put business metrics and playbook links front and center.

➡️ Next: [Module 5 — Alarms](05-alarms.md)

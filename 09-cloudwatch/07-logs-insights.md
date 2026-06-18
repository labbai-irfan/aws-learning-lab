# Module 7 — CloudWatch Logs Insights

> Query your logs interactively. The single most useful skill during an incident.

---

## 1. The query language
A pipeline of commands, left to right:
```
fields @timestamp, @message          # choose fields
| filter level = "error"             # narrow rows
| stats count(*) by route            # aggregate
| sort count desc                    # order
| limit 20                           # cap
```
Core commands: `fields`, `filter`, `stats`, `sort`, `limit`, `parse`, `dedup`, `display`.
Built-in fields: `@timestamp`, `@message`, `@logStream`, `@log`, `@ingestionTime`.

🛠️ Run from CLI:
```bash
aws logs start-query --log-group-name /hrms/api \
  --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s) \
  --query-string 'fields @timestamp,@message | filter level="error" | sort @timestamp desc | limit 50'
# then: aws logs get-query-results --query-id <id>
```

---

## 2. Structured vs unstructured logs
- **JSON logs** auto-parse into queryable fields: `filter statusCode >= 500`, `stats avg(ms)`.
- **Plain text** needs `parse` to extract:
```
fields @message
| parse @message "* - * [*] \"* *\" * *" as ip, user, time, method, path, status, bytes
| filter status >= 500
```
💡 Emit JSON from your app so you never have to write fragile `parse` patterns.

---

## 3. Incident-grade queries (copy/paste)

**Error rate over time**
```
fields @timestamp, @message
| filter level = "error"
| stats count(*) as errors by bin(5m)
| sort @timestamp desc
```

**Top failing routes**
```
filter statusCode >= 500
| stats count(*) as hits by route
| sort hits desc | limit 10
```

**p50 / p90 / p99 latency from logs**
```
filter ispresent(ms)
| stats avg(ms) as avg, pct(ms, 50) as p50, pct(ms, 90) as p90, pct(ms, 99) as p99 by route
| sort p99 desc
```

**Find one request's full trace (correlation id)**
```
fields @timestamp, level, route, msg
| filter requestId = "abc-123"
| sort @timestamp asc
```

**Count by HTTP status**
```
stats count(*) by statusCode | sort statusCode
```

**Who hit a specific error**
```
filter @message like /OutOfMemory/
| stats count(*) by @logStream
```

---

## 4. From query → dashboard → alarm
- Save useful queries; pin a query result as a **logs widget** on a dashboard ([Module 4](04-dashboards.md)).
- For recurring conditions, convert the pattern into a **metric filter** ([Module 3](03-logs-and-log-groups.md)) and **alarm** on it — Insights is for investigation, metric filters + alarms for continuous detection.

---

## 5. Cost & performance 💰
- Logs Insights bills **per GB of data scanned** per query.
- 💡 Always set a **tight time range** and **filter early**; query specific log groups, not all.
- Structured logs + retention discipline keep scans cheap.

---

## ✅ Recap
- Insights = piped query language (`fields | filter | stats | sort`).
- JSON logs auto-parse; use `parse` for text.
- Keep a library of incident queries; promote recurring ones to metric filters + alarms.
- Cost = GB scanned → narrow the time range.

➡️ Next: [Module 8 — Production Monitoring Setup](08-production-monitoring-setup.md)

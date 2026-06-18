# 16 — AWS X-Ray (Distributed Tracing & Observability)

> Metrics tell you *something* is slow; **traces** tell you *where*. X-Ray follows a single request across API Gateway → Lambda → DynamoDB → downstream calls, so you can pinpoint the slow or failing hop. A core observability topic for the **Developer Associate** and **DevOps** exams.

**By the end you can:**
- Read a service map and a trace timeline to find the bottleneck.
- Instrument Lambda, API Gateway, and containers/EC2 with X-Ray.
- Use sampling, annotations, and subsegments effectively.
- Tie traces, logs, and metrics together with CloudWatch ServiceLens.

**Prerequisites:** [01 — CloudWatch Core Concepts](01-cloudwatch-core-concepts.md), [Phase 10 — Serverless](../10-serverless/README.md).

---

## 1. The three pillars of observability

```
METRICS  → numbers over time   "p99 latency is 1.2s"     (CloudWatch metrics/alarms)
LOGS     → discrete events      "DB query failed: timeout" (CloudWatch Logs)
TRACES   → request journeys     "the 1.2s was 1.1s in RDS" (X-Ray)  ← this module
```
Metrics say *what*, logs say *why* at a point, **traces say where across services**. You need all three.

---

## 2. X-Ray vocabulary

```
TRACE  = the whole journey of ONE request (a unique trace ID)
 ├── SEGMENT      = work done by one service (e.g., the Lambda)
 │     ├── SUBSEGMENT = a unit within it (e.g., the DynamoDB call, an HTTP call)
 │     └── SUBSEGMENT = another downstream call
 └── SEGMENT      = work done by the next service
```

- **Trace ID** propagates via the `X-Amzn-Trace-Id` header so all services stamp the same trace.
- **Segment** = a service's contribution (timing, status, metadata).
- **Subsegment** = granular timing inside a segment (a specific SDK/HTTP/SQL call).
- **Annotations** = indexed key/values you can **filter/search** on (e.g., `userId`, `tenant`). Max 50.
- **Metadata** = extra non-indexed context (not searchable, but visible in the trace).

---

## 3. The service map

X-Ray aggregates traces into a **service map** — a visual graph of your components with latency, request rates, and error/fault/throttle percentages on each edge.

```
[Client] →● API Gateway (12ms) →● Lambda (avg 240ms, 2% faults)
                                       ├─►● DynamoDB (8ms)
                                       └─►● RDS (avg 190ms) ← the bottleneck lights up red
```
💡 Colors: green = OK, yellow/red = errors/faults, throttle highlighted. The map is where you *start* — then click into individual traces.

---

## 4. Status semantics
| Term | Meaning | HTTP |
|---|---|---|
| **Error** | Client-side problem | 4xx |
| **Fault** | Server-side problem | 5xx |
| **Throttle** | Rate-limited | 429 |

Filtering the map/traces by faults vs throttles tells you whether to fix the app or raise capacity/limits.

---

## 5. Instrumenting your services

**Lambda** — easiest: enable **Active Tracing** (one checkbox / `TracingConfig: Active`). The execution role needs `xray:PutTraceSegments` + `PutTelemetryRecords` (the `AWSXRayDaemonWriteAccess` policy). Wrap the SDK to trace downstream calls:
```js
// Node.js — auto-instrument AWS SDK + HTTP calls
const AWSXRay = require('aws-xray-sdk-core');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const ddb = AWSXRay.captureAWSv3Client(new DynamoDBClient({}));
// custom subsegment around a hot block:
const seg = AWSXRay.getSegment().addNewSubsegment('payroll-calc');
try { /* work */ } finally { seg.close(); }
```

**API Gateway** — enable X-Ray tracing on the stage; it starts the trace and links to the backend.

**ECS / EC2 / on-prem** — run the **X-Ray daemon** (or the ADOT/OpenTelemetry collector) as a sidecar/agent; the SDK sends segments to it over UDP, and it batches them to X-Ray.

**Annotations for searchability:**
```js
AWSXRay.getSegment().addAnnotation('tenant', tenantId);  // filter traces by tenant later
```

---

## 6. Sampling (control cost & volume)
You don't trace every request — you **sample**.
```
Default reservoir rule: 1 request/second, then 5% of the rest.
```
- Custom **sampling rules** target specific paths/services (e.g., trace 100% of `/payroll`, 1% of `/health`).
- Sampling keeps tracing cheap at scale while still catching representative slow/error traces.

---

## 7. CloudWatch ServiceLens (tie it together)
**ServiceLens** overlays X-Ray traces with CloudWatch metrics and logs on one map — click a node to jump from "this service is slow" → its traces → its logs, without switching tools. **CloudWatch Application Signals** builds on this for SLO tracking. This is the modern, unified observability view.

---

## 8. HRMS example

```
React SPA → API Gateway (traced) → Lambda (active tracing) ─► DynamoDB (subsegment)
                                                            └─► RDS payroll (subsegment)
Annotation: employeeId, requestType=payroll-run
```
- A payroll run feels slow → the **service map** shows the RDS edge at 190ms vs DynamoDB 8ms.
- Open a trace → the **RDS subsegment** dominates the timeline → add an index / connection pooling ([Phase 06 — RDS](../06-rds/README.md)).
- Filter traces by `annotation.requestType = "payroll-run"` to study only that path.

---

## 9. Cost & best practices ⚠️
- Billed per trace **recorded** and per trace **retrieved/scanned** — **sampling** is your main cost lever.
- Trace the paths that matter (checkout, payroll, login), sample health checks lightly.
- Add **annotations** for the dimensions you'll want to filter by (user, tenant, route) — but keep them ≤50 and low-cardinality-ish.
- Don't put secrets/PII in annotations or metadata.
- Combine with CloudWatch **alarms** (metrics) and **Logs Insights** (logs) — traces alone aren't a full monitoring strategy.

---

## 10. Quick reference
```
Trace        → one request end-to-end (X-Amzn-Trace-Id propagates it)
Segment      → one service's work
Subsegment   → a call within a service (SDK/HTTP/SQL)
Annotation   → indexed, searchable key/value (≤50)
Metadata     → extra context, not searchable
Service map  → visual graph: latency + error/fault/throttle per edge
Sampling     → reservoir (1/s) + percentage; custom rules per path
Lambda       → Active Tracing + xray write permissions
ECS/EC2      → X-Ray daemon / ADOT collector sidecar
ServiceLens  → traces + metrics + logs unified in CloudWatch
```

**Official docs:** https://docs.aws.amazon.com/xray/ · ServiceLens: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ServiceLens.html

---

*Back to [CloudWatch & Monitoring README](README.md). Related: [Phase 10 — Serverless](../10-serverless/README.md) · [Phase 06 — RDS monitoring](../06-rds/09-monitoring-guide.md).*

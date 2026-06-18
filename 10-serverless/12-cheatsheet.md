# 12 — Serverless Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Lambda](01-lambda-core-concepts.md).

## Lambda
| Limit | Value |
|---|---|
| Memory | 128 MB – 10,240 MB (CPU scales with it) |
| Timeout | 1 s – **900 s (15 min)** |
| Deploy package | 50 MB zipped / 250 MB unzipped · image 10 GB |
| /tmp | 512 MB – 10,240 MB |
| Concurrency (default) | 1,000/region (soft) |
| Payload | sync 6 MB · async 256 KB |
- **Invocation:** sync (API GW/ALB) · async (S3/SNS/EventBridge, 2 retries + DLQ) · poll (SQS/Kinesis/DDB Streams).
- **Cold start** fixes: provisioned concurrency, SnapStart, small packages, layers.
- VPC Lambda needs NAT or **VPC endpoints** for AWS API access.

## API Gateway
| Type | $/1M | Use |
|---|---|---|
| **REST** | $3.50 | Full features (API keys, usage plans, request validation, WAF) |
| **HTTP** | $1.00 | Cheaper, JWT/OIDC auth, simple proxies |
| **WebSocket** | $1.00 +msg | Bi-directional/real-time |
- Auth: Cognito authorizer / JWT authorizer / Lambda authorizer / IAM. Timeout 29 s.

## Messaging (decoupling)
| Service | Pattern |
|---|---|
| **SQS** | Queue (point-to-point); Standard (at-least-once) vs **FIFO** (ordered, exactly-once) |
| **SNS** | Pub/sub fan-out (push to many subscribers) |
| **EventBridge** | Event bus + routing rules + schemas + scheduler |
| **Step Functions** | Orchestration: **Standard** (≤1yr, durable) vs **Express** (≤5min, high-volume) |
- **Fan-out** = SNS → many SQS/Lambda. **DLQ** = capture failures, never lose events.
- **Idempotency** = safe to process the same event twice (use a dedupe key).

## DynamoDB (Module 08)
- Key = partition (+ optional sort). **Query** good, **Scan** bad. GSI (alt PK, eventual) / LSI (alt SK, create-time).
- On-demand vs provisioned (RCU/WCU). Streams → Lambda. TTL = free expiry. Transactions = 2× cost.

## Cognito (Module 09)
- **User Pool** = authN → JWTs (ID/access/refresh). **Identity Pool** = authZ → temp AWS creds.

## Exam triggers 💡
- "Decouple producer/consumer, buffer load" → **SQS**. "Notify many at once" → **SNS**.
- "Route events by content to many targets" → **EventBridge**.
- "Coordinate multi-step workflow with retries" → **Step Functions**.
- "Cheapest HTTP API, JWT auth" → **HTTP API**. "API keys/usage plans" → **REST API**.
- "Ordered, no duplicates" → **SQS FIFO**. "Eliminate cold starts" → **provisioned concurrency**.
- "Too many DB connections from Lambda" → **RDS Proxy** (relational) / DynamoDB (NoSQL).

## Gotchas ⚠️
- Lambda max 15 min — long jobs → Step Functions/Fargate.
- API Gateway hard 29 s timeout.
- SQS standard = **at-least-once** (design for duplicates).
- Async Lambda retries twice → configure a **DLQ**.

---
*Back to [Serverless README](README.md).*

# Phase 10: AWS Serverless Architecture — Complete Learning Repository

> **Role:** AWS Serverless Architect  
> **Level:** Intermediate → Advanced  
> **Focus:** Lambda, API Gateway, EventBridge, SQS, SNS, Step Functions

---

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Learning Path](#learning-path)
3. [Serverless Architecture](#serverless-architecture)
4. [Event-Driven Design](#event-driven-design)
5. [Cost Optimization](#cost-optimization)
6. [Security Design](#security-design)
7. [Real-World Projects](#real-world-projects)
8. [Quick Reference](#quick-reference)

---

## Repository Structure

```
10-serverless/
├── README.md                          ← You are here (incl. Security Design + Cost Optimization sections)
├── 01-lambda-core-concepts.md         ← Lambda deep dive
├── 02-api-gateway.md                  ← REST + HTTP + WebSocket APIs
├── 03-eventbridge.md                  ← Event routing & rules
├── 04-sqs-integration.md              ← Queue-based decoupling
├── 05-sns-integration.md              ← Pub/Sub messaging
├── 06-step-functions.md               ← Workflow orchestration
├── 07-serverless-patterns.md          ← Architecture patterns
├── 08-dynamodb.md                     ← DynamoDB deep dive (serverless NoSQL)
├── 09-cognito.md                      ← Authentication & authorization (user pools, JWT)
├── 10-interview-questions.md          ← 60+ interview Q&A
├── 11-troubleshooting.md              ← Debug playbook
├── 12-cheatsheet.md                   ← 1-page revision
├── 13-labs.md                         ← Hands-on labs (Lambda → Cognito → X-Ray)
├── 14-100-mcqs.md                     ← 100 MCQs
└── projects/
    ├── 01-ecommerce-order-processing/ ← Event-driven orders
    ├── 02-realtime-notifications/     ← SNS + Lambda + WebSocket
    ├── 03-data-pipeline/              ← S3 → Lambda → DynamoDB
    └── 04-api-backend/                ← API GW + Lambda + Cognito + DynamoDB
```

> **📝 Note:** runnable code examples live inline in each module and in the `projects/`.
> **Security Design** and **Cost Optimization** are covered in the inline sections of this README below.

---

## Learning Path

### Week 1 — Lambda Fundamentals
```
Day 1-2: Lambda execution model, cold starts, memory/timeout
Day 3-4: Triggers, event sources, destinations
Day 5-7: Layers, container images, function URLs
```

### Week 2 — API Gateway
```
Day 1-2: REST API vs HTTP API vs WebSocket API
Day 3-4: Authorizers (Cognito, Lambda, IAM)
Day 5-7: Request/response mapping, throttling, caching
```

### Week 3 — Messaging Services
```
Day 1-2: EventBridge rules, patterns, buses
Day 3-4: SQS standard vs FIFO queues
Day 5-7: SNS topics, filtering, fan-out pattern
```

### Week 4 — Orchestration & Production
```
Day 1-2: Step Functions Express vs Standard workflows
Day 3-4: Security, monitoring, X-Ray tracing
Day 5-7: Real-world projects + interview prep
```

---

## Serverless Architecture

### What Is Serverless?

Serverless does NOT mean "no servers." It means:
- **No server management** — AWS manages the compute fleet
- **Automatic scaling** — from 0 to 10,000 concurrent executions
- **Pay-per-use** — billed in milliseconds, not hours
- **Built-in HA** — multi-AZ by default

### Core Serverless Pillars

```
┌─────────────────────────────────────────────────────────┐
│                  SERVERLESS ARCHITECTURE                  │
├──────────────┬──────────────┬──────────────┬────────────┤
│   COMPUTE    │  MESSAGING   │   STORAGE    │  DATABASE  │
│              │              │              │            │
│  Lambda      │  SQS         │  S3          │  DynamoDB  │
│  Fargate     │  SNS         │  EFS         │  Aurora    │
│  App Runner  │  EventBridge │  S3 Glacier  │  Serverless│
└──────────────┴──────────────┴──────────────┴────────────┘
```

### Synchronous vs Asynchronous Invocation

```
SYNCHRONOUS (API Gateway, ALB, Function URL)
┌──────────┐   request    ┌────────┐   result   ┌──────────┐
│  Client  │ ──────────→  │ Lambda │ ──────────→ │  Client  │
└──────────┘              └────────┘             └──────────┘
  waits for response (max 29s for API Gateway)

ASYNCHRONOUS (S3, SNS, EventBridge)
┌──────────┐   event     ┌────────┐
│  Source  │ ──────────→ │ Lambda │ → processes independently
└──────────┘             └────────┘
  fire and forget; Lambda retries 2x on failure

POLL-BASED (SQS, Kinesis, DynamoDB Streams)
┌────────┐  polls   ┌──────┐  batch   ┌────────┐
│ Lambda │ ──────→  │  SQS │ ───────→ │ Lambda │
└────────┘          └──────┘          └────────┘
  Lambda polls queue; processes in batches
```

### Serverless Architecture Patterns

| Pattern | Services | Use Case |
|---|---|---|
| **API Backend** | API GW + Lambda + DynamoDB | REST APIs, mobile backends |
| **Fan-Out** | SNS + Lambda/SQS | Parallel processing |
| **Queue Worker** | SQS + Lambda | Async job processing |
| **Event Pipeline** | EventBridge + Lambda | System integration |
| **Saga Orchestration** | Step Functions + Lambda | Distributed transactions |
| **CQRS** | API GW + Lambda + DynamoDB Streams | Read/write separation |

---

## Event-Driven Design

### Principles

1. **Loose Coupling** — producers don't know consumers
2. **Async First** — don't wait if you don't have to
3. **Idempotency** — safe to process the same event twice
4. **Schema Registry** — events have defined contracts
5. **Dead Letter Queues** — capture failed events, never lose data

### Event Envelope Pattern

```json
{
  "version": "1.0",
  "id": "uuid-here",
  "source": "com.myapp.orders",
  "detail-type": "OrderPlaced",
  "time": "2026-06-17T10:00:00Z",
  "region": "us-east-1",
  "detail": {
    "orderId": "ORD-12345",
    "customerId": "CUST-789",
    "amount": 150.00,
    "items": [...]
  }
}
```

### Event-Driven Flow: Order Processing

```
Customer
   │ POST /orders
   ▼
API Gateway
   │ invokes
   ▼
Lambda (Order Service)
   │ validates & saves to DynamoDB
   │ publishes event to EventBridge
   ▼
EventBridge (default bus)
   │
   ├──→ Lambda (Inventory Service) ─→ Reserve stock
   ├──→ Lambda (Email Service)     ─→ Confirmation email
   ├──→ SQS (Payment Queue)        ─→ Lambda (Payment Service)
   └──→ SNS (Notification Topic)   ─→ Mobile push + SMS
```

---

## Cost Optimization

### Lambda Cost Formula

```
Cost = (Number of requests × $0.0000002)
     + (Duration GB-seconds × $0.0000166667)

Example: 1M requests, avg 200ms, 512MB memory
  Request cost:  1,000,000 × $0.0000002        = $0.20
  Duration cost: 1,000,000 × 0.2s × 0.5GB
                 × $0.0000166667                 = $1.67
  Total:                                         = $1.87/month
```

### Cost Optimization Strategies

#### 1. Right-Size Memory
```
- More memory = more CPU = faster execution = lower duration cost
- Test with AWS Lambda Power Tuning (Step Functions)
- Sweet spot is often 512MB-1024MB for most workloads

Benchmark example:
  128MB  → 2000ms → 0.256 GB-s
  512MB  → 400ms  → 0.200 GB-s  ✓ cheaper & faster
  1024MB → 150ms  → 0.150 GB-s  ✓ even better if CPU-bound
```

#### 2. Reduce Cold Starts
```
- Provisioned Concurrency: pre-warm functions (costs money, eliminates latency)
- Lambda SnapStart (Java 11+): snapshot & restore in <1s
- Keep packages lean: <50MB deployment package
- Use Lambda Layers for shared dependencies
```

#### 3. Batch Processing
```
SQS batch size: up to 10,000 messages per batch
Kinesis batch size: up to 10,000 records
Cost: 1 Lambda invocation per batch vs per message
```

#### 4. Architecture Cost Comparison

| Architecture | Monthly Cost (1M req/day) | Notes |
|---|---|---|
| EC2 t3.medium | ~$30 (fixed) | Running 24/7 |
| ECS Fargate | ~$15-40 | Container-based |
| Lambda + API GW | ~$3-8 | Pay per request |
| Lambda alone | ~$2-5 | No API GW overhead |

#### 5. API Gateway Cost Comparison

| Type | Price per 1M calls | Features |
|---|---|---|
| REST API | $3.50 | Full features, caching |
| HTTP API | $1.00 | 71% cheaper, OIDC/JWT |
| WebSocket | $1.00 + $0.25/million messages | Bi-directional |

**Use HTTP API when you don't need:** API keys, usage plans, request validation, AWS WAF.

---

## Security Design

### Defense in Depth

```
Internet
   │
   ▼
WAF (AWS WAF)            ← Layer 7: Block SQL injection, XSS
   │
   ▼
API Gateway              ← Rate limiting, API keys, throttling
   │
   ▼
Lambda Authorizer        ← JWT validation, custom auth logic
   │
   ▼
Lambda Function          ← IAM role, VPC, env var encryption
   │
   ▼
DynamoDB / RDS           ← VPC, encryption at rest, IAM auth
```

### IAM Least Privilege for Lambda

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789:table/Orders",
      "Condition": {
        "StringEquals": {
          "dynamodb:LeadingKeys": "${aws:PrincipalTag/UserId}"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### Secrets Management

```
NEVER → Hard-code secrets in code or environment variables
NEVER → Put secrets in Lambda environment variables unencrypted

DO USE:
  AWS Secrets Manager  → Credentials, API keys, DB passwords
  AWS SSM Parameter Store → Config values, non-sensitive params
  AWS KMS              → Encrypt environment variables at rest

Lambda pattern:
  import boto3, json, os
  def get_secret():
      client = boto3.client('secretsmanager')
      return json.loads(
          client.get_secret_value(SecretId=os.environ['SECRET_ARN'])['SecretString']
      )
```

### Network Security

```
Lambda in VPC:
  - Access RDS, ElastiCache, private resources
  - Needs NAT Gateway or VPC Endpoints for internet/AWS APIs
  - Interface Endpoints for: S3, DynamoDB, SNS, SQS, Lambda

VPC Endpoint costs: ~$7.20/month per endpoint
NAT Gateway costs: ~$32/month + $0.045/GB

For Lambda-only AWS API access → VPC Endpoints are cheaper
```

---

## Real-World Projects

### Project 1: E-Commerce Order Processing System
**File:** [projects/01-ecommerce-order-processing/](projects/01-ecommerce-order-processing/)

```
Services: API Gateway + Lambda + DynamoDB + EventBridge + SQS + SNS + Step Functions
Concepts: Saga pattern, idempotency, DLQ, error handling
```

### Project 2: Real-Time Notification System
**File:** [projects/02-realtime-notifications/](projects/02-realtime-notifications/)

```
Services: API Gateway WebSocket + Lambda + DynamoDB + SNS
Concepts: WebSocket connections, fan-out, connection management
```

### Project 3: Serverless Data Pipeline
**File:** [projects/03-data-pipeline/](projects/03-data-pipeline/)

```
Services: S3 + Lambda + SQS + DynamoDB + EventBridge
Concepts: Event-driven ETL, batch processing, error recovery
```

### Project 4: Multi-Tenant API Backend
**File:** [projects/04-api-backend/](projects/04-api-backend/)

```
Services: API Gateway + Lambda + Cognito + RDS Aurora Serverless
Concepts: JWT auth, connection pooling (RDS Proxy), caching
```

---

## Quick Reference

### Lambda Limits

| Limit | Value |
|---|---|
| Memory | 128MB – 10,240MB |
| Timeout | 1s – 900s (15 min) |
| Deployment package (zip) | 50MB (250MB unzipped) |
| Container image | 10GB |
| Concurrent executions (default) | 1,000 per region |
| /tmp storage | 512MB – 10,240MB |
| Environment variables | 4KB total |
| Payload (sync) | 6MB request, 6MB response |
| Payload (async) | 256KB |

### API Gateway Limits

| Limit | REST API | HTTP API |
|---|---|---|
| Timeout | 29s | 29s |
| Payload | 10MB | 10MB |
| Rate (default) | 10,000 RPS | 10,000 RPS |
| Burst | 5,000 | 5,000 |

### SQS Limits

| Attribute | Standard | FIFO |
|---|---|---|
| Throughput | Unlimited | 300 msg/s (3,000 with batching) |
| Message size | 256KB | 256KB |
| Retention | 1min – 14days | 1min – 14days |
| Visibility timeout | 0s – 12hrs | 0s – 12hrs |
| Receive wait time | 0 – 20s (long polling) | 0 – 20s |
| In-flight messages | 120,000 | 20,000 |

### SNS Limits

| Attribute | Value |
|---|---|
| Topics per account | 100,000 |
| Subscriptions per topic | 12,500,000 |
| Message size | 256KB |
| Message retention | Not stored (push only) |

### EventBridge Limits

| Attribute | Value |
|---|---|
| Rules per bus | 300 |
| Targets per rule | 5 |
| Event size | 256KB |
| PutEvents per second | 10,000 |

### Step Functions Limits

| Attribute | Standard | Express |
|---|---|---|
| Duration | Up to 1 year | Up to 5 minutes |
| Execution history | 25,000 events | CloudWatch Logs |
| Pricing | Per state transition | Per execution duration |
| Use case | Long-running workflows | High-volume, short workflows |

---

## Study Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [Serverless Land Patterns](https://serverlessland.com/patterns)
- [AWS Well-Architected Serverless Lens](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/)
- [Lambda Power Tuning Tool](https://github.com/alexcasalboni/aws-lambda-power-tuning)

---

*Repository Version: 1.0 | Last Updated: June 2026 | Phase 10 of AWS Learning Path*

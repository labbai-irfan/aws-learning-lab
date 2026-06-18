# 07 — Serverless Architecture Patterns

---

## Pattern 1: API Backend (BFF - Backend for Frontend)

```
Mobile App / Web App
        │
        ▼
  CloudFront (CDN)
        │
        ▼
  API Gateway HTTP API
  ├── /users     → Lambda: UserService
  ├── /products  → Lambda: ProductService
  ├── /orders    → Lambda: OrderService
  └── /search    → Lambda: SearchService (OpenSearch)

  Each Lambda connects to:
  ├── DynamoDB (primary data store)
  ├── ElastiCache Redis (caching layer)
  └── Secrets Manager (credentials)
```

**Best for:** Mobile/web backends, REST APIs, CRUD operations

---

## Pattern 2: Fan-Out / Fan-In

```
                 SNS Topic
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
    SQS Queue    SQS Queue    SQS Queue
    (email)      (inventory)  (analytics)
        │            │            │
        ▼            ▼            ▼
    Lambda       Lambda       Lambda
    (send email) (reserve)   (stream to DW)

Fan-In via Step Functions Parallel state:
  Parallel → results aggregated → next step
```

**Best for:** Broadcasting events, parallel processing with aggregation

---

## Pattern 3: Competing Consumers

```
High Volume Events → SQS Standard Queue
                          │
                    ┌─────┼─────┐
                    ▼     ▼     ▼
                Lambda Lambda Lambda
                 (up to 1000 concurrent)
                    │     │     │
                    └─────┼─────┘
                          ▼
                      DynamoDB
```

**Best for:** High-throughput message processing, job queues

---

## Pattern 4: Event Sourcing

```
Command → Lambda (write)
              │ Store event (not state)
              ▼
         DynamoDB (event log)
              │ DynamoDB Streams
              ▼
         Lambda (projections)
              │ Build read models
              ▼
         DynamoDB (read models) → API Gateway → Queries
```

**Best for:** Audit trails, temporal queries, microservices with complex domains

---

## Pattern 5: Strangler Fig (Migration)

```
Legacy System
     │
     ▼
CloudFront (router)
  ├── /api/v2/* → API Gateway + Lambda (new)
  └── /api/v1/* → Legacy EC2/ECS (old)

Gradually migrate routes from legacy to serverless
```

**Best for:** Incremental migration from monolith to serverless

---

## Pattern 6: CQRS (Command Query Responsibility Segregation)

```
WRITE PATH (Commands):
API GW → Lambda (command handler)
              │ validate + save event
              ▼
         DynamoDB (events table)
              │ streams
              ▼
         Lambda (event processor)
              │ build read model
              ▼
         DynamoDB (read models table)

READ PATH (Queries):
API GW → Lambda (query handler) → DynamoDB (read models)
```

**Best for:** Complex domains with different read/write requirements

---

## Pattern 7: Transactional Outbox

Problem: Atomically save to DB AND publish event.

```
Lambda
  │ DynamoDB TransactWrite:
  │   ├── Write order record
  │   └── Write outbox entry (status=PENDING)
  │
  ▼
DynamoDB Streams
  │
  ▼
EventBridge Pipes (filter: outbox table changes)
  │
  ▼
Lambda (publish to EventBridge bus + mark outbox SENT)
```

**Best for:** Guaranteed event delivery with DB write atomicity

---

## Pattern 8: Choreography vs Orchestration Decision

```
Use CHOREOGRAPHY (EventBridge) when:
  ✓ Services are loosely coupled
  ✓ New consumers can be added without modifying publisher
  ✓ Simple, independent reactions to events
  ✓ High-scale fan-out (many consumers)
  ✗ Avoid when: Need to track overall workflow state

Use ORCHESTRATION (Step Functions) when:
  ✓ Complex multi-step business process
  ✓ Need compensating transactions (Saga)
  ✓ Human approval required
  ✓ Visibility into overall workflow state required
  ✓ Conditional branching based on results
  ✗ Avoid when: Simple fan-out notifications
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Lambda Calling Lambda Synchronously

```
BAD:
Lambda A → invokes Lambda B directly (synchronous)
                    │ waits for response
Lambda A → invokes Lambda C directly
                    │ waits for response

Problems:
  - Tight coupling (A knows about B and C)
  - If B is slow, A times out
  - Costs: 2x Lambda time (A waits while B runs)
  - Hard to change B without updating A

GOOD: Use SQS or Step Functions
Lambda A → SQS → Lambda B (decoupled, async)
Lambda A → Step Functions → orchestrates B and C
```

### Anti-Pattern 2: Storing State in Lambda

```
BAD:
class GlobalState:
    cache = {}  # shared across invocations? NO!

GOOD: Use external state stores
  - DynamoDB for persistent state
  - ElastiCache Redis for ephemeral cache
  - S3 for large objects
  - /tmp for within-invocation only
```

### Anti-Pattern 3: Very Long Lambda Functions

```
BAD: 14-minute Lambda processing a large file
  - Expensive (pay for idle wait)
  - No visibility into progress
  - Retry retries entire job

GOOD: Use Step Functions + Map state
  - Split work into chunks
  - Process chunks in parallel (Map)
  - Track progress in Step Functions execution history
  - Retry failed chunks only
```

### Anti-Pattern 4: One Lambda Per REST Endpoint

```
BAD (Lambda proliferation):
  GET /users     → lambda-get-users
  POST /users    → lambda-create-user
  GET /users/123 → lambda-get-user-by-id
  PUT /users/123 → lambda-update-user
  ... (100+ functions)

GOOD (service-level grouping):
  UserService Lambda → handles all /users routes
  ProductService Lambda → handles all /products routes

  Best: Monorepo with shared code, route inside Lambda
  Use: aws-lambda-powertools Router
```

### Anti-Pattern 5: Ignoring Cold Starts for APIs

```
BAD: Customer-facing API with Java Lambda, no provisioned concurrency
     First request: 4 second cold start → terrible UX

GOOD:
  - Provisioned concurrency for critical paths
  - Or use Node.js/Python (sub-500ms cold start)
  - Or cache at CloudFront to reduce Lambda invocations
```

---

## Serverless Decision Framework

```
Is the workload:
  
  Stateless and event-driven?         → Lambda ✓
  Long-running (> 15 min)?           → Fargate, EC2, Batch
  Requires persistent connections?   → ECS + ALB
  
Traffic pattern:
  Spiky / unpredictable?             → Serverless (auto-scale to 0)
  Steady state, high volume?         → EC2/ECS (fixed cost, lower per-unit)
  
Data processing:
  Real-time stream?                  → Lambda + Kinesis
  Batch (large file)?                → Lambda + S3 or Glue
  
Latency requirement:
  < 100ms p99?                       → Provisioned concurrency
  < 1s p99?                          → Lambda (Node.js/Python)
  < 5s p99?                          → Lambda (any runtime)
```

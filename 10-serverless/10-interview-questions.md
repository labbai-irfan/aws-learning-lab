# 10 — Interview Questions & Answers: AWS Serverless

> 65 questions across Beginner → Senior Architect level.

---

## Lambda

### Q1: What is the difference between synchronous and asynchronous Lambda invocations?

**Answer:**

**Synchronous:** The caller waits for the Lambda response. If Lambda fails, the error is returned directly to the caller. Examples: API Gateway, ALB, Lambda Function URLs. Max wait: 29s for API Gateway, 15min for direct invocation.

**Asynchronous:** The caller sends the event and immediately gets back a 202 Accepted. Lambda processes independently. On failure, Lambda retries twice with exponential backoff. Events can be routed to DLQ or Destinations. Examples: S3, SNS, EventBridge.

**Poll-based (Event Source Mapping):** Lambda polls the source (SQS, Kinesis, DynamoDB Streams) and invokes itself with a batch of records. Retries until success or data expiry.

---

### Q2: What causes a Lambda cold start and how do you mitigate it?

**Answer:**

**Causes:**
- First invocation after deployment
- Scaling beyond existing warm instances (burst)
- Inactivity (no requests for ~15 minutes)

**Mitigation strategies:**
1. **Provisioned Concurrency** — pre-warms N environments; eliminates cold starts for those environments but adds cost (~$0.015/GB-hour)
2. **Lambda SnapStart (Java)** — snapshots initialized environment; restores from snapshot instead of initializing
3. **Minimize package size** — smaller = faster download and initialization
4. **Choose lighter runtimes** — Node.js/Python cold start is much faster than Java/.NET
5. **Lazy loading** — import only what's needed
6. **Lambda Layers** — shared dependencies don't re-download
7. **Scheduled warm-up pings** (free but not 100% reliable for burst scenarios)

---

### Q3: How does Lambda concurrency work? What's the difference between reserved and provisioned concurrency?

**Answer:**

**Concurrency** = number of simultaneous function instances (requests being processed at the same time).

Account default: 1,000 concurrent executions per region (soft limit, can increase).

**Reserved Concurrency:**
- Sets a MAXIMUM and GUARANTEED amount for a function
- Other functions cannot use this capacity
- If invocations exceed reserved limit → 429 ThrottleException
- Cost: FREE
- Use when: protecting downstream services, preventing one function from consuming all capacity

**Provisioned Concurrency:**
- Pre-initializes N execution environments (eliminates cold starts for those N)
- Charged even when idle (~$0.015/GB-hour)
- Combined with reserved concurrency (reserved must be ≥ provisioned)
- Use when: consistent low-latency required (user-facing APIs)

---

### Q4: What is the Lambda execution environment lifecycle?

**Answer:**

1. **Init phase (cold start):** Download code, start runtime, run initialization code outside handler, create execution environment
2. **Invoke phase:** Run the handler function for each invocation; execution environment is reused for subsequent calls (warm)
3. **Shutdown phase:** Lambda sends SIGTERM; extensions have 2 seconds to clean up; environment is destroyed

**Implication:** Code outside the handler runs once (per cold start). Use this for SDK client initialization, DB connections, config loading — these are reused across invocations.

---

### Q5: What are Lambda Layers and when would you use them?

**Answer:**

Layers are ZIP archives that can be attached to Lambda functions (up to 5 per function). They appear in `/opt/` inside the execution environment.

**Use cases:**
- Shared libraries across multiple functions (utilities, logging)
- Large dependencies (numpy, pandas) to keep function package small
- Custom runtimes
- Security agents or monitoring tools (Datadog, New Relic)

**Limits:**
- 5 layers per function
- Total unzipped size (code + layers): 250MB
- Layer path: `/opt/python/` (Python), `/opt/nodejs/node_modules/` (Node.js)

---

### Q6: How do you handle errors in Lambda with SQS?

**Answer:**

**Without partial batch reporting:**
- If any message fails → entire batch is returned to queue
- All messages (including successful ones) are retried
- Can lead to duplicate processing

**With ReportBatchItemFailures (best practice):**
- Lambda returns `{ batchItemFailures: [{ itemIdentifier: messageId }] }`
- Only failed messages return to queue; successful messages are deleted
- Requires: FunctionResponseTypes = ["ReportBatchItemFailures"] on ESM

**Error types to differentiate:**
- Retryable (transient): DB timeout, throttling → add to batchItemFailures
- Permanent (data issue): validation failure → log and skip (don't retry); let it go to DLQ after maxReceiveCount

---

### Q7: What is the /tmp directory in Lambda and what are its limits?

**Answer:**

`/tmp` is ephemeral local storage within the Lambda execution environment.

- Default size: 512MB (can increase to 10,240MB)
- Persists between invocations of the SAME warm environment
- NOT shared between different Lambda instances
- Destroyed when execution environment is destroyed

**Use cases:** Caching downloaded files, temporary file processing, ML model caching

**Security note:** Don't store sensitive data in /tmp; it could persist to the next invocation if the environment is reused.

---

## API Gateway

### Q8: When would you choose HTTP API over REST API?

**Answer:**

**Choose HTTP API when:**
- Cost is a concern (71% cheaper: $1.00 vs $3.50 per million)
- You need JWT/OIDC authorization (Cognito, Auth0, Okta)
- Building standard CRUD APIs
- You don't need: WAF, caching, request/response transformation (VTL), API keys/usage plans, private APIs, edge-optimized endpoints

**Choose REST API when:**
- Need AWS WAF integration
- Need response caching
- Need request/response transformation (VTL mapping templates)
- Need API keys and usage plans
- Need to directly integrate with AWS services (SQS, DynamoDB) without Lambda
- Need private endpoints within VPC

---

### Q9: Explain Lambda Authorizer types and caching.

**Answer:**

**Token-based:** Receives the Authorization header value; returns IAM policy. Client sends JWT/OAuth token.

**Request-based:** Receives the full request (headers, query params, path, body); more flexible for multi-factor authorization logic.

**Caching:**
- Results are cached per cache key (token value or request parameters)
- TTL: 0–3600 seconds (default 300s)
- Caching reduces Lambda invocations = lower cost + lower latency
- Cache key for token-based: Authorization header value
- Disable caching for highly dynamic authorization (per-request context needed)

---

### Q10: What is the difference between API Gateway stages and canary deployments?

**Answer:**

**Stages:** Named deployment snapshots (dev, staging, prod). Each stage has its own URL, settings, throttling, and stage variables.

**Canary Deployment:**
- Split traffic between current stage (baseline) and new deployment (canary)
- Example: 10% to new Lambda version, 90% to current
- Monitor errors on canary before full deployment
- Promote canary → becomes new baseline
- Roll back if canary shows errors

```bash
aws apigateway update-stage --rest-api-id abc123 --stage-name prod \
    --patch-operations \
    op=replace,path=/canarySettings/percentTraffic,value=10 \
    op=replace,path=/canarySettings/deploymentId,value=new-deploy-id
```

---

## EventBridge

### Q11: What are the differences between EventBridge, SNS, and SQS for event routing?

**Answer:**

| | EventBridge | SNS | SQS |
|---|---|---|---|
| Model | Push event bus | Push pub/sub | Pull queue |
| Routing | Content-based (any JSON field) | Attribute-based | N/A |
| Storage | No (archive optional) | No | Yes (14 days) |
| Replay | Yes (archive) | No | Via DLQ redrive |
| SaaS integration | Yes (50+) | No | No |
| Schema registry | Yes | No | No |
| Best for | System integration | Fan-out notifications | Job queues |

**Rule:** Use SQS when you need reliable, buffered processing. Use SNS for immediate fan-out notifications. Use EventBridge for complex routing, SaaS integrations, or schema discovery.

---

### Q12: How does EventBridge event pattern matching work?

**Answer:**

EventBridge filters events using JSON patterns. A rule matches if all specified conditions are true (AND logic). Within an array of values, any value can match (OR logic).

**Key matchers:**
- Exact value: `"status": ["PENDING"]`
- Multiple values (OR): `"status": ["PENDING", "PROCESSING"]`
- Numeric range: `"amount": [{"numeric": [">", 100]}]`
- Prefix: `"orderId": [{"prefix": "VIP-"}]`
- Exists/not exists: `"promoCode": [{"exists": true}]`
- Anything-but: `"status": [{"anything-but": ["CANCELLED"]}]`
- Wildcard: `"email": [{"wildcard": "*@company.com"}]`

---

### Q13: What is the EventBridge Archive and Replay feature and when would you use it?

**Answer:**

**Archive:** Continuously stores events matching a filter pattern. Configurable retention (1 day to indefinite).

**Replay:** Re-publishes archived events to any bus (same or different), within a specified time range.

**Use cases:**
- **New consumer deployment:** Deploy new microservice, replay historical events to bring it up-to-date
- **Bug fix validation:** After fixing a bug in a consumer, replay events from the failure window
- **Disaster recovery:** Replay events after a consumer outage
- **Testing:** Replay production events in staging environment

**Cost:** Storage cost for archived events + replay execution cost.

---

## SQS

### Q14: What is the SQS visibility timeout and how should it be set?

**Answer:**

Visibility timeout is the period during which SQS prevents other consumers from receiving a message that has been retrieved.

**Lifecycle:**
1. Consumer receives message → message becomes invisible
2. Consumer processes → deletes message (success)
3. OR consumer fails → visibility timeout expires → message reappears

**Setting guidelines:**
- Must be GREATER than your Lambda timeout
- Formula: `Visibility Timeout = Lambda Timeout × 1.5 + buffer`
- If Lambda times out at 60s: set VT to 90s
- Maximum: 12 hours
- Default: 30 seconds

**Risk if too short:** Lambda times out, message becomes visible again → processed twice (duplication)
**Risk if too long:** Failed messages take too long to retry

---

### Q15: Explain the difference between SQS Standard and FIFO queues.

**Answer:**

**Standard Queue:**
- **Throughput:** Nearly unlimited (3,000+ TPS per API action)
- **Delivery:** At-least-once (message may be delivered more than once)
- **Ordering:** Best-effort (not guaranteed)
- **Deduplication:** None built-in
- **Use when:** High throughput needed, processing is idempotent, order doesn't matter
- **Cost:** $0.40 per million messages

**FIFO Queue:**
- **Throughput:** 300 TPS (3,000 with batching)
- **Delivery:** Exactly-once (within 5-minute deduplication window)
- **Ordering:** Strict FIFO within message group
- **Message Groups:** Multiple parallel FIFO lanes (1 consumer per group)
- **Name suffix:** Must end with `.fifo`
- **Use when:** Order matters (state transitions), cannot process duplicates (payments)
- **Cost:** $0.50 per million messages

---

### Q16: What is the SQS Dead Letter Queue (DLQ) and how do you use it?

**Answer:**

A DLQ is a separate queue where messages are sent after failing maxReceiveCount times.

**Configuration:**
```json
{
  "RedrivePolicy": {
    "deadLetterTargetArn": "arn:aws:sqs:...:my-dlq",
    "maxReceiveCount": 3
  }
}
```

**maxReceiveCount:** How many times a message is received (attempted) before going to DLQ.

**Operations:**
1. **Monitor:** CloudWatch alarm on `ApproximateNumberOfMessagesVisible` > 0
2. **Investigate:** Inspect DLQ messages to understand failure reason
3. **Fix:** Fix the bug in your consumer
4. **Redrive:** Use SQS DLQ Redrive to move messages back to source queue
5. **Verify:** Process completes successfully

**DLQ retention:** Set to max (14 days) to have time to investigate and fix.

---

## SNS

### Q17: How does SNS message filtering work and what are its limitations?

**Answer:**

**Message filtering:** Each subscription can have a filter policy. SNS only delivers messages matching the filter. By default, filtering applies to message attributes.

**FilterPolicyScope:**
- `MessageAttributes` (default): Filter against `MessageAttribute` fields
- `MessageBody`: Filter against JSON body fields (more flexible, requires JSON body)

**Limitations:**
- Maximum 5 filter policies per subscription (5 AND conditions)
- Attribute-based filtering limited to string and numeric comparisons
- MessageBody filtering: message must be valid JSON
- Cannot filter on message ID, timestamp, or SNS metadata

---

### Q18: Why use SNS → SQS → Lambda instead of SNS → Lambda directly?

**Answer:**

**SNS → Lambda directly (problems):**
- Lambda throttles → SNS retries 3 times → message dropped
- No buffering during Lambda cold start surge
- No control over processing concurrency
- No persistence if Lambda is down

**SNS → SQS → Lambda (benefits):**
- **Durability:** SQS stores messages up to 14 days
- **Buffering:** SQS absorbs traffic spikes while Lambda scales
- **Retry:** SQS retries failed messages independently per consumer
- **DLQ:** Capture permanently failed messages
- **Concurrency control:** Reserved concurrency on Lambda limits processing rate
- **Independent scaling:** Each consumer (SQS+Lambda) scales independently

This is the recommended fan-out pattern for reliable event processing.

---

## Step Functions

### Q19: What is the difference between Standard and Express workflows?

**Answer:**

**Standard Workflows:**
- Max duration: 1 year
- Pricing: $0.025 per 1,000 state transitions
- History: stored in Step Functions (searchable, up to 25,000 events)
- Execution model: Exactly-once (at-most-once)
- Use for: Long-running business processes, audit trails, human approval, financial transactions

**Express Workflows:**
- Max duration: 5 minutes
- Pricing: Based on executions + duration (much cheaper at high volume)
- History: CloudWatch Logs only
- Execution model: At-least-once (may run state twice on failure)
- Supports: StartSyncExecution (synchronous invocation)
- Use for: High-volume event processing, IoT, streaming data, short ETL

---

### Q20: What is the Saga pattern and how do you implement it with Step Functions?

**Answer:**

The Saga pattern manages distributed transactions across microservices by executing a sequence of local transactions. If any step fails, compensating transactions undo the previous steps.

**Order processing saga:**
1. Reserve Inventory → if fails: nothing to undo
2. Charge Payment → if fails: Release Inventory
3. Create Shipment → if fails: Refund Payment + Release Inventory

**Implementation with Step Functions:**
- Each step has a Catch that routes to the compensating transaction
- Compensating transactions run in reverse order
- Final state is either OrderComplete or OrderFailed (compensated)

```json
"ChargePayment": {
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "Next": "ReleaseInventory"  // compensate previous step
  }]
},
"ReleaseInventory": {
  "Type": "Task",
  "Next": "OrderFailed"
}
```

---

### Q21: What is the Task Token pattern in Step Functions?

**Answer:**

The Task Token pattern allows Step Functions to pause and wait for an external system to resume execution. The state machine generates a unique task token, passes it to an external system, and waits. The external system calls `SendTaskSuccess` or `SendTaskFailure` to resume.

**Use cases:**
- Human approval workflows (manager approves expense)
- Waiting for external API callback
- Long-running external processes

**How it works:**
1. State uses `Resource: arn:aws:states:::lambda:invoke.waitForTaskToken`
2. `$$.Task.Token` is passed in the payload to the Lambda/service
3. Lambda stores token, sends to external system (email link, etc.)
4. External system calls `sfn.send_task_success(taskToken=..., output=...)`
5. Step Functions resumes the next state

**Timeout:** Set `TimeoutSeconds` to avoid waiting forever if the external system never responds.

---

## Architecture

### Q22: How do you implement idempotency in serverless functions?

**Answer:**

Idempotency means processing the same event multiple times produces the same result (no side effects from duplicates).

**Pattern: Conditional write with DynamoDB:**
```python
def already_processed(idempotency_key):
    try:
        table.put_item(
            Item={'key': idempotency_key, 'ttl': now + 86400},
            ConditionExpression='attribute_not_exists(#k)',
            ExpressionAttributeNames={'#k': 'key'}
        )
        return False  # first time
    except ConditionalCheckFailedException:
        return True   # already processed
```

**Powertools for AWS Lambda:**
```python
from aws_lambda_powertools.utilities.idempotency import idempotent

@idempotent(persistence_store=DynamoDBPersistenceLayer(table_name="IdempotencyTable"))
def handler(event, context):
    # Automatically idempotent based on event hash
    return process_order(event)
```

**Key:** Generate idempotency key from business data (not AWS request ID — that changes on retry).

---

### Q23: How do you handle Lambda cold starts for a user-facing API?

**Answer:**

**Option 1: Provisioned Concurrency (best for consistent low latency)**
- Pre-warm N instances
- Cost: ~$0.015/GB-hour regardless of traffic
- Set on alias or version (not $LATEST)
- Can auto-scale with Application Auto Scaling

**Option 2: Lambda SnapStart (Java)**
- Snapshot initialized environment
- 90% reduction in cold start time
- No extra cost for pre-warming

**Option 3: HTTP API + lightweight runtime**
- HTTP API is faster than REST API (lower overhead)
- Node.js/Python cold starts are much faster than Java

**Option 4: Architecture change**
- Move to container (ECS/Fargate) for consistently low latency
- Use caching (CloudFront, API GW cache) to reduce Lambda invocations

**Option 5: Scheduled warming (cost-free, not perfect)**
- EventBridge rule every 5 min → Lambda ping
- Only keeps specific instances warm, not all concurrent slots

---

### Q24: How do you design a serverless API for 1 million requests per day?

**Answer:**

**Traffic calculation:**
- 1M req/day = ~12 req/sec average
- Assume 10x peak = 120 req/sec peak
- At 200ms avg duration: 120 × 0.2 = 24 concurrent Lambda instances

**Architecture:**
```
CloudFront (CDN + Cache for GET requests)
    ↓
API Gateway HTTP API
    ↓
Lambda (right-sized: 512MB, 30s timeout)
    ↓
DynamoDB (on-demand capacity)
```

**Cost estimate (1M req/day = 30M/month):**
- API Gateway HTTP: 30M × $1/M = $30
- Lambda: 30M × 200ms × 0.5GB × $0.0000166667 = $50
- DynamoDB on-demand: ~$20 (depends on RCU/WCU)
- Total: ~$100/month (vs EC2 t3.large = $120/month fixed)

**Optimizations:**
- Cache GET responses in CloudFront (reduce Lambda invocations)
- Use DynamoDB DAX for sub-ms reads
- Increase Lambda memory if CPU-bound (1024MB may be faster + cheaper)

---

### Q25: How do you implement blue/green deployment for Lambda?

**Answer:**

**Lambda Aliases + Weighted Routing:**
```bash
# Deploy new version
aws lambda publish-version --function-name my-function

# Update alias to route 10% to new version
aws lambda update-alias \
    --function-name my-function \
    --name PROD \
    --routing-config '{"AdditionalVersionWeights":{"2": 0.10}}'

# Monitor for errors, then gradually increase:
# 10% → 25% → 50% → 100%

# Full cutover
aws lambda update-alias \
    --function-name my-function \
    --name PROD \
    --function-version 2 \
    --routing-config '{}'
```

**With CodeDeploy (automated rollback):**
- Linear10PercentEvery1Minute
- Linear10PercentEvery3Minutes
- Canary10Percent5Minutes
- AllAtOnce

CodeDeploy monitors CloudWatch alarms; if errors detected → auto-rollback.

---

### Q26: What are the security best practices for Lambda?

**Answer:**

1. **Least privilege IAM:** Grant only the specific actions on specific resources needed; avoid wildcard `*` resources
2. **No hardcoded secrets:** Use Secrets Manager or SSM Parameter Store; reference by ARN in environment variables
3. **Encrypt environment variables:** Use KMS CMK for sensitive env vars (not just AWS managed key)
4. **VPC placement:** Put Lambda in VPC only if needed (requires NAT GW for internet + adds cold start latency)
5. **Function URLs:** Disable public function URLs unless required; use IAM_AUTH or custom auth
6. **Input validation:** Validate and sanitize all inputs at the boundary
7. **Lambda Authorizers:** Validate tokens before any business logic runs
8. **Logging:** Never log secrets, tokens, or PII; use structured logging
9. **Resource-based policies:** Restrict which services/accounts can invoke your function
10. **Code signing:** Use Lambda code signing to prevent unauthorized code deployment

---

### Q27: How do you troubleshoot Lambda timeouts?

**Answer:**

**Investigation steps:**

1. **CloudWatch Logs:** Look for timeout message: `Task timed out after X seconds`
2. **X-Ray Trace:** Identify which downstream call is slow (DynamoDB, external API, etc.)
3. **CloudWatch Metrics:** Check Duration p99 vs timeout setting

**Common causes:**
- Database connection taking too long (cold start + VPC Lambda)
- External HTTP call without timeout set
- DynamoDB throttling
- Large payload processing
- Memory exhaustion (swapping to disk)

**Fixes:**
- Add timeout to all external calls
- Initialize DB connections outside handler (reuse on warm start)
- Increase Lambda memory (more CPU = faster processing)
- Add connection pool (RDS Proxy for RDS)
- Use async where possible (don't wait for non-critical operations)
- Break large processing into smaller chunks (SQS + smaller batches)

---

### Q28: What is the difference between orchestration and choreography in microservices?

**Answer:**

**Orchestration (Step Functions):**
- Central coordinator controls the workflow
- Each service reports back to the orchestrator
- Clear visibility of workflow state
- Easier to add/remove steps
- Single point of truth for workflow state
- Risk: orchestrator can become a bottleneck

```
Step Functions → Service A → Step Functions → Service B → Step Functions → Service C
```

**Choreography (EventBridge/SNS):**
- Services react to events without central coordinator
- Publish events, don't call services directly
- Looser coupling
- Harder to debug (trace an event through multiple services)
- Emergent behavior can be complex

```
Service A publishes event → EventBridge → Service B reacts → publishes event → Service C reacts
```

**When to choose:**
- **Orchestration:** Complex multi-step transactions, need visibility/audit, saga compensation, human approval
- **Choreography:** Simple event notifications, many independent consumers, maximum loose coupling

---

## Troubleshooting Scenarios

### Q29: Lambda is receiving duplicate SQS messages. What's wrong?

**Possible causes:**
1. **Visibility timeout too short:** Message reappears before Lambda finishes processing → set VT > Lambda timeout × 1.5
2. **Lambda timing out:** Same root cause
3. **ReportBatchItemFailures not configured:** Entire batch retried including successes
4. **SQS Standard queue:** At-least-once delivery by design — implement idempotency
5. **Multiple ESM triggers:** Function has two SQS event source mappings to the same queue

**Fix:** 
- Check VT vs timeout
- Add idempotency check
- Use FIFO queue if exactly-once required

---

### Q30: API Gateway returns 502 Bad Gateway. What do you check?

**Possible causes:**
1. **Lambda crashed:** Exception not caught → check CloudWatch Logs
2. **Lambda response format wrong:** Must return `{statusCode, body, headers}` — missing `statusCode` → 502
3. **Lambda timeout:** 29s for API Gateway, Lambda still running → 502
4. **Lambda not returning JSON string for body:** Must be `json.dumps({...})` not a dict
5. **Lambda permissions:** API Gateway doesn't have permission to invoke Lambda
6. **Lambda in VPC:** ENI not ready (cold start + VPC) → timeout

**Check order:**
1. CloudWatch Logs for Lambda errors
2. API Gateway execution logs (enable in stage settings)
3. X-Ray traces
4. Lambda response format

---

## Quick-Fire Questions

### Q31: What is the maximum SQS message size?
**256KB.** For larger payloads, use S3 + SQS pointer pattern.

### Q32: Can Lambda access VPC resources?
**Yes.** Enable VPC configuration on Lambda (specify subnets + security group). Requires NAT Gateway or VPC Endpoints for internet/AWS API access.

### Q33: What is Lambda SnapStart?
Available for **Java 11+** runtimes. AWS snapshots the initialized execution environment and restores from that snapshot instead of initializing from scratch. Reduces cold start from seconds to ~200ms. Enabled per published version.

### Q34: What's the maximum timeout for API Gateway?
**29 seconds** for REST and HTTP APIs. For WebSocket, connection can persist longer.

### Q35: Can EventBridge trigger another EventBridge bus?
**Yes.** You can route events to another bus in the same or different account/region. This is how cross-account event routing works.

### Q36: What is SQS Long Polling?
Setting `WaitTimeSeconds` (1–20) on `ReceiveMessage` API calls. Amazon SQS waits until a message is available before returning a response. Reduces empty responses, API calls, and cost compared to short polling.

### Q37: What are Step Functions Intrinsic Functions?
Built-in functions usable in state machine parameters without Lambda:
- `States.Format`: String interpolation
- `States.StringToJson`: Parse string to JSON
- `States.JsonToString`: Serialize JSON to string
- `States.Array`: Create array
- `States.ArrayPartition`: Split array into chunks
- `States.MathAdd`, `States.MathRandom`: Math operations

### Q38: What is Lambda Power Tuning?
An open-source Step Functions state machine that tests your Lambda with different memory configurations and finds the optimal setting (lowest cost or lowest latency). Runs your actual function with real inputs at 10+ memory sizes simultaneously.

### Q39: What is the difference between SNS and SES?
- **SNS (Simple Notification Service):** General-purpose pub/sub messaging; supports SMS, email, push, HTTP, Lambda, SQS. Low control over email formatting. For system notifications.
- **SES (Simple Email Service):** Dedicated email service with rich HTML templates, bounce/complaint handling, dedicated IPs, high deliverability. For transactional or marketing emails.

### Q40: How does Lambda handle concurrent FIFO SQS messages?
For FIFO queues, Lambda processes one batch per message group ID sequentially (preserves order). Different message groups can be processed in parallel. Max concurrency = number of active message groups.

---

## Senior Architect Level

### Q41: Design a real-time fraud detection system using serverless.

**Answer:**

```
Transaction API (API Gateway + Lambda)
    │
    ├─→ DynamoDB (save transaction)
    │
    └─→ Kinesis Data Streams (real-time stream)
              │
              ▼
        Lambda (ML scoring)
              │
              ├─→ DynamoDB (store risk score)
              │
              └─→ EventBridge
                        │
                  ┌─────┴──────┐
                  ▼            ▼
          (score < 0.3)  (score > 0.7)
          Auto-approve   Step Functions
                         (fraud review)
                              │
                        Human Review
                         (Task Token)
                              │
                         Block/Allow
```

**Key design decisions:**
- Kinesis for real-time ordering of transactions
- ML model cached in Lambda memory (hot model inference)
- Express Step Functions for automated checks
- Standard Step Functions for human review (with timeout)
- EventBridge for routing by risk score threshold

---

### Q42: How do you implement circuit breaker pattern in serverless?

**Answer:**

Lambda doesn't have built-in circuit breakers. Implement with:

**Option 1: DynamoDB-based circuit state:**
```python
def check_circuit(service_name):
    item = circuit_table.get_item(Key={'service': service_name}).get('Item', {})
    if item.get('state') == 'OPEN':
        if time.time() > item.get('resetAt', 0):
            set_circuit(service_name, 'HALF_OPEN')
        else:
            raise CircuitOpenException(f"Circuit open for {service_name}")

def record_failure(service_name):
    response = circuit_table.update_item(
        Key={'service': service_name},
        UpdateExpression='ADD failures :one',
        ExpressionAttributeValues={':one': 1},
        ReturnValues='ALL_NEW'
    )
    if response['Attributes']['failures'] >= THRESHOLD:
        set_circuit(service_name, 'OPEN', resetAt=time.time() + 60)
```

**Option 2: AWS Resilience Hub** — managed chaos engineering and resilience scoring

**Option 3: Service Mesh (App Mesh)** — circuit breaker in the sidecar proxy (works with ECS/EKS, not pure Lambda)

---

### Q43: How do you handle back pressure in a serverless event-driven system?

**Answer:**

Back pressure occurs when producers generate events faster than consumers can process them.

**SQS-based approach (best for Lambda):**
- SQS naturally buffers events
- Lambda scales up to 1,000 concurrent (Standard) or message groups (FIFO)
- Set reserved concurrency to protect downstream databases
- DLQ captures events that repeatedly fail

**Lambda reserved concurrency as back pressure:**
```
SQS → Lambda (reserved=20) → DynamoDB
```
Lambda processes max 20 concurrent; SQS holds the rest. DynamoDB protected from more than 20 concurrent writers.

**Kinesis approach:**
- Partition count limits parallelism
- Lambda processes one shard per concurrent instance
- Add shards to scale up

**EventBridge Pipes with filtering:**
- Filter out irrelevant events before they reach Lambda
- Reduce Lambda invocations at the source

---

*Total: 43 detailed answers + many quick-fire questions. Review all before technical interviews.*

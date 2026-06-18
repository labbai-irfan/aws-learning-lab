# Module 3 — SQS & SNS: Messaging & Events

> Decouple and scale with SQS (queuing) and SNS (pub/sub fan-out). Production patterns, DLQs, FIFO, filtering, and the standard architecture combos.

---

## Part A — SQS (Simple Queue Service)

### 1. What SQS solves
```
   Without SQS: Producer ──sync──► Consumer  (tight coupling, consumer must be up)
   With SQS:    Producer ──► [Queue] ──► Consumer  (decoupled, async, consumer can scale/fail independently)
```
SQS is a **fully managed message queue** that holds messages until a consumer processes and deletes them.

### 2. Standard vs FIFO queues

| | **Standard** | **FIFO** |
|---|---|---|
| Ordering | Best-effort (not guaranteed) | Exactly-in-order per group |
| Delivery | At-least-once (duplicates possible) | Exactly-once (deduplication) |
| Throughput | Nearly unlimited | 300 msg/s (or 3000 with batching) |
| Use | High-throughput async tasks | Order processing, financial, sequenced workflows |
| Suffix | `.fifo` required | `.fifo` |

### 3. Key SQS parameters
| Parameter | Purpose | Typical |
|---|---|---|
| **Visibility timeout** | How long a message is invisible while being processed | 30s–2× processing time |
| **Message retention** | How long unsent messages stay in queue | 4d default, max 14d |
| **Receive message wait time** | Long-polling wait (up to 20s) | 20s (saves cost vs short-poll) |
| **Delay seconds** | Delay before a message becomes visible | 0s default |
| **Max message size** | Max payload | 256 KB (use S3 for larger) |

⚠️ If a consumer fails and doesn't delete the message, it re-appears after `VisibilityTimeout`. **Set visibility timeout > max processing time** to avoid double-processing.

### 4. Dead Letter Queue (DLQ)
Messages that fail `maxReceiveCount` times are moved to a DLQ:
```
   Main queue ──► Consumer fails 3× ──► DLQ
   DLQ → CloudWatch alarm (queue depth > 0) → investigate / replay
```
🛠️ Link a DLQ:
```bash
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/ACCT/hrms-payroll \
  --attributes '{"RedrivePolicy":"{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:ACCT:hrms-payroll-dlq\",\"maxReceiveCount\":\"3\"}"}'
```
💡 Alarm on `ApproximateNumberOfMessagesVisible` on the **DLQ** → page on-call.

### 5. Large message pattern (S3 extended payload)
For payloads > 256 KB, store in S3 and put the S3 reference in SQS:
```
   Producer → upload to S3 → SQS message (S3 key)
   Consumer → SQS message → download from S3 → process
```

### 6. FIFO deduplication
Set `MessageDeduplicationId` (or enable content-based deduplication) so identical messages within 5 minutes aren't enqueued twice. Set `MessageGroupId` to control ordering scope within a FIFO queue.

### 7. SQS + Lambda (event source mapping)
Lambda polls SQS (long-poll) and invokes your function with batches:
```
   SQS ──event-source-mapping──► Lambda (batch up to 10,000 messages)
   Failed messages re-queued → DLQ after maxReceiveCount
```
💡 Set Lambda `ReservedConcurrency` to avoid overwhelming downstream DBs during a burst.

---

## Part B — SNS (Simple Notification Service)

### 8. What SNS is
**SNS** is a fully managed **pub/sub messaging** service. A **publisher** sends to a **topic**; all **subscribers** receive (fan-out):
```
   Publisher ──► SNS Topic ──► Subscriber 1: SQS queue (for payroll worker)
                           ──► Subscriber 2: Lambda (for audit log)
                           ──► Subscriber 3: Email (for HR manager)
                           ──► Subscriber 4: HTTPS endpoint
```

### 9. SNS subscription types
| Type | Use |
|---|---|
| **SQS** | Reliable fan-out, consumer can process at its own pace |
| **Lambda** | Real-time processing, lightweight |
| **HTTPS** | Webhooks to external systems |
| **Email / Email-JSON** | Human notifications |
| **SMS** | Mobile alerts |
| **Mobile push** (FCM, APNs) | App push notifications |

### 10. Message filtering
Each SQS/Lambda subscriber can set a **filter policy** — only matching messages are delivered:
```json
{ "eventType": ["payroll", "leave"], "priority": [{ "numeric": [">=", 5] }] }
```
💡 Filter policies cut downstream cost — only relevant consumers receive each event type.

### 11. SNS FIFO topics
For **ordered, deduplicated** fan-out (paired with SQS FIFO queues). Same FIFO semantics but fan-out to multiple queues.

### 12. Cross-account / cross-region
- SNS can deliver to SQS queues in **other accounts** (set queue policy to allow).
- SNS can replicate to topics in other regions via subscriptions.

---

## Part C — Patterns combining SQS + SNS

### 13. Fan-out (SNS → multiple SQS)
```
   Order placed ──► SNS:order-events ──► SQS:inventory-updates
                                      ──► SQS:payment-processing
                                      ──► SQS:email-notifications
```
Each downstream service has its own queue, can fail independently, and processes at its own rate. This is the **canonical microservices event pattern**.

### 14. Request-response over SQS (async RPC)
```
   Caller puts request → request-queue (replyTo = temp-response-queue)
   Worker processes → puts result in response-queue
   Caller polls response-queue (or waits on ReceiveMessage)
```

### 15. Work queue (competing consumers)
Multiple consumers on the same SQS queue — SQS distributes work across them:
```
   SQS:payroll-jobs ──► Worker 1 (processes emp 1–500)
                    ──► Worker 2 (processes emp 501–1000)
   Workers auto-scale based on queue depth (ASG policy or ECS/Lambda)
```
⚠️ Idempotent workers essential — at-least-once delivery means duplicate processing is possible.

---

## Part D — Cost, limits, security

### 16. Cost
- SQS: per million requests (standard ~$0.40/M, FIFO ~$0.50/M). Long-polling reduces requests.
- SNS: per million publishes + per notification type/destination.

### 17. Security 🔒
- Both support **IAM resource policies** (queue/topic policies) for cross-account.
- SQS: **SSE-SQS** or **KMS encryption** at rest; TLS in transit.
- SNS: **KMS encryption** at rest; delivery via HTTPS only.
- Private delivery: use **VPC endpoints** (PrivateLink) so messages don't leave the VPC.

---

## ✅ Key decisions
- High-throughput async task: **Standard SQS** + competing consumers.
- Ordered/financial workflow: **FIFO SQS** with `MessageGroupId`.
- Fan-out to N consumers: **SNS → SQS** fan-out pattern.
- Dead letters: always attach a **DLQ** with a CloudWatch alarm.
- Serverless consumer: **SQS → Lambda** event source mapping.

➡️ Next: [Module 4 — Terraform](04-terraform.md)

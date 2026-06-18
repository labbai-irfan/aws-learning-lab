# 04 — SQS Integration with Lambda

---

## Table of Contents
1. [SQS Fundamentals](#sqs-fundamentals)
2. [Standard vs FIFO Queues](#standard-vs-fifo-queues)
3. [Key Queue Attributes](#key-queue-attributes)
4. [Lambda Integration (ESM)](#lambda-integration-esm)
5. [Batch Processing](#batch-processing)
6. [Error Handling & DLQ](#error-handling--dlq)
7. [Visibility Timeout](#visibility-timeout)
8. [Long Polling](#long-polling)
9. [Message Filtering](#message-filtering)
10. [Patterns](#patterns)
11. [Code Examples](#code-examples)

---

## SQS Fundamentals

Amazon SQS (Simple Queue Service) is a **fully managed message queue** for decoupling microservices, distributed systems, and serverless applications.

### How SQS Works

```
Producer → SQS Queue → Consumer
  writes     stores      reads & deletes

SQS guarantees:
  ✓ At-least-once delivery (Standard)
  ✓ Exactly-once delivery (FIFO)
  ✓ Messages retained up to 14 days
  ✓ Unlimited throughput (Standard)
  ✓ Messages survive consumer failure
```

### Message Lifecycle

```
1. Producer sends message to queue
2. Message becomes visible to consumers
3. Consumer polls & receives message
4. Message becomes INVISIBLE (visibility timeout starts)
5a. Consumer processes successfully → DELETES message → done
5b. Consumer fails → visibility timeout expires → message REAPPEARS
6. After N failures → message goes to DLQ (if configured)
```

---

## Standard vs FIFO Queues

```
Feature                | Standard              | FIFO
───────────────────────┼───────────────────────┼─────────────────────
Throughput             | Unlimited             | 300 msg/s (3,000 w/batch)
Delivery               | At-least-once         | Exactly-once
Ordering               | Best-effort           | Strict FIFO
Deduplication          | No                    | Yes (5-min window)
Message groups         | No                    | Yes (parallel FIFO lanes)
Use cases              | High-volume async     | Orders, financial txns
Cost                   | $0.40/1M              | $0.50/1M
Lambda trigger         | YES                   | YES
.fifo suffix required  | No                    | YES (queue-name.fifo)
```

### When to Use Each

```
Standard Queue:
  - Order doesn't matter (image processing, email sending)
  - Very high throughput needed
  - Idempotent consumers (safe to process twice)
  - Fan-out from SNS

FIFO Queue:
  - Order matters (banking transactions, order state machine)
  - Cannot process duplicates (payment processing)
  - Workflow steps that must run in sequence
  - E-commerce order updates (PENDING → CONFIRMED → SHIPPED)
```

---

## Key Queue Attributes

### Visibility Timeout

```
Default: 30 seconds
Range:   0 seconds – 12 hours

Rule: Visibility Timeout > Lambda function timeout

If Lambda timeout = 60s:
  Set visibility timeout = 90s (1.5x Lambda timeout)
  
Why? If Lambda times out at 60s, the message must stay invisible
long enough for Lambda to finish (or fail). If visibility expires
before Lambda finishes → message becomes visible again → processed TWICE.
```

### Message Retention

```
Default: 4 days
Range:   1 minute – 14 days

Design consideration:
  - How long can your system be down before messages expire?
  - A 14-day retention gives you 2 weeks to fix issues
  - Default 4 days is too short for most production systems
```

### Receive Wait Time (Long Polling)

```
Default: 0 (short polling) → empty responses if no messages
Set to:  20 seconds (max, recommended for Lambda)

Why? Lambda's SQS trigger uses long polling internally.
For custom consumers: long polling = fewer API calls = lower cost
```

### Delivery Delay

```
Default: 0 seconds
Range:   0 – 15 minutes

Use case: delay processing (e.g., send abandoned cart email 1hr later)
Per-message delay also possible (override queue delay)
```

### Max Message Size

```
Default & Max: 256KB
For larger payloads: use S3 + SQS pointer pattern
  - Store large payload in S3
  - Put S3 key in SQS message
  - Consumer fetches from S3
```

---

## Lambda Integration (ESM)

Event Source Mapping (ESM) — Lambda polls SQS automatically.

### How ESM Works

```
Lambda Service         SQS Queue          Your Lambda
     │                    │                    │
     │   LoopPolling       │                    │
     │ ──────────────→     │                    │
     │ ← messages ──────   │                    │
     │                     │                    │
     │   InvokeFunction ──────────────────────→ │
     │   (batch of messages)                    │
     │                                          │
     │   ← success (delete messages from SQS) ──│
     │   ← failure (partial) ──────────────────-│
```

### ESM Configuration

```python
# AWS CLI
aws lambda create-event-source-mapping \
    --function-name my-processor \
    --event-source-arn arn:aws:sqs:us-east-1:123:my-queue \
    --batch-size 10 \
    --maximum-batching-window-in-seconds 30 \
    --function-response-types ReportBatchItemFailures

# SAM Template
OrderProcessorFunction:
  Type: AWS::Serverless::Function
  Properties:
    Handler: processor.handler
    Events:
      SQSEvent:
        Type: SQS
        Properties:
          Queue: !GetAtt OrderQueue.Arn
          BatchSize: 10
          MaximumBatchingWindowInSeconds: 30
          FunctionResponseTypes:
            - ReportBatchItemFailures
          FilterCriteria:
            Filters:
              - Pattern: '{"body": {"status": ["PENDING"]}}'
```

### Key ESM Settings

```
BatchSize: 1–10,000
  - Higher = more efficient, but one Lambda handles more messages
  - Lower = more granular error handling
  - For FIFO: max 10 per message group

MaximumBatchingWindowInSeconds: 0–300 seconds
  - Lambda waits up to N seconds to fill a batch
  - Use when: low message rate but want to batch for efficiency
  - Cost trade-off: fewer invocations vs higher latency

Concurrency:
  Standard Queue: Lambda scales up to 1,000 concurrent instances
  FIFO Queue: 1 Lambda per message group ID (preserves order)

ScalingMode (Standard only):
  ConcurrentMessageGroupProcessing — process multiple groups in parallel
```

---

## Batch Processing

### ReportBatchItemFailures

Instead of failing the entire batch, report only failed items:

```python
import json
import logging
import boto3

logger = logging.getLogger()

def handler(event, context):
    """
    Process SQS messages with partial batch failure support.
    Return failed message IDs — Lambda will retry ONLY those.
    """
    records = event['Records']
    failed_items = []
    
    logger.info(f"Processing batch of {len(records)} messages")
    
    for record in records:
        message_id = record['messageId']
        
        try:
            body = json.loads(record['body'])
            process_message(body)
            logger.info(f"Processed message {message_id}")
            
        except RetryableError as e:
            # Transient error — put back in queue
            logger.warning(f"Retryable error for {message_id}: {e}")
            failed_items.append({'itemIdentifier': message_id})
            
        except PermanentError as e:
            # Non-retryable — log and skip (don't add to failures)
            # DLQ should capture these separately
            logger.error(f"Permanent error for {message_id}: {e}")
            # Do NOT add to failed_items — message will be deleted
    
    return {'batchItemFailures': failed_items}


def process_message(body):
    order_id = body.get('orderId')
    if not order_id:
        raise PermanentError("Missing orderId")
    
    # ... actual processing
    save_to_database(body)


class RetryableError(Exception):
    """Transient errors worth retrying (DB timeout, throttling)."""

class PermanentError(Exception):
    """Permanent errors that should not be retried (invalid data)."""
```

### Batch Size Strategy

```
Low volume, order-sensitive:    BatchSize=1 (process one at a time)
High volume, independent msgs:  BatchSize=10 (default, balanced)
High volume, CPU-bound:         BatchSize=100+ (maximize throughput)
Fan-out / analytics:            BatchSize=10,000 (maximum)

Batching window = 0:  Lambda fires immediately when any message arrives
Batching window = 30: Lambda waits 30s to collect messages (lower cost)
```

---

## Error Handling & DLQ

### Dead Letter Queue Setup

```
Main Queue → (after maxReceiveCount failures) → DLQ

maxReceiveCount: 1–1000
  - How many times a message is delivered before going to DLQ
  - Recommended: 3–5 retries for business events
  - Set based on how many retries make sense for your error type
```

```python
# Create DLQ
aws sqs create-queue --queue-name order-processor-dlq

# Create main queue with DLQ
aws sqs create-queue \
    --queue-name order-processor \
    --attributes '{
        "VisibilityTimeout": "90",
        "MessageRetentionPeriod": "1209600",
        "RedrivePolicy": "{
            \"deadLetterTargetArn\": \"arn:aws:sqs:us-east-1:123:order-processor-dlq\",
            \"maxReceiveCount\": \"3\"
        }"
    }'
```

### DLQ Monitoring

```python
# CloudWatch alarm on DLQ depth
aws cloudwatch put-metric-alarm \
    --alarm-name "DLQ-Messages-Alert" \
    --metric-name ApproximateNumberOfMessagesVisible \
    --namespace AWS/SQS \
    --dimensions Name=QueueName,Value=order-processor-dlq \
    --period 60 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --statistic Sum \
    --alarm-actions arn:aws:sns:us-east-1:123:ops-alerts
```

### DLQ Redrive (Replay Failed Messages)

```python
# After fixing the bug, move DLQ messages back to main queue
aws sqs start-message-move-task \
    --source-arn arn:aws:sqs:us-east-1:123:order-processor-dlq \
    --destination-arn arn:aws:sqs:us-east-1:123:order-processor \
    --max-number-of-messages-per-second 10

# Monitor progress
aws sqs list-message-move-tasks \
    --source-arn arn:aws:sqs:us-east-1:123:order-processor-dlq
```

---

## Visibility Timeout

### The Right Way to Set Visibility Timeout

```
Scenario: Lambda timeout = 60s, batch size = 10

Per-message processing time:
  avg: 2s, p99: 15s, max: 55s

Full batch processing time:
  worst case = 10 × 55s = 550s?  No — Lambda runs messages in parallel!
  Lambda processes ALL messages in a batch simultaneously
  
Actual visibility timeout needed:
  = Lambda timeout + buffer
  = 60s + 30s
  = 90s
  
Set queue visibility timeout to 90s.
```

### Extending Visibility During Long Processing

```python
import boto3
import threading
import time

sqs = boto3.client('sqs')
QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/123/my-queue'

def extend_visibility(receipt_handle, extension_seconds=60, interval=45):
    """Background thread that keeps extending visibility."""
    while True:
        time.sleep(interval)
        try:
            sqs.change_message_visibility(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=receipt_handle,
                VisibilityTimeout=extension_seconds
            )
        except Exception:
            break  # message was deleted or thread should stop


def handler(event, context):
    for record in event['Records']:
        receipt_handle = record['receiptHandle']
        
        # Start background heartbeat for long-running processing
        heartbeat = threading.Thread(
            target=extend_visibility,
            args=(receipt_handle,),
            daemon=True
        )
        heartbeat.start()
        
        try:
            process_long_running_task(record)
        finally:
            heartbeat.join(timeout=0)  # stop heartbeat
```

---

## Long Polling

```
Short polling (WaitTimeSeconds=0):
  - Returns immediately, even if queue is empty
  - Multiple empty responses = API cost + latency
  
Long polling (WaitTimeSeconds=1-20):
  - Waits up to N seconds for a message
  - Returns immediately when message arrives
  - Reduces empty responses by ~90%
  - Recommended: WaitTimeSeconds=20

For Lambda ESM: long polling is handled automatically by AWS
For custom consumers: always use long polling
```

```python
# Custom SQS consumer with long polling
def consume_messages():
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,      # long polling
            MessageAttributeNames=['All'],
            AttributeNames=['All']
        )
        
        messages = response.get('Messages', [])
        for message in messages:
            try:
                process(json.loads(message['Body']))
                sqs.delete_message(
                    QueueUrl=QUEUE_URL,
                    ReceiptHandle=message['ReceiptHandle']
                )
            except Exception as e:
                logger.error(f"Failed: {e}")
                # Don't delete — will retry after visibility timeout
```

---

## Message Filtering

ESM filter expressions reduce Lambda invocations for SQS.

```json
// Only process orders with status PENDING
{
  "body": {
    "status": ["PENDING"]
  }
}

// Only process high-value orders
{
  "body": {
    "amount": [{ "numeric": [">", 1000] }]
  }
}

// Complex filter: VIP customer orders over $500
{
  "body": {
    "amount": [{ "numeric": [">=", 500] }],
    "customerTier": ["VIP", "PLATINUM"]
  }
}

// Using message attributes
{
  "messageAttributes": {
    "eventType": {
      "stringValue": ["OrderCreated"]
    }
  }
}
```

---

## Patterns

### Pattern 1: SNS Fan-Out to SQS

```
SNS Topic
├── SQS Queue A → Lambda A (Email Service)
├── SQS Queue B → Lambda B (Inventory Service)
└── SQS Queue C → Lambda C (Analytics Service)

Benefits:
  - Each consumer has its own queue (independent scaling)
  - SQS buffers if Lambda is slow
  - Retries are per-consumer
  - One service going down doesn't affect others
```

### Pattern 2: Priority Queue

```
High Priority Queue (visibility=5s)  → Lambda with reserved concurrency=50
Low Priority Queue  (visibility=30s) → Lambda with reserved concurrency=5

Router Lambda reads both, uses priority queue first
→ Implement SLA tiers for different message types
```

### Pattern 3: Request-Response (Temporary Queue)

```
Caller creates temporary reply queue
Caller sends request to main queue with replyTo queue ARN
Worker processes request → sends response to replyTo queue
Caller polls replyTo queue for response
Caller deletes temporary queue

Use case: sync-async bridge where caller needs a response
Library: JMS TemporaryQueue, or DIY with FIFO queues
```

---

## Code Examples

### Idempotent SQS Processor

```python
import json
import hashlib
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
idempotency_table = dynamodb.Table('IdempotencyKeys')
sqs = boto3.client('sqs')

def handler(event, context):
    failed_items = []
    
    for record in event['Records']:
        message_id = record['messageId']
        body = json.loads(record['body'])
        
        try:
            # Generate idempotency key from business data
            idempotency_key = generate_idempotency_key(body)
            
            # Skip if already processed
            if already_processed(idempotency_key):
                print(f"Duplicate message {message_id}, skipping")
                continue
            
            # Process message
            result = process_order(body)
            
            # Mark as processed
            mark_processed(idempotency_key, result)
            
        except Exception as e:
            print(f"Error processing {message_id}: {e}")
            failed_items.append({'itemIdentifier': message_id})
    
    return {'batchItemFailures': failed_items}


def generate_idempotency_key(body):
    key_data = f"{body['orderId']}:{body.get('eventType', 'process')}"
    return hashlib.sha256(key_data.encode()).hexdigest()


def already_processed(key):
    try:
        response = idempotency_table.put_item(
            Item={
                'idempotencyKey': key,
                'processedAt': str(datetime.utcnow()),
                'ttl': int(time.time()) + 86400  # 24 hour TTL
            },
            ConditionExpression='attribute_not_exists(idempotencyKey)'
        )
        return False  # Successfully inserted = first time
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return True  # Already exists = duplicate
        raise


def process_order(order):
    # ... business logic
    return {'processed': True}


def mark_processed(key, result):
    pass  # already done in already_processed via conditional put
```

### Sending Messages with Attributes

```python
def send_order_message(order, priority='normal'):
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(order),
        MessageAttributes={
            'eventType': {
                'StringValue': 'OrderCreated',
                'DataType': 'String'
            },
            'priority': {
                'StringValue': priority,
                'DataType': 'String'
            },
            'version': {
                'StringValue': '1.0',
                'DataType': 'String'
            }
        },
        # For FIFO queues:
        # MessageGroupId=order['customerId'],
        # MessageDeduplicationId=order['orderId']
    )
    return response['MessageId']
```

---

*Next: [05-sns-integration.md](05-sns-integration.md)*

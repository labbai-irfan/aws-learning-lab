# 03 — Amazon EventBridge: Event Routing & Rules

---

## Table of Contents
1. [What Is EventBridge](#what-is-eventbridge)
2. [Event Buses](#event-buses)
3. [Events Structure](#events-structure)
4. [Rules & Patterns](#rules--patterns)
5. [Targets](#targets)
6. [Scheduled Events](#scheduled-events)
7. [EventBridge Pipes](#eventbridge-pipes)
8. [Schema Registry](#schema-registry)
9. [Cross-Account & Cross-Region](#cross-account--cross-region)
10. [Code Examples](#code-examples)

---

## What Is EventBridge

EventBridge is a **serverless event bus** that connects AWS services, SaaS applications, and your own services using events.

```
┌─────────────────────────────────────────────────────────────┐
│                    AMAZON EVENTBRIDGE                         │
│                                                               │
│  Event Sources          Event Bus         Targets            │
│                                                               │
│  AWS Services    ──→                ──→  Lambda              │
│  (EC2, S3, RDS)         Default         SQS                  │
│                          Bus            SNS                   │
│  Your Apps       ──→                ──→  Step Functions      │
│  (PutEvents)     ──→  Custom  ──→       API Gateway          │
│                          Bus            EventBridge (other)   │
│  SaaS Partners   ──→                ──→  Kinesis             │
│  (Shopify, etc.)        Partner         ECS Task             │
│                          Bus            CodePipeline          │
└─────────────────────────────────────────────────────────────┘
```

### Why EventBridge vs SNS?

```
EventBridge:
  ✓ Content-based routing (filter by any JSON field)
  ✓ Schema registry + discovery
  ✓ SaaS partner integrations (50+ partners)
  ✓ Cross-account event routing
  ✓ Archive & replay events
  ✓ EventBridge Pipes (enrichment + filtering)
  ✗ Higher latency than SNS (~1-2s)
  ✗ 10,000 PutEvents/sec limit (SNS is higher)

SNS:
  ✓ Lower latency (~10ms)
  ✓ Fan-out to SQS (reliable delivery)
  ✓ SMS/Email/Mobile push delivery
  ✓ Higher throughput
  ✗ Limited filtering (attribute-based only)
  ✗ No schema registry
  ✗ No replay
```

---

## Event Buses

### Types of Buses

```
DEFAULT BUS
  - Receives events from AWS services automatically
  - Cannot be deleted
  - Shared across your AWS account
  - Example: EC2 instance state change, S3 bucket notifications

CUSTOM BUS
  - You create for your own application events
  - Isolate domains (orders-bus, payments-bus, inventory-bus)
  - Cross-account event routing

PARTNER BUS
  - Created when you subscribe to a SaaS partner event source
  - Examples: Shopify, Zendesk, Datadog, GitHub
```

### Creating Custom Buses

```bash
# Create a bus per domain
aws events create-event-bus --name orders-bus
aws events create-event-bus --name payments-bus
aws events create-event-bus --name inventory-bus

# Add resource policy to allow cross-account publishing
aws events put-permission \
    --event-bus-name orders-bus \
    --action events:PutEvents \
    --principal 111222333444 \   # other AWS account
    --statement-id allow-account-111222333444
```

---

## Events Structure

Every EventBridge event follows the same envelope:

```json
{
  "version": "0",
  "id": "12345678-1234-1234-1234-123456789012",
  "source": "com.mycompany.orders",
  "account": "123456789012",
  "time": "2026-06-17T10:30:00Z",
  "region": "us-east-1",
  "resources": [
    "arn:aws:dynamodb:us-east-1:123:table/Orders/stream/..."
  ],
  "detail-type": "OrderPlaced",
  "detail": {
    "orderId": "ORD-12345",
    "customerId": "CUST-789",
    "amount": 150.00,
    "currency": "USD",
    "status": "PENDING",
    "items": [
      { "productId": "PROD-001", "quantity": 2, "price": 75.00 }
    ]
  }
}
```

### Publishing Events (PutEvents)

```python
import boto3
import json
from datetime import datetime

events = boto3.client('events')

def publish_order_event(order):
    response = events.put_events(
        Entries=[
            {
                'Source': 'com.mycompany.orders',
                'DetailType': 'OrderPlaced',
                'Detail': json.dumps({
                    'orderId': order['id'],
                    'customerId': order['customerId'],
                    'amount': order['amount'],
                    'status': 'PENDING',
                    'items': order['items']
                }),
                'EventBusName': 'orders-bus',
                'Time': datetime.utcnow()
            }
        ]
    )
    
    # Check for failures (PutEvents can partially fail)
    failed = response.get('FailedEntryCount', 0)
    if failed > 0:
        for entry in response['Entries']:
            if 'ErrorCode' in entry:
                print(f"Failed: {entry['ErrorCode']} - {entry['ErrorMessage']}")
    
    return response


# Batch publishing (up to 10 events per call)
def publish_batch(events_list):
    entries = [
        {
            'Source': 'com.mycompany.orders',
            'DetailType': event['type'],
            'Detail': json.dumps(event['data']),
            'EventBusName': 'orders-bus'
        }
        for event in events_list
    ]
    
    # PutEvents accepts max 10 entries per call
    for i in range(0, len(entries), 10):
        batch = entries[i:i+10]
        events.put_events(Entries=batch)
```

---

## Rules & Patterns

Rules filter events and route matching events to targets.

### Event Pattern Matching

```json
// Match exact field value
{
  "source": ["com.mycompany.orders"],
  "detail-type": ["OrderPlaced"]
}

// Match multiple values (OR logic)
{
  "source": ["com.mycompany.orders"],
  "detail-type": ["OrderPlaced", "OrderUpdated", "OrderCancelled"]
}

// Match nested field value
{
  "detail": {
    "status": ["PENDING"]
  }
}

// Numeric comparison (amount > 1000)
{
  "detail": {
    "amount": [{ "numeric": [">", 1000] }]
  }
}

// Amount between 100 and 500
{
  "detail": {
    "amount": [{ "numeric": [">=", 100, "<=", 500] }]
  }
}

// String prefix matching
{
  "detail": {
    "orderId": [{ "prefix": "ORD-VIP-" }]
  }
}

// Field exists check
{
  "detail": {
    "promoCode": [{ "exists": true }]
  }
}

// Field does NOT exist
{
  "detail": {
    "deletedAt": [{ "exists": false }]
  }
}

// Anything-but (exclude values)
{
  "detail": {
    "status": [{ "anything-but": ["CANCELLED", "REFUNDED"] }]
  }
}

// Wildcard matching
{
  "detail": {
    "email": [{ "wildcard": "*@mycompany.com" }]
  }
}

// Complex rule: VIP orders over $500 with promo code
{
  "source": ["com.mycompany.orders"],
  "detail-type": ["OrderPlaced"],
  "detail": {
    "amount": [{ "numeric": [">", 500] }],
    "customerId": [{ "prefix": "VIP-" }],
    "promoCode": [{ "exists": true }]
  }
}
```

### Creating Rules

```bash
# Create rule with pattern
aws events put-rule \
    --name "high-value-orders" \
    --event-bus-name orders-bus \
    --event-pattern '{
        "source": ["com.mycompany.orders"],
        "detail-type": ["OrderPlaced"],
        "detail": {
            "amount": [{"numeric": [">", 1000]}]
        }
    }' \
    --state ENABLED

# Add Lambda target to rule
aws events put-targets \
    --rule "high-value-orders" \
    --event-bus-name orders-bus \
    --targets '[
        {
            "Id": "high-value-order-processor",
            "Arn": "arn:aws:lambda:us-east-1:123:function:vip-order-processor"
        }
    ]'
```

---

## Targets

EventBridge can route events to 20+ target types.

### Common Targets Configuration

```json
{
  "Targets": [
    {
      "Id": "LambdaTarget",
      "Arn": "arn:aws:lambda:us-east-1:123:function:my-function"
    },
    {
      "Id": "SQSTarget",
      "Arn": "arn:aws:sqs:us-east-1:123:my-queue",
      "SqsParameters": {
        "MessageGroupId": "orders"
      }
    },
    {
      "Id": "SNSTarget",
      "Arn": "arn:aws:sns:us-east-1:123:my-topic"
    },
    {
      "Id": "StepFunctionsTarget",
      "Arn": "arn:aws:states:us-east-1:123:stateMachine:OrderWorkflow",
      "RoleArn": "arn:aws:iam::123:role/EventBridgeRole"
    },
    {
      "Id": "APIGatewayTarget",
      "Arn": "arn:aws:execute-api:us-east-1:123:abc/prod/POST/orders",
      "RoleArn": "arn:aws:iam::123:role/EventBridgeRole",
      "HttpParameters": {
        "PathParameterValues": [],
        "HeaderParameters": { "Content-Type": "application/json" },
        "QueryStringParameters": {}
      }
    }
  ]
}
```

### Input Transformation

Transform the event before sending to target:

```json
// Extract only needed fields from event
{
  "Id": "LambdaTarget",
  "Arn": "arn:aws:lambda:...",
  "InputTransformer": {
    "InputPathsMap": {
      "orderId":    "$.detail.orderId",
      "amount":     "$.detail.amount",
      "customerId": "$.detail.customerId",
      "eventTime":  "$.time"
    },
    "InputTemplate": "{\"order_id\": \"<orderId>\", \"total\": <amount>, \"customer\": \"<customerId>\", \"received_at\": \"<eventTime>\"}"
  }
}
```

### Dead Letter Queue for Failed Targets

```json
{
  "Id": "LambdaTarget",
  "Arn": "arn:aws:lambda:...",
  "DeadLetterConfig": {
    "Arn": "arn:aws:sqs:us-east-1:123:eventbridge-dlq"
  },
  "RetryPolicy": {
    "MaximumRetryAttempts": 3,
    "MaximumEventAgeInSeconds": 3600
  }
}
```

---

## Scheduled Events

EventBridge Scheduler replaces CloudWatch Events cron rules.

### Cron Expressions

```
cron(Minutes Hours Day-of-month Month Day-of-week Year)

cron(0 12 * * ? *)         → Every day at 12:00 UTC
cron(0 8 ? * MON-FRI *)    → Weekdays at 8:00 AM
cron(0/15 * * * ? *)       → Every 15 minutes
cron(0 18 L * ? *)         → Last day of month at 6 PM
cron(0 9 ? * 2#1 *)        → First Monday of month at 9 AM

rate(5 minutes)             → Every 5 minutes
rate(1 hour)                → Every hour
rate(7 days)                → Every 7 days
```

### EventBridge Scheduler (Newer, more features)

```python
import boto3

scheduler = boto3.client('scheduler')

# One-time scheduled task (at specific time)
scheduler.create_schedule(
    Name='monthly-report-june-2026',
    ScheduleExpression='at(2026-06-30T23:59:00)',
    ScheduleExpressionTimezone='UTC',
    Target={
        'Arn': 'arn:aws:lambda:us-east-1:123:function:generate-report',
        'RoleArn': 'arn:aws:iam::123:role/SchedulerRole',
        'Input': json.dumps({'reportType': 'monthly', 'month': '2026-06'})
    },
    FlexibleTimeWindow={'Mode': 'OFF'},
    ActionAfterCompletion='DELETE'  # auto-delete after run
)

# Recurring schedule with flexible time window
scheduler.create_schedule(
    Name='nightly-cleanup',
    ScheduleExpression='cron(0 2 * * ? *)',
    Target={
        'Arn': 'arn:aws:lambda:us-east-1:123:function:cleanup',
        'RoleArn': 'arn:aws:iam::123:role/SchedulerRole'
    },
    FlexibleTimeWindow={
        'Mode': 'FLEXIBLE',
        'MaximumWindowInMinutes': 30  # run within 30min of 2:00 AM
    }
)
```

---

## EventBridge Pipes

Pipes connect a **source → (filter) → (enrichment) → target** in a single construct.

```
Source         Filter        Enrichment      Target
(SQS)    →  (pattern)  →  (Lambda/API)  →  (Step Functions)
(Kinesis)                 (optional)
(DynamoDB)
```

```python
# Example: SQS → Lambda enrichment → Step Functions

{
    "Name": "order-processing-pipe",
    "Source": "arn:aws:sqs:us-east-1:123:raw-orders",
    "SourceParameters": {
        "SqsQueueParameters": {
            "BatchSize": 1
        }
    },
    "Filter": {
        "Filters": [{
            "Pattern": "{\"body\": {\"amount\": [{\"numeric\": [\">=\", 100]}]}}"
        }]
    },
    "Enrichment": "arn:aws:lambda:us-east-1:123:function:enrich-order",
    "Target": "arn:aws:states:us-east-1:123:stateMachine:OrderWorkflow",
    "TargetParameters": {
        "StepFunctionStateMachineParameters": {
            "InvocationType": "FIRE_AND_FORGET"
        }
    }
}
```

---

## Schema Registry

EventBridge discovers and stores event schemas automatically.

```
Schema Registry:
  - AWS: schemas for all AWS service events
  - Discovered: schemas from your custom events (auto-discovery)
  - Custom: manually created schemas

Benefits:
  - IDE code binding generation (Python, Java, TypeScript, Go)
  - Event validation
  - Documentation for your event-driven system
```

```python
# Enable schema discovery on a bus
aws schemas create-discoverer \
    --source-arn arn:aws:events:us-east-1:123:event-bus/orders-bus \
    --description "Discover schemas from orders events"

# Download code bindings
aws schemas get-code-binding-source \
    --registry-name discovered-schemas \
    --schema-name com.mycompany.orders@OrderPlaced \
    --language Python36

# Generated Python class
from schema.com_mycompany_orders import OrderPlaced, AWSEvent

def handler(event, context):
    typed_event: AWSEvent = AWSEvent.from_dict(event)
    order: OrderPlaced = typed_event.detail
    print(f"Order {order.order_id} for ${order.amount}")
```

---

## Cross-Account & Cross-Region

### Pattern: Hub and Spoke Event Bus

```
Production Account (Hub)
├── central-events-bus
│   ├── Receives events from all spoke accounts
│   └── Routes to central logging, monitoring, SIEM

Development Account (Spoke)
└── default-bus → Rule → central-events-bus (prod account)

Staging Account (Spoke)
└── default-bus → Rule → central-events-bus (prod account)
```

```bash
# In prod account: allow spoke accounts to publish
aws events put-permission \
    --event-bus-name central-events-bus \
    --action events:PutEvents \
    --principal "*" \
    --statement-id allow-org \
    --condition Type=StringEquals,Key=aws:PrincipalOrgID,Value=o-abc123

# In dev account: create rule to forward events
aws events put-rule \
    --name "forward-to-central" \
    --event-bus-name default \
    --event-pattern '{"account": ["111222333444"]}' \
    --state ENABLED

aws events put-targets \
    --rule "forward-to-central" \
    --targets '[{
        "Id": "CentralBus",
        "Arn": "arn:aws:events:us-east-1:999888777666:event-bus/central-events-bus",
        "RoleArn": "arn:aws:iam::111222333444:role/EventBridgeCrossAccountRole"
    }]'
```

---

## Code Examples

### Lambda Receiving EventBridge Events

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel('INFO')

def handler(event, context):
    """Process EventBridge event."""
    
    # EventBridge event structure
    source = event['source']              # com.mycompany.orders
    detail_type = event['detail-type']    # OrderPlaced
    detail = event['detail']             # your event data
    event_time = event['time']
    event_id = event['id']
    
    logger.info(json.dumps({
        'eventId': event_id,
        'source': source,
        'detailType': detail_type,
        'message': 'Processing EventBridge event'
    }))
    
    if detail_type == 'OrderPlaced':
        return process_order_placed(detail)
    elif detail_type == 'OrderCancelled':
        return process_order_cancelled(detail)
    elif detail_type == 'PaymentFailed':
        return process_payment_failed(detail)
    else:
        logger.warning(f"Unknown event type: {detail_type}")
        return {'statusCode': 200, 'message': 'Unknown event type, skipping'}


def process_order_placed(order):
    order_id = order['orderId']
    customer_id = order['customerId']
    amount = order['amount']
    
    logger.info(f"Processing order {order_id} for customer {customer_id}, amount ${amount}")
    # ... business logic
    return {'processed': True, 'orderId': order_id}


def process_order_cancelled(order):
    # ... handle cancellation
    pass


def process_payment_failed(payment):
    # ... handle payment failure
    pass
```

### Fan-Out Pattern with EventBridge

```python
# One service publishes → EventBridge routes to multiple services

# Publisher (Order Service)
def create_order(order_data):
    # Save to database
    order = save_to_dynamodb(order_data)
    
    # Publish single event — EventBridge routes to all consumers
    events.put_events(Entries=[{
        'Source': 'com.mycompany.orders',
        'DetailType': 'OrderPlaced',
        'Detail': json.dumps(order),
        'EventBusName': 'orders-bus'
    }])
    
    return order

# Rule 1: → inventory-service Lambda (reserve stock)
# Rule 2: → email-service Lambda (send confirmation)
# Rule 3: → analytics-service Kinesis (stream to data warehouse)
# Rule 4: → SQS payment-queue (process payment)
# No coupling between publisher and consumers!
```

### Archive & Replay

```bash
# Create archive of all events on a bus
aws events create-archive \
    --archive-name orders-archive \
    --event-source-arn arn:aws:events:us-east-1:123:event-bus/orders-bus \
    --retention-days 90 \
    --event-pattern '{"source": ["com.mycompany.orders"]}'

# Replay events (e.g., after deploying new consumer)
aws events start-replay \
    --replay-name replay-for-new-consumer \
    --source-arn arn:aws:events:us-east-1:123:archive/orders-archive \
    --event-start-time 2026-06-01T00:00:00Z \
    --event-end-time 2026-06-17T00:00:00Z \
    --destination '{
        "Arn": "arn:aws:events:us-east-1:123:event-bus/orders-bus"
    }'
```

---

*Next: [04-sqs-integration.md](04-sqs-integration.md)*

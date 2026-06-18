# 05 — SNS Integration: Pub/Sub Messaging

---

## Table of Contents
1. [SNS Fundamentals](#sns-fundamentals)
2. [SNS vs SQS vs EventBridge](#sns-vs-sqs-vs-eventbridge)
3. [Topics & Subscriptions](#topics--subscriptions)
4. [Message Filtering](#message-filtering)
5. [Fan-Out Pattern](#fan-out-pattern)
6. [FIFO Topics](#fifo-topics)
7. [Mobile Push Notifications](#mobile-push-notifications)
8. [Message Delivery & Retry](#message-delivery--retry)
9. [Security](#security)
10. [Code Examples](#code-examples)

---

## SNS Fundamentals

Amazon SNS (Simple Notification Service) is a **managed pub/sub messaging service** for decoupling publishers from subscribers.

### Push vs Pull

```
SNS (Push):
  Publisher → SNS Topic → PUSHES to all subscribers immediately
  Subscribers receive messages instantly
  No polling needed by consumers

SQS (Pull):
  Producer → SQS Queue → Consumer POLLS for messages
  Messages stored until consumer retrieves them
  Consumer controls processing rate
```

### SNS Delivery Model

```
Publisher
    │ Publish(message)
    ▼
SNS Topic
    ├── Lambda Subscription    → invokes function immediately
    ├── SQS Subscription       → delivers to queue
    ├── HTTP/HTTPS Subscription → POST to endpoint
    ├── Email Subscription     → sends email
    ├── SMS Subscription       → sends text message
    ├── Mobile Push (APNs/FCM) → push notification
    └── Kinesis Data Streams   → stream analytics
```

---

## SNS vs SQS vs EventBridge

```
Feature              | SNS            | SQS            | EventBridge
─────────────────────┼────────────────┼────────────────┼──────────────────
Model                | Push (pub/sub) | Pull (queue)   | Push (event bus)
Message Storage      | No             | Yes (14 days)  | No (archive opt.)
Delivery             | At-least-once  | At-least-once  | At-least-once
Ordering             | No             | No (Standard)  | No
Fan-out              | YES            | No             | YES
Filtering            | Attribute-based| Content-based  | Content-based
Schema Registry      | No             | No             | YES
Replay               | No             | No             | YES
SaaS Integration     | No             | No             | YES
Multiple consumers   | YES (per sub.) | No (one worker)| YES (per rule)
Throughput           | Very High      | Very High      | 10K events/sec
Best for             | Notifications  | Job queues     | System integration
```

### Decision Guide

```
Fan-out to multiple services?         → SNS (or EventBridge)
Queue work for later processing?       → SQS
Filter by content (any JSON field)?    → EventBridge
Connect SaaS partner events?           → EventBridge
Send mobile push / SMS / email?        → SNS
Replay events for new consumers?       → EventBridge
Reliable async job processing?         → SQS + Lambda
```

---

## Topics & Subscriptions

### Creating a Topic

```bash
# Standard topic
aws sns create-topic --name order-notifications

# FIFO topic
aws sns create-topic \
    --name order-events.fifo \
    --attributes FifoTopic=true,ContentBasedDeduplication=true

# With encryption (KMS)
aws sns create-topic \
    --name order-notifications-encrypted \
    --attributes KmsMasterKeyId=arn:aws:kms:us-east-1:123:key/abc123
```

### Subscription Types

```python
sns = boto3.client('sns')
TOPIC_ARN = 'arn:aws:sns:us-east-1:123:order-notifications'

# Lambda subscription
sns.subscribe(
    TopicArn=TOPIC_ARN,
    Protocol='lambda',
    Endpoint='arn:aws:lambda:us-east-1:123:function:process-order'
)

# SQS subscription
sns.subscribe(
    TopicArn=TOPIC_ARN,
    Protocol='sqs',
    Endpoint='arn:aws:sqs:us-east-1:123:order-queue'
)

# HTTP subscription
sns.subscribe(
    TopicArn=TOPIC_ARN,
    Protocol='https',
    Endpoint='https://api.myservice.com/webhooks/sns'
)

# Email subscription
sns.subscribe(
    TopicArn=TOPIC_ARN,
    Protocol='email',
    Endpoint='ops-team@mycompany.com'
)

# SMS subscription
sns.subscribe(
    TopicArn=TOPIC_ARN,
    Protocol='sms',
    Endpoint='+15551234567'
)
```

### Publishing Messages

```python
def publish_order_event(order, event_type='OrderPlaced'):
    response = sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=f"Order Event: {event_type}",
        Message=json.dumps(order),
        MessageAttributes={
            'eventType': {
                'DataType': 'String',
                'StringValue': event_type
            },
            'priority': {
                'DataType': 'String',
                'StringValue': 'high' if order['amount'] > 500 else 'normal'
            },
            'region': {
                'DataType': 'String',
                'StringValue': 'us-east-1'
            }
        }
    )
    return response['MessageId']


# Different message per protocol (MessageStructure='json')
def publish_multi_format(order):
    sns.publish(
        TopicArn=TOPIC_ARN,
        MessageStructure='json',
        Message=json.dumps({
            'default': f"New order placed: {order['orderId']}",
            'email': f"""
                Dear Team,
                
                New order #{order['orderId']} placed.
                Amount: ${order['amount']}
                Customer: {order['customerId']}
            """,
            'sms': f"Order {order['orderId']}: ${order['amount']}",
            'lambda': json.dumps(order),  # full data for Lambda
            'sqs': json.dumps(order)      # full data for SQS
        })
    )
```

---

## Message Filtering

SNS subscription filter policies route messages to specific subscribers.

### Filter Policy (Attribute-Based)

```json
// Subscription 1: Only high-priority orders
{
  "priority": ["high"],
  "eventType": ["OrderPlaced", "OrderUpdated"]
}

// Subscription 2: Only cancellations
{
  "eventType": ["OrderCancelled"]
}

// Subscription 3: Orders over $1000 (numeric)
{
  "amount": [{ "numeric": [">", 1000] }]
}

// Subscription 4: VIP customers
{
  "customerTier": ["VIP", "PLATINUM"]
}

// Subscription 5: Everything NOT cancelled
{
  "eventType": [{ "anything-but": ["OrderCancelled"] }]
}
```

### Setting Filter Policy on Subscription

```bash
# Get subscription ARN first
SUBSCRIPTION_ARN=$(aws sns list-subscriptions-by-topic \
    --topic-arn $TOPIC_ARN \
    --query "Subscriptions[?Endpoint=='arn:aws:sqs:...:high-priority-queue'].SubscriptionArn" \
    --output text)

# Apply filter policy
aws sns set-subscription-attributes \
    --subscription-arn $SUBSCRIPTION_ARN \
    --attribute-name FilterPolicy \
    --attribute-value '{"priority": ["high"], "eventType": ["OrderPlaced"]}'

# Apply filter using message body (FilterPolicyScope=MessageBody)
aws sns set-subscription-attributes \
    --subscription-arn $SUBSCRIPTION_ARN \
    --attribute-name FilterPolicyScope \
    --attribute-value MessageBody
```

### Filter Policy Scope: MessageBody

When `FilterPolicyScope=MessageBody`, filter against the message content (not just attributes):

```json
// Message body:
{
  "orderId": "ORD-123",
  "amount": 750,
  "status": "PENDING",
  "customer": { "tier": "VIP" }
}

// Filter policy (against body):
{
  "amount": [{ "numeric": [">=", 500] }],
  "customer": {
    "tier": ["VIP", "PLATINUM"]
  }
}
```

---

## Fan-Out Pattern

SNS → multiple SQS queues is the most common fan-out pattern.

```
                  SNS Topic (order-events)
                        │
           ┌────────────┼────────────┐────────────────┐
           │            │            │                 │
           ▼            ▼            ▼                 ▼
       SQS Queue    SQS Queue    SQS Queue         Lambda
       (payments)   (inventory)  (notifications)   (analytics)
           │            │            │
           ▼            ▼            ▼
       Lambda       Lambda       Lambda
       (payment     (stock       (email/SMS
        service)     reservation) sender)
```

### Why SQS between SNS and Lambda?

```
SNS → Lambda directly:
  ✓ Simpler
  ✗ Lambda throttled → messages LOST (SNS retries 3 times then drops)
  ✗ Lambda errors → messages may be lost
  ✗ No control over processing rate

SNS → SQS → Lambda:
  ✓ SQS buffers messages during Lambda throttling
  ✓ Messages never lost (SQS retains up to 14 days)
  ✓ DLQ captures permanently failed messages
  ✓ Lambda processes at own pace
  ✓ Can control concurrency (reserved concurrency on Lambda)
  ✗ Slightly more complex setup
  ✗ Small additional cost (SQS charges)
```

### Fan-Out with Filtering

```
                  SNS Topic (order-events)
                        │
           ┌────────────┼────────────┐
           │            │            │
    Filter: ALL  Filter: VIP   Filter: Cancel
           │            │            │
           ▼            ▼            ▼
       SQS Queue    SQS Queue    SQS Queue
       (all-orders) (vip-orders) (cancellations)
```

---

## FIFO Topics

SNS FIFO preserves message order and eliminates duplicates.

```
FIFO Topic → FIFO Queue → Lambda

Features:
  - Strict ordering within a message group
  - Exactly-once delivery (deduplication)
  - Only supports SQS FIFO subscriptions (no Lambda, HTTP, email)
  - Lower throughput: 300 msg/s (3,000 with batching)

When to use:
  - Financial transactions
  - Order status updates (PENDING → CONFIRMED → SHIPPED)
  - Audit logs that must be in order
```

```python
# Publish to FIFO topic
sns.publish(
    TopicArn='arn:aws:sns:us-east-1:123:order-events.fifo',
    Message=json.dumps(order_update),
    MessageGroupId=order_update['orderId'],    # same group = same order
    MessageDeduplicationId=f"{order_update['orderId']}:{order_update['status']}:{timestamp}"
)
```

---

## Mobile Push Notifications

### Platform Application Setup

```
SNS supports push notification platforms:
  APNs   (Apple Push Notification service) → iOS/macOS
  GCM    (Google Cloud Messaging / FCM)    → Android
  ADM    (Amazon Device Messaging)         → Kindle
  WNS    (Windows Notification Service)    → Windows
  BAIDU  (Baidu Cloud Push)               → China Android
```

```python
# 1. Create platform application
response = sns.create_platform_application(
    Name='MyApp-iOS',
    Platform='APNS',
    Attributes={
        'PlatformCredential': '<APNs private key>',
        'PlatformPrincipal': '<APNs certificate>'
    }
)
platform_app_arn = response['PlatformApplicationArn']

# 2. Register device token (from mobile app)
def register_device(device_token, user_id):
    response = sns.create_platform_endpoint(
        PlatformApplicationArn=platform_app_arn,
        Token=device_token,
        CustomUserData=user_id  # store user mapping
    )
    endpoint_arn = response['EndpointArn']
    
    # Save endpoint_arn to user profile in DynamoDB
    save_device_endpoint(user_id, endpoint_arn)
    return endpoint_arn

# 3. Send push notification to specific device
def send_push(endpoint_arn, title, body, data=None):
    apns_payload = {
        'aps': {
            'alert': {'title': title, 'body': body},
            'badge': 1,
            'sound': 'default'
        }
    }
    if data:
        apns_payload['data'] = data
    
    try:
        sns.publish(
            TargetArn=endpoint_arn,
            MessageStructure='json',
            Message=json.dumps({
                'default': body,
                'APNS': json.dumps(apns_payload),
                'APNS_SANDBOX': json.dumps(apns_payload)
            })
        )
    except sns.exceptions.EndpointDisabledException:
        # Device token no longer valid — remove from DB
        deactivate_device(endpoint_arn)
```

### Broadcast Push Notifications

```python
# Option 1: SNS topic subscribed by all device endpoints
# Publish to topic → all devices receive

# Option 2: Iterate over user devices (for targeted push)
def send_to_user(user_id, message):
    endpoints = get_user_endpoints(user_id)  # from DynamoDB
    
    for endpoint_arn in endpoints:
        try:
            send_push(endpoint_arn, message['title'], message['body'])
        except Exception as e:
            logger.error(f"Failed to send to {endpoint_arn}: {e}")
```

---

## Message Delivery & Retry

### Delivery Retry Policy

```
HTTP/HTTPS subscriptions have configurable retry:
  numRetries: 3 (default)
  minDelayTarget: 20s
  maxDelayTarget: 20s
  numNoDelayRetries: 0
  backoffFunction: linear (default) or exponential or geometric

Lambda subscriptions:
  SNS retries 3 times (total 4 attempts)
  Failed → goes to subscription's DLQ (if configured)
  
SQS subscriptions:
  SNS delivers once; SQS handles retries
  Message stays in SQS until deleted or DLQ
```

### Subscription Dead Letter Queue

```bash
# Create DLQ for SNS subscription
aws sqs create-queue --queue-name sns-subscription-dlq

# Set DLQ on subscription
aws sns set-subscription-attributes \
    --subscription-arn $SUBSCRIPTION_ARN \
    --attribute-name RedrivePolicy \
    --attribute-value '{
        "deadLetterTargetArn": "arn:aws:sqs:us-east-1:123:sns-subscription-dlq"
    }'
```

---

## Security

### Topic Resource Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublishFromLambda",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:us-east-1:123:order-events",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:lambda:us-east-1:123:function:order-service"
        }
      }
    },
    {
      "Sid": "DenyHTTP",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "SNS:Subscribe",
      "Resource": "arn:aws:sns:us-east-1:123:order-events",
      "Condition": {
        "StringEquals": {
          "sns:Protocol": "http"
        }
      }
    }
  ]
}
```

### Message Encryption (SSE)

```bash
# Create KMS key for SNS
aws kms create-key --description "SNS message encryption"
KEY_ID="arn:aws:kms:us-east-1:123:key/abc123"

# Create encrypted topic
aws sns create-topic \
    --name secure-notifications \
    --attributes KmsMasterKeyId=$KEY_ID

# Messages are encrypted at rest in SNS
# Note: SQS subscriptions also need access to the same KMS key
```

### HTTPS-Only Subscription Policy

```python
# Enforce HTTPS for HTTP subscriptions
sns.set_subscription_attributes(
    SubscriptionArn=subscription_arn,
    AttributeName='DeliveryPolicy',
    AttributeValue=json.dumps({
        "healthyRetryPolicy": {
            "numRetries": 3,
            "minDelayTarget": 20,
            "maxDelayTarget": 20,
            "numMaxDelayRetries": 0,
            "numNoDelayRetries": 0,
            "numMinDelayRetries": 0,
            "backoffFunction": "linear"
        }
    })
)
```

---

## Code Examples

### Lambda Receiving SNS Events

```python
import json
import logging

logger = logging.getLogger()

def handler(event, context):
    """SNS wraps each message in a Records array."""
    
    for record in event['Records']:
        sns_record = record['Sns']
        
        # SNS message envelope
        topic_arn = sns_record['TopicArn']
        subject = sns_record.get('Subject', '')
        message_id = sns_record['MessageId']
        timestamp = sns_record['Timestamp']
        
        # Message attributes
        attributes = sns_record.get('MessageAttributes', {})
        event_type = attributes.get('eventType', {}).get('Value')
        
        # Actual message payload
        try:
            payload = json.loads(sns_record['Message'])
        except json.JSONDecodeError:
            payload = sns_record['Message']  # plain text message
        
        logger.info(json.dumps({
            'messageId': message_id,
            'eventType': event_type,
            'topicArn': topic_arn
        }))
        
        # Route by event type
        if event_type == 'OrderPlaced':
            handle_order_placed(payload)
        elif event_type == 'PaymentCompleted':
            handle_payment_completed(payload)
        else:
            logger.warning(f"Unknown event type: {event_type}")


def handle_order_placed(order):
    logger.info(f"Sending confirmation email for order {order['orderId']}")
    # send email logic


def handle_payment_completed(payment):
    logger.info(f"Updating order status for payment {payment['paymentId']}")
    # update order logic
```

### SMS Notification Service

```python
def send_sms(phone_number, message):
    """Send SMS via SNS."""
    try:
        response = sns.publish(
            PhoneNumber=phone_number,  # E.164 format: +15551234567
            Message=message,
            MessageAttributes={
                'AWS.SNS.SMS.SenderID': {
                    'DataType': 'String',
                    'StringValue': 'MyShop'
                },
                'AWS.SNS.SMS.SMSType': {
                    'DataType': 'String',
                    'StringValue': 'Transactional'  # or Promotional
                }
            }
        )
        return response['MessageId']
    except Exception as e:
        logger.error(f"SMS delivery failed to {phone_number}: {e}")
        raise


def notify_order_shipped(order):
    if order.get('phone'):
        send_sms(
            order['phone'],
            f"Your order #{order['orderId']} has shipped! "
            f"Track at: https://track.myshop.com/{order['trackingId']}"
        )
```

### HTTP Subscription Verification

```python
# HTTP/HTTPS subscriptions receive a SubscriptionConfirmation first
import urllib.request

def webhook_handler(request):
    body = json.loads(request.body)
    message_type = request.headers.get('x-amz-sns-message-type')
    
    if message_type == 'SubscriptionConfirmation':
        # Auto-confirm subscription
        confirm_url = body['SubscribeURL']
        urllib.request.urlopen(confirm_url)
        return {'statusCode': 200}
    
    elif message_type == 'Notification':
        payload = json.loads(body['Message'])
        process_notification(payload)
        return {'statusCode': 200}
    
    elif message_type == 'UnsubscribeConfirmation':
        logger.info("Unsubscribed from SNS topic")
        return {'statusCode': 200}
```

---

*Next: [06-step-functions.md](06-step-functions.md)*

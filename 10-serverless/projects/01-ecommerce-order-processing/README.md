# Project 01: E-Commerce Order Processing System

**Difficulty:** Advanced  
**Services:** API Gateway + Lambda + DynamoDB + EventBridge + SQS + SNS + Step Functions

---

## Architecture

```
Customer
  │ POST /orders
  ▼
API Gateway (HTTP API)
  │ JWT auth (Cognito)
  ▼
Lambda: CreateOrderFunction
  │ 1. Validate input
  │ 2. Save to DynamoDB (status=PENDING)
  │ 3. PutEvent to EventBridge
  ▼
EventBridge (orders-bus)
  │
  ├──→ Step Functions (Order Workflow)
  │         │
  │         ├─ ValidateInventory (Lambda)
  │         ├─ CheckOrderValue → [>$5000 → Manager Approval (Task Token)]
  │         ├─ Parallel:
  │         │    ├─ ChargePayment (Lambda → Stripe API)
  │         │    └─ ReserveInventory (Lambda)
  │         ├─ CreateShipment (Lambda)
  │         ├─ UpdateDynamoDB (status=CONFIRMED)
  │         └─ Notify SNS
  │
  └──→ Analytics Lambda
          │ Stream to Kinesis for BI dashboards

SNS (order-notifications)
  ├── Email subscription (SES template)
  ├── SMS subscription (E.164 format)
  └── SQS (loyalty-queue) → Lambda (award points)
```

---

## Key Design Decisions

### 1. Saga Pattern for Distributed Transactions

```
If payment fails → Release inventory (compensate)
If shipment fails → Refund payment + Release inventory (compensate)
Each compensation step runs as a Task state in Step Functions
```

### 2. Idempotency

```python
# DynamoDB conditional write prevents duplicate orders
table.put_item(
    Item={'orderId': order_id, ...},
    ConditionExpression='attribute_not_exists(orderId)'
)
# If order already exists → ConditionCheckFailedException
# → Return 409 Conflict (not 500)
```

### 3. Event-First Design

```
Lambda saves to DB AND publishes event atomically:
  - Use DynamoDB Streams + EventBridge Pipes instead
  - OR: Transactional outbox pattern
  - Result: DB and event bus always in sync
```

---

## Lambda Functions

### 1. CreateOrderFunction

```python
import json
import boto3
import uuid
import time
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')
table = dynamodb.Table('Orders')

def handler(event, context):
    # Extract JWT claims
    claims = event['requestContext']['authorizer']['jwt']['claims']
    customer_id = claims['sub']
    
    # Parse body
    body = json.loads(event['body'])
    
    # Generate order ID
    order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    
    # Calculate total
    total = sum(item['price'] * item['quantity'] for item in body['items'])
    
    order = {
        'orderId': order_id,
        'customerId': customer_id,
        'items': body['items'],
        'amount': str(total),
        'status': 'PENDING',
        'createdAt': datetime.utcnow().isoformat(),
        'ttl': int(time.time()) + (90 * 24 * 3600)  # 90 day TTL
    }
    
    try:
        # Idempotent write
        table.put_item(
            Item=order,
            ConditionExpression='attribute_not_exists(orderId)'
        )
    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        return {'statusCode': 409, 'body': json.dumps({'error': 'Order already exists'})}
    
    # Publish event (fire and forget)
    events.put_events(Entries=[{
        'Source': 'com.myshop.orders',
        'DetailType': 'OrderCreated',
        'Detail': json.dumps(order),
        'EventBusName': 'orders-bus'
    }])
    
    return {
        'statusCode': 201,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'orderId': order_id, 'status': 'PENDING'})
    }
```

### 2. ValidateInventoryFunction

```python
def handler(event, context):
    items = event['items']
    
    for item in items:
        stock = check_stock(item['productId'])
        if stock < item['quantity']:
            raise InventoryException(
                f"Insufficient stock for {item['productId']}: "
                f"requested {item['quantity']}, available {stock}"
            )
    
    return {**event, 'inventoryValidated': True}


class InventoryException(Exception):
    pass
```

### 3. ChargePaymentFunction

```python
import stripe
import os

stripe.api_key = get_secret(os.environ['STRIPE_SECRET_ARN'])

def handler(event, context):
    order = event
    
    try:
        charge = stripe.PaymentIntent.create(
            amount=int(float(order['amount']) * 100),  # cents
            currency='usd',
            customer=order['stripeCustomerId'],
            payment_method=order['paymentMethodId'],
            confirm=True,
            idempotency_key=order['orderId']  # Stripe idempotency key
        )
        
        return {
            **order,
            'paymentId': charge['id'],
            'paymentStatus': charge['status']
        }
    
    except stripe.error.CardError as e:
        raise PaymentDeclinedException(str(e.user_message))


class PaymentDeclinedException(Exception):
    pass
```

---

## State Machine Definition

```json
{
  "Comment": "E-Commerce Order Processing Saga",
  "StartAt": "ValidateInventory",
  "States": {
    "ValidateInventory": {
      "Type": "Task",
      "Resource": "${ValidateInventoryFunctionArn}",
      "Next": "CheckOrderValue",
      "Retry": [{
        "ErrorEquals": ["Lambda.ServiceException"],
        "MaxAttempts": 3,
        "IntervalSeconds": 2,
        "BackoffRate": 2
      }],
      "Catch": [{
        "ErrorEquals": ["InventoryException"],
        "Next": "NotifyOutOfStock",
        "ResultPath": "$.error"
      }]
    },

    "CheckOrderValue": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.amount",
        "NumericGreaterThan": 5000,
        "Next": "RequireManagerApproval"
      }],
      "Default": "ProcessPaymentAndInventory"
    },

    "RequireManagerApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "${ApprovalFunctionArn}",
        "Payload": {
          "taskToken.$": "$$.Task.Token",
          "order.$": "$"
        }
      },
      "TimeoutSeconds": 86400,
      "Next": "ProcessPaymentAndInventory",
      "Catch": [{
        "ErrorEquals": ["HumanRejected"],
        "Next": "NotifyOrderRejected"
      }]
    },

    "ProcessPaymentAndInventory": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "ChargePayment",
          "States": {
            "ChargePayment": {
              "Type": "Task",
              "Resource": "${ChargePaymentFunctionArn}",
              "End": true,
              "Retry": [{
                "ErrorEquals": ["Lambda.ServiceException"],
                "MaxAttempts": 2
              }]
            }
          }
        },
        {
          "StartAt": "ReserveInventory",
          "States": {
            "ReserveInventory": {
              "Type": "Task",
              "Resource": "${ReserveInventoryFunctionArn}",
              "End": true
            }
          }
        }
      ],
      "ResultPath": "$.processingResults",
      "Next": "CreateShipment",
      "Catch": [{
        "ErrorEquals": ["PaymentDeclinedException"],
        "Next": "CompensateInventory",
        "ResultPath": "$.error"
      }, {
        "ErrorEquals": ["States.ALL"],
        "Next": "CompensateAll",
        "ResultPath": "$.error"
      }]
    },

    "CreateShipment": {
      "Type": "Task",
      "Resource": "${CreateShipmentFunctionArn}",
      "Next": "UpdateOrderConfirmed",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "CompensateAll",
        "ResultPath": "$.error"
      }]
    },

    "UpdateOrderConfirmed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "Orders",
        "Key": { "orderId": { "S.$": "$.orderId" } },
        "UpdateExpression": "SET #s = :status, confirmedAt = :now",
        "ExpressionAttributeNames": { "#s": "status" },
        "ExpressionAttributeValues": {
          ":status": { "S": "CONFIRMED" },
          ":now": { "S.$": "$$.State.EnteredTime" }
        }
      },
      "Next": "NotifyCustomer"
    },

    "NotifyCustomer": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${NotificationTopicArn}",
        "Message.$": "States.Format('Order {} confirmed! Total: ${}', $.orderId, $.amount)",
        "MessageAttributes": {
          "eventType": { "DataType": "String", "StringValue": "OrderConfirmed" },
          "customerId": { "DataType": "String.$", "StringValue.$": "$.customerId" }
        }
      },
      "Next": "OrderComplete"
    },

    "OrderComplete": { "Type": "Succeed" },

    "CompensateInventory": {
      "Type": "Task",
      "Resource": "${ReleaseInventoryFunctionArn}",
      "Next": "NotifyPaymentFailed"
    },

    "CompensateAll": {
      "Type": "Task",
      "Resource": "${CompensateOrderFunctionArn}",
      "Next": "NotifyOrderFailed"
    },

    "NotifyOutOfStock": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${NotificationTopicArn}",
        "Message.$": "States.Format('Order {} failed: out of stock', $.orderId)"
      },
      "Next": "OrderFailed"
    },

    "NotifyPaymentFailed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "${NotificationTopicArn}",
        "Message.$": "States.Format('Payment failed for order {}', $.orderId)"
      },
      "Next": "OrderFailed"
    },

    "NotifyOrderRejected": { "Next": "OrderFailed", "Type": "Pass" },
    "NotifyOrderFailed": { "Next": "OrderFailed", "Type": "Pass" },

    "OrderFailed": {
      "Type": "Fail",
      "Error": "OrderFailed",
      "Cause": "Order processing failed — compensation applied"
    }
  }
}
```

---

## DynamoDB Table Design

```
Table: Orders
PK: orderId (String)
GSI-1: customerId-createdAt-index
  PK: customerId
  SK: createdAt

Attributes:
  orderId, customerId, items, amount, status,
  createdAt, confirmedAt, shippedAt, paymentId,
  trackingId, ttl

Access Patterns:
  1. Get order by ID          → PK lookup
  2. List orders by customer  → GSI-1 query
  3. Orders in last 30 days   → GSI-1 + begins_with/between on SK
```

---

## Cost Estimate (10,000 orders/day)

```
Service           | Monthly Cost
──────────────────┼──────────────
API Gateway HTTP  | ~$0.30
Lambda            | ~$2.50
DynamoDB          | ~$5.00
EventBridge       | ~$0.50
Step Functions    | ~$1.00
SNS               | ~$1.00
SQS               | ~$0.50
──────────────────┼──────────────
TOTAL             | ~$11/month

vs EC2 t3.medium: ~$30/month (fixed, no elasticity)
```

---

## Testing

```bash
# Place a test order
curl -X POST https://api.myshop.com/orders \
    -H "Authorization: Bearer <jwt-token>" \
    -H "Content-Type: application/json" \
    -d '{
        "items": [
            {"productId": "PROD-001", "quantity": 2, "price": 49.99}
        ],
        "paymentMethodId": "pm_test_visa"
    }'

# Check order status
curl https://api.myshop.com/orders/ORD-ABC12345 \
    -H "Authorization: Bearer <jwt-token>"

# Check Step Functions execution
aws stepfunctions list-executions \
    --state-machine-arn $STATE_MACHINE_ARN \
    --status-filter RUNNING
```

# 06 — AWS Step Functions: Workflow Orchestration

---

## Table of Contents
1. [What Is Step Functions](#what-is-step-functions)
2. [Standard vs Express Workflows](#standard-vs-express-workflows)
3. [State Types](#state-types)
4. [Error Handling](#error-handling)
5. [Parallel & Map States](#parallel--map-states)
6. [Wait & Callback Patterns](#wait--callback-patterns)
7. [Express Workflows](#express-workflows)
8. [Integrations](#integrations)
9. [Real-World Patterns](#real-world-patterns)
10. [Code Examples](#code-examples)

---

## What Is Step Functions

AWS Step Functions is a **serverless orchestration service** that coordinates multiple AWS services into visual workflows called **state machines**.

### Why Use Step Functions?

```
WITHOUT Step Functions (Lambda orchestration):
  Lambda A → calls Lambda B → calls Lambda C
  Problems:
    ✗ Tight coupling between functions
    ✗ Error handling = complex nested try/catch
    ✗ Hard to retry individual steps
    ✗ State must be passed manually in payloads
    ✗ Hard to visualize workflow
    ✗ Hard to debug failed execution

WITH Step Functions:
  State Machine defines the workflow
    ✓ Each step independent
    ✓ Built-in retry and catch per step
    ✓ Visual execution history
    ✓ Easy to add/remove steps
    ✓ Human approval steps
    ✓ Parallel branching
    ✓ Wait for external callback
```

### When to Use Step Functions

```
✓ Multi-step business workflows (order processing, loan approval)
✓ Parallel processing with fan-out/fan-in
✓ Human approval in the middle of a workflow
✓ Long-running processes (days, weeks)
✓ Saga pattern for distributed transactions
✓ ETL pipelines
✓ Microservice orchestration (vs choreography)

✗ Simple single-step invocations (just use Lambda directly)
✗ Real-time, ultra-low latency (Step Functions adds ~10ms per state)
✗ Very high volume simple events (use SQS/Lambda)
```

---

## Standard vs Express Workflows

```
Feature               | Standard          | Express
──────────────────────┼───────────────────┼──────────────────────
Max Duration          | 1 year            | 5 minutes
Execution Model       | At-most-once      | At-least-once
History              | 25,000 events     | CloudWatch Logs only
Execution rate        | 2,000/sec (soft)  | 100,000/sec
Pricing               | Per state transition ($0.025/1K)
                      |                   | Per execution duration
                      |                   | ($0.00001/sec + $1/M exec)
Use cases             | Business workflows| High-volume, short-lived
                      | Long running      | Event processing
                      | Human approvals   | IoT events
                      | Financial txns    | Streaming data
Idempotency           | YES               | NO (may run twice)
Sync execution        | NO                | YES (StartSync)
```

---

## State Types

### 1. Task State

Calls a Lambda, AWS service, or custom activity.

```json
{
  "ValidateOrder": {
    "Type": "Task",
    "Resource": "arn:aws:lambda:us-east-1:123:function:validate-order",
    "Parameters": {
      "orderId.$": "$.orderId",
      "customerId.$": "$.customerId"
    },
    "ResultPath": "$.validationResult",
    "Next": "CheckInventory",
    "Retry": [
      {
        "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2.0,
        "JitterStrategy": "FULL"
      }
    ],
    "Catch": [
      {
        "ErrorEquals": ["ValidationError"],
        "Next": "OrderRejected",
        "ResultPath": "$.error"
      }
    ]
  }
}
```

### 2. Choice State

Branch based on conditions.

```json
{
  "CheckOrderValue": {
    "Type": "Choice",
    "Choices": [
      {
        "Variable": "$.amount",
        "NumericGreaterThan": 1000,
        "Next": "RequireManagerApproval"
      },
      {
        "Variable": "$.customerTier",
        "StringEquals": "VIP",
        "Next": "VIPProcessing"
      },
      {
        "And": [
          { "Variable": "$.amount", "NumericGreaterThanEquals": 100 },
          { "Variable": "$.amount", "NumericLessThan": 1000 }
        ],
        "Next": "StandardProcessing"
      }
    ],
    "Default": "SmallOrderProcessing"
  }
}
```

### 3. Wait State

Pause execution for a duration or until a timestamp.

```json
{
  "WaitForPaymentConfirmation": {
    "Type": "Wait",
    "Seconds": 300,
    "Next": "CheckPaymentStatus"
  }
}

// Wait until specific timestamp from input
{
  "WaitUntilDeliveryDate": {
    "Type": "Wait",
    "TimestampPath": "$.scheduledDeliveryTime",
    "Next": "TriggerDelivery"
  }
}
```

### 4. Parallel State

Execute multiple branches simultaneously.

```json
{
  "ProcessOrderInParallel": {
    "Type": "Parallel",
    "Branches": [
      {
        "StartAt": "ChargePayment",
        "States": {
          "ChargePayment": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:charge-payment",
            "End": true
          }
        }
      },
      {
        "StartAt": "ReserveInventory",
        "States": {
          "ReserveInventory": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:reserve-inventory",
            "End": true
          }
        }
      },
      {
        "StartAt": "SendConfirmationEmail",
        "States": {
          "SendConfirmationEmail": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:...:function:send-email",
            "End": true
          }
        }
      }
    ],
    "Next": "FulfillOrder",
    "ResultPath": "$.parallelResults"
  }
}
```

### 5. Map State

Iterate over an array and process each item.

```json
{
  "ProcessOrderItems": {
    "Type": "Map",
    "ItemsPath": "$.order.items",
    "MaxConcurrency": 5,
    "Iterator": {
      "StartAt": "ProcessItem",
      "States": {
        "ProcessItem": {
          "Type": "Task",
          "Resource": "arn:aws:lambda:...:function:process-item",
          "End": true
        }
      }
    },
    "ResultPath": "$.processedItems",
    "Next": "CompleteOrder"
  }
}
```

### 6. Pass State

Pass input to output, optionally with transformation.

```json
{
  "AddMetadata": {
    "Type": "Pass",
    "Parameters": {
      "orderId.$": "$.orderId",
      "processedAt": "2026-06-17T10:00:00Z",
      "source": "api",
      "version": "1.0"
    },
    "ResultPath": "$.metadata",
    "Next": "ProcessOrder"
  }
}
```

### 7. Succeed / Fail States

```json
{
  "OrderCompleted": {
    "Type": "Succeed"
  }
}

{
  "OrderFailed": {
    "Type": "Fail",
    "Error": "OrderProcessingFailed",
    "Cause": "Payment declined after 3 retries"
  }
}
```

---

## Error Handling

### Retry Configuration

```json
{
  "Retry": [
    {
      "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
      "IntervalSeconds": 2,
      "MaxAttempts": 6,
      "BackoffRate": 2,
      "JitterStrategy": "FULL"
    },
    {
      "ErrorEquals": ["Lambda.TooManyRequestsException"],
      "IntervalSeconds": 1,
      "MaxAttempts": 10,
      "BackoffRate": 1.5
    },
    {
      "ErrorEquals": ["States.Timeout"],
      "MaxAttempts": 2,
      "IntervalSeconds": 30
    }
  ]
}
```

### Catch Configuration

```json
{
  "Catch": [
    {
      "ErrorEquals": ["PaymentDeclinedException"],
      "Next": "NotifyCustomerPaymentFailed",
      "ResultPath": "$.error"
    },
    {
      "ErrorEquals": ["InventoryException"],
      "Next": "NotifyOutOfStock",
      "ResultPath": "$.error"
    },
    {
      "ErrorEquals": ["States.ALL"],
      "Next": "HandleUnexpectedError",
      "ResultPath": "$.error"
    }
  ]
}
```

### Lambda Throwing Custom Errors

```python
class PaymentDeclinedException(Exception):
    pass

class InventoryException(Exception):
    pass

def handler(event, context):
    try:
        result = charge_payment(event['paymentDetails'])
        return result
    except PaymentError as e:
        # Step Functions catches the function name from the exception class
        raise PaymentDeclinedException(str(e))
    except StockError as e:
        raise InventoryException(str(e))
```

---

## Parallel & Map States

### Fan-Out / Fan-In

```
Input: { "orderId": "ORD-123", "items": [...] }
                │
                ▼
         Parallel State
        ┌───────┼───────┐
        ▼       ▼       ▼
    Charge   Reserve  Send Email
    Payment  Inventory
        │       │       │
        └───────┴───────┘
                │
                ▼
        Merge results (ResultPath)
        → { "payment": {...}, "inventory": {...}, "email": {...} }
```

### Map with Distributed Processing

```json
{
  "Type": "Map",
  "ItemsPath": "$.orderIds",
  "MaxConcurrency": 40,
  "ToleratedFailurePercentage": 10,
  "Label": "ProcessBatchOrders",
  "ItemSelector": {
    "orderId.$": "$$.Map.Item.Value",
    "batchId.$": "$.batchId"
  },
  "ItemProcessor": {
    "ProcessorConfig": {
      "Mode": "DISTRIBUTED",
      "ExecutionType": "EXPRESS"
    },
    "StartAt": "ProcessSingleOrder",
    "States": {
      "ProcessSingleOrder": {
        "Type": "Task",
        "Resource": "arn:aws:lambda:...:function:process-order",
        "End": true
      }
    }
  }
}
```

---

## Wait & Callback Patterns

### Callback Pattern (Task Token)

Used when a step requires an async external response (human approval, external API).

```json
{
  "WaitForHumanApproval": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
    "Parameters": {
      "FunctionName": "send-approval-request",
      "Payload": {
        "orderId.$": "$.orderId",
        "amount.$": "$.amount",
        "taskToken.$": "$$.Task.Token"
      }
    },
    "TimeoutSeconds": 86400,
    "HeartbeatSeconds": 3600,
    "Next": "ProcessApproval"
  }
}
```

```python
# Lambda: send approval request with task token
def handler(event, context):
    task_token = event['taskToken']
    order_id = event['orderId']
    amount = event['amount']
    
    # Send email with approve/reject links
    approval_url = f"https://api.myapp.com/approve?token={task_token}&action=approve"
    reject_url = f"https://api.myapp.com/approve?token={task_token}&action=reject"
    
    send_email(
        to='manager@company.com',
        subject=f"Approval Required: Order {order_id} (${amount})",
        body=f"Approve: {approval_url}\nReject: {reject_url}"
    )
    # Lambda returns — Step Functions waits for callback


# Approval endpoint: resumes Step Functions
def approval_handler(event, context):
    task_token = event['queryStringParameters']['token']
    action = event['queryStringParameters']['action']
    
    sfn = boto3.client('stepfunctions')
    
    if action == 'approve':
        sfn.send_task_success(
            taskToken=task_token,
            output=json.dumps({'approved': True, 'approvedBy': 'manager@company.com'})
        )
    else:
        sfn.send_task_failure(
            taskToken=task_token,
            error='HumanRejected',
            cause='Manager rejected the order'
        )
    
    return {'statusCode': 200, 'body': f'Order {action}d successfully'}
```

---

## Express Workflows

### Synchronous Express Workflow

Returns result immediately (like a synchronous Lambda call).

```python
sfn = boto3.client('stepfunctions')

def process_order_sync(order_data):
    """Call Step Functions synchronously — waits for result."""
    
    response = sfn.start_sync_execution(
        stateMachineArn='arn:aws:states:us-east-1:123:stateMachine:OrderProcessor',
        name=f"order-{order_data['orderId']}-{int(time.time())}",
        input=json.dumps(order_data)
    )
    
    if response['status'] == 'SUCCEEDED':
        return json.loads(response['output'])
    else:
        error = response.get('error', 'Unknown error')
        cause = response.get('cause', '')
        raise Exception(f"Workflow failed: {error} - {cause}")
```

---

## Integrations

### SDK Integrations (No Lambda Needed)

Step Functions can call AWS services directly without Lambda:

```json
// DynamoDB PutItem directly
{
  "SaveOrder": {
    "Type": "Task",
    "Resource": "arn:aws:states:::dynamodb:putItem",
    "Parameters": {
      "TableName": "Orders",
      "Item": {
        "orderId": { "S.$": "$.orderId" },
        "status": { "S": "PENDING" },
        "amount": { "N.$": "States.Format('{}', $.amount)" },
        "createdAt": { "S.$": "$$.Execution.StartTime" }
      }
    },
    "Next": "PublishEvent"
  }
}

// SNS Publish directly
{
  "PublishEvent": {
    "Type": "Task",
    "Resource": "arn:aws:states:::sns:publish",
    "Parameters": {
      "TopicArn": "arn:aws:sns:us-east-1:123:order-events",
      "Message.$": "States.JsonToString($.order)",
      "MessageAttributes": {
        "eventType": {
          "DataType": "String",
          "StringValue": "OrderConfirmed"
        }
      }
    },
    "Next": "Done"
  }
}

// SQS SendMessage directly
{
  "QueueForProcessing": {
    "Type": "Task",
    "Resource": "arn:aws:states:::sqs:sendMessage",
    "Parameters": {
      "QueueUrl": "https://sqs.us-east-1.amazonaws.com/123/payment-queue",
      "MessageBody.$": "States.JsonToString($.paymentDetails)"
    },
    "End": true
  }
}
```

---

## Real-World Patterns

### Saga Pattern (Distributed Transaction)

```json
{
  "Comment": "Order Saga — compensate on failure",
  "StartAt": "ReserveInventory",
  "States": {
    "ReserveInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:reserve-inventory",
      "Next": "ChargePayment",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "SagaFailed"
      }]
    },
    "ChargePayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:charge-payment",
      "Next": "CreateShipment",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "ReleaseInventory"
      }]
    },
    "CreateShipment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:create-shipment",
      "Next": "OrderComplete",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "RefundPayment"
      }]
    },
    "OrderComplete": { "Type": "Succeed" },
    
    "RefundPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:refund-payment",
      "Next": "ReleaseInventory"
    },
    "ReleaseInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:release-inventory",
      "Next": "SagaFailed"
    },
    "SagaFailed": {
      "Type": "Fail",
      "Error": "OrderFailed",
      "Cause": "Transaction rolled back"
    }
  }
}
```

### Lambda Power Tuning State Machine

```
Step Functions orchestrates the Lambda Power Tuning tool:

Initialize → Parallel (test 10 memory configs) → Analyze → Cleanup
         ↗ [128MB test]
         ↗ [256MB test]
         ↗ [512MB test]
         ↗ [1024MB test]
         ↗ [2048MB test]
```

---

## Code Examples

### Starting a Workflow from Lambda

```python
import boto3
import json
import uuid

sfn = boto3.client('stepfunctions')
STATE_MACHINE_ARN = 'arn:aws:states:us-east-1:123:stateMachine:OrderWorkflow'

def handler(event, context):
    """API Gateway → Lambda → Start Step Functions execution."""
    
    body = json.loads(event['body'])
    order_id = body.get('orderId', str(uuid.uuid4()))
    
    # Start async execution
    response = sfn.start_execution(
        stateMachineArn=STATE_MACHINE_ARN,
        name=f"order-{order_id}",  # unique per execution
        input=json.dumps({
            'orderId': order_id,
            'customerId': body['customerId'],
            'items': body['items'],
            'amount': body['amount'],
            'correlationId': context.aws_request_id
        })
    )
    
    execution_arn = response['executionArn']
    
    return {
        'statusCode': 202,
        'body': json.dumps({
            'orderId': order_id,
            'executionArn': execution_arn,
            'status': 'PROCESSING'
        })
    }


def check_execution_status(execution_arn):
    """Poll execution status."""
    response = sfn.describe_execution(executionArn=execution_arn)
    return {
        'status': response['status'],
        'startDate': str(response['startDate']),
        'output': json.loads(response.get('output', '{}'))
        if response['status'] == 'SUCCEEDED' else None,
        'error': response.get('error'),
        'cause': response.get('cause')
    }
```

### Complete Order Processing State Machine

```json
{
  "Comment": "E-Commerce Order Processing Workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:validate-order",
      "ResultPath": "$.validation",
      "Next": "IsOrderValid",
      "Retry": [{ "ErrorEquals": ["Lambda.ServiceException"], "MaxAttempts": 3 }],
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "HandleValidationError" }]
    },

    "IsOrderValid": {
      "Type": "Choice",
      "Choices": [
        { "Variable": "$.validation.valid", "BooleanEquals": true, "Next": "CheckOrderValue" },
        { "Variable": "$.validation.valid", "BooleanEquals": false, "Next": "RejectOrder" }
      ]
    },

    "CheckOrderValue": {
      "Type": "Choice",
      "Choices": [
        { "Variable": "$.amount", "NumericGreaterThan": 5000, "Next": "RequireApproval" }
      ],
      "Default": "ProcessOrderInParallel"
    },

    "RequireApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "send-approval-email",
        "Payload": { "taskToken.$": "$$.Task.Token", "order.$": "$" }
      },
      "TimeoutSeconds": 86400,
      "Next": "ProcessOrderInParallel",
      "Catch": [{ "ErrorEquals": ["HumanRejected"], "Next": "RejectOrder" }]
    },

    "ProcessOrderInParallel": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "ChargePayment",
          "States": {
            "ChargePayment": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:...:function:charge-payment",
              "End": true
            }
          }
        },
        {
          "StartAt": "ReserveInventory",
          "States": {
            "ReserveInventory": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:...:function:reserve-inventory",
              "End": true
            }
          }
        }
      ],
      "ResultPath": "$.parallelResults",
      "Next": "FulfillOrder",
      "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "CompensateTransaction" }]
    },

    "FulfillOrder": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "fulfill-order",
        "Payload.$": "$"
      },
      "Next": "NotifyCustomer"
    },

    "NotifyCustomer": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sns:publish",
      "Parameters": {
        "TopicArn": "arn:aws:sns:us-east-1:123:customer-notifications",
        "Message.$": "States.Format('Your order {} has been confirmed!', $.orderId)"
      },
      "Next": "OrderComplete"
    },

    "OrderComplete": { "Type": "Succeed" },

    "CompensateTransaction": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:compensate-order",
      "Next": "OrderFailed"
    },

    "RejectOrder": {
      "Type": "Fail",
      "Error": "OrderRejected",
      "Cause": "Order failed validation or was rejected"
    },

    "OrderFailed": {
      "Type": "Fail",
      "Error": "ProcessingFailed",
      "Cause": "Order processing failed, transaction compensated"
    },

    "HandleValidationError": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:function:handle-error",
      "Next": "OrderFailed"
    }
  }
}
```

---

*Next: [07-serverless-patterns.md](07-serverless-patterns.md)*

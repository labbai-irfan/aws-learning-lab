# 01 — AWS Lambda: Core Concepts

---

## Table of Contents
1. [What Is Lambda](#what-is-lambda)
2. [Execution Model](#execution-model)
3. [Cold Starts](#cold-starts)
4. [Memory & Performance](#memory--performance)
5. [Triggers & Event Sources](#triggers--event-sources)
6. [Lambda Destinations](#lambda-destinations)
7. [Layers](#layers)
8. [Container Images](#container-images)
9. [Lambda Extensions](#lambda-extensions)
10. [Concurrency](#concurrency)
11. [Monitoring & Observability](#monitoring--observability)
12. [Code Examples](#code-examples)
13. [Best Practices](#best-practices)

---

## What Is Lambda

AWS Lambda is a **Function-as-a-Service (FaaS)** that:
- Runs code without provisioning or managing servers
- Scales from 0 to thousands of concurrent instances automatically
- Charges only for compute time consumed (100ms billing granularity)
- Supports multiple runtimes: Python, Node.js, Java, Go, .NET, Ruby, custom

### Lambda Execution Environment

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Lambda Service                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Execution Environment                    │    │
│  │                                                       │    │
│  │  ┌─────────────┐  ┌───────────────┐  ┌──────────┐  │    │
│  │  │   Runtime   │  │  Your Code    │  │  /tmp    │  │    │
│  │  │  (Python,   │  │  (handler +   │  │ (ephemeral│  │    │
│  │  │  Node.js)   │  │   libraries)  │  │  storage) │  │    │
│  │  └─────────────┘  └───────────────┘  └──────────┘  │    │
│  │                                                       │    │
│  │  Environment Variables  │  IAM Role Credentials      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Execution Model

### Lifecycle Phases

```
1. INIT PHASE (cold start only)
   ├── Download your code package
   ├── Start the runtime (Python interpreter, JVM, etc.)
   ├── Run initialization code OUTSIDE the handler
   └── Create execution environment

2. INVOKE PHASE (every request)
   ├── Run your handler function
   ├── Return response
   └── Environment stays warm for reuse

3. SHUTDOWN PHASE
   ├── Runtime receives SIGTERM
   ├── Extension cleanup
   └── Environment destroyed
```

### Handler Function Structure

```python
# Python handler
import json
import boto3

# INIT: runs once during cold start
dynamodb = boto3.resource('dynamodb')  # connection created once
table = dynamodb.Table('Orders')

def handler(event, context):
    """
    event   — dict with trigger data (API request, S3 event, etc.)
    context — runtime info: function name, remaining time, request ID
    """
    # INVOKE: runs on every request
    order_id = event.get('pathParameters', {}).get('orderId')
    
    response = table.get_item(Key={'orderId': order_id})
    
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(response.get('Item', {}))
    }
```

```javascript
// Node.js handler
const { DynamoDBClient, GetItemCommand } = require('@aws-sdk/client-dynamodb');

// INIT: runs once
const client = new DynamoDBClient({ region: 'us-east-1' });

exports.handler = async (event, context) => {
    // INVOKE: runs on every request
    const orderId = event.pathParameters?.orderId;
    
    const response = await client.send(new GetItemCommand({
        TableName: 'Orders',
        Key: { orderId: { S: orderId } }
    }));
    
    return {
        statusCode: 200,
        body: JSON.stringify(response.Item)
    };
};
```

### Context Object

```python
def handler(event, context):
    print(context.function_name)          # my-function
    print(context.function_version)       # $LATEST or version number
    print(context.invoked_function_arn)   # full ARN
    print(context.memory_limit_in_mb)     # 512
    print(context.remaining_time_in_millis()) # ms until timeout
    print(context.aws_request_id)         # unique invocation ID
    print(context.log_group_name)         # CloudWatch log group
    print(context.log_stream_name)        # CloudWatch log stream
```

---

## Cold Starts

### What Causes a Cold Start?

```
Cold start occurs when:
  1. No warm execution environment is available
  2. First invocation after deployment
  3. After scaling out to new concurrent instances
  4. After period of inactivity (~15 minutes)

NOT a cold start:
  1. Subsequent calls to the same warm environment
  2. Concurrent invocations up to the number of warm instances
```

### Cold Start Duration by Runtime

```
Runtime          | Typical Cold Start
─────────────────┼───────────────────
Python 3.12      | 100–400ms
Node.js 20       | 100–300ms
.NET 8           | 500ms–2s
Java 21          | 500ms–4s
Java + SnapStart | 200–500ms  (uses snapshot)
Go               | 50–200ms
Custom Runtime   | varies
Container Image  | 1–10s (larger = slower)
```

### Cold Start Mitigation Strategies

#### 1. Provisioned Concurrency
```yaml
# CloudFormation / SAM
MyFunction:
  Type: AWS::Serverless::Function
  Properties:
    ProvisionedConcurrencyConfig:
      ProvisionedConcurrentExecutions: 10

# Cost: ~$0.015 per GB-hour provisioned (always-on)
# Use for: latency-sensitive APIs
```

#### 2. Lambda SnapStart (Java)
```yaml
MyJavaFunction:
  Type: AWS::Serverless::Function
  Properties:
    Runtime: java21
    SnapStart:
      ApplyOn: PublishedVersions
# AWS snapshots the initialized environment
# Restores from snapshot instead of cold-init
# 90% reduction in cold start time for Java
```

#### 3. Minimize Package Size
```
# Reduce import time
DO:    from boto3 import client              # lazy import specific client
AVOID: import boto3                          # loads entire SDK

# Use Lambda Layers for shared deps
# Keep handler file lean
# Tree-shake Node.js with webpack/esbuild
```

#### 4. Keep Functions Warm (Scheduled Ping)
```python
# EventBridge rule: every 5 minutes
# Lambda handler:
def handler(event, context):
    if event.get('source') == 'aws.events':
        print('Warm-up ping, skipping processing')
        return {'statusCode': 200}
    # ... real logic
```

---

## Memory & Performance

### Memory Configuration

```
Range: 128MB to 10,240MB (in 1MB increments)

CPU allocation scales linearly with memory:
  128MB   → 0.125 vCPUs
  1,769MB → 1 vCPU
  3,538MB → 2 vCPUs
  10,240MB → 6 vCPUs

Memory also affects:
  - Network bandwidth (more memory = more bandwidth)
  - /tmp storage speed
  - Garbage collection performance (JVM, .NET)
```

### AWS Lambda Power Tuning Results (example)

```
Function: Image resize (CPU-bound)

Memory   | Duration | Cost/1M req
─────────┼──────────┼────────────
128MB    | 11,000ms | $2.86      ← cheapest memory, most expensive
256MB    | 5,200ms  | $2.71
512MB    | 2,100ms  | $2.19
1024MB   | 720ms    | $1.50      ← sweet spot for this function
2048MB   | 380ms    | $1.58
3008MB   | 260ms    | $1.59

→ 1024MB is optimal: fastest and cheapest per invocation
```

### Timeout Configuration

```
Default: 3 seconds
Maximum: 900 seconds (15 minutes)

Set timeout based on:
  - P99 latency of downstream calls
  - Maximum acceptable user wait time
  - SQS visibility timeout (must be > Lambda timeout)

Rule: timeout = max_expected_duration × 1.5 + buffer
```

---

## Triggers & Event Sources

### Synchronous Triggers

```
Source              | Invocation | Retry  | Notes
────────────────────┼────────────┼────────┼───────────────────────
API Gateway         | Sync       | None   | 29s timeout
Lambda Function URL | Sync       | None   | 15min timeout
ALB                 | Sync       | None   | 29s timeout
Cognito             | Sync       | None   | Pre/Post triggers
CloudFront          | Sync       | None   | Lambda@Edge
```

### Asynchronous Triggers

```
Source              | Invocation | Retry  | Notes
────────────────────┼────────────┼────────┼───────────────────────
S3                  | Async      | 2x     | Object events
SNS                 | Async      | 2x     | Message delivery
EventBridge         | Async      | 2x     | Event rules
SES                 | Async      | 2x     | Email receipt
CloudFormation      | Async      | 2x     | Custom resources
Config              | Async      | 2x     | Rule evaluations
```

### Poll-Based Triggers (Event Source Mapping)

```
Source              | Invocation | Retry  | Notes
────────────────────┼────────────┼────────┼───────────────────────
SQS                 | Poll       | Until  | Batch size 1-10,000
Kinesis             | Poll       | Until  | Batch size 1-10,000
DynamoDB Streams    | Poll       | Until  | Batch size 1-10,000
MSK (Kafka)         | Poll       | Until  | Self-managed Kafka
```

### S3 Event Example

```python
def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key    = record['s3']['object']['key']
        size   = record['s3']['object']['size']
        
        print(f"Processing: s3://{bucket}/{key} ({size} bytes)")
        # ... process the file
```

### SQS Event Example

```python
def handler(event, context):
    failed_items = []
    
    for record in event['Records']:
        message_id = record['messageId']
        body = json.loads(record['body'])
        
        try:
            process_message(body)
        except Exception as e:
            print(f"Failed to process {message_id}: {e}")
            failed_items.append({'itemIdentifier': message_id})
    
    # Return failed items — Lambda will retry only these
    return {'batchItemFailures': failed_items}
```

---

## Lambda Destinations

Destinations route the result of an **async** invocation:

```
Async Event → Lambda → SUCCESS → Destination A (SQS/SNS/EventBridge/Lambda)
                    → FAILURE → Destination B (SQS/SNS/EventBridge/Lambda)
```

```python
# Configuration via AWS console, CDK, or SAM
# Function configuration:
{
  "FunctionResponseTypes": ["ReportBatchItemFailures"],
  "DestinationConfig": {
    "OnSuccess": {
      "Destination": "arn:aws:sqs:us-east-1:123:success-queue"
    },
    "OnFailure": {
      "Destination": "arn:aws:sqs:us-east-1:123:dlq"
    }
  }
}
```

### Destinations vs DLQ

```
Feature          | Destinations           | DLQ
─────────────────┼────────────────────────┼──────────────────
Success routing  | YES                    | No
Failure routing  | YES                    | YES
Payload          | Full event + response  | Original event only
Targets          | SQS, SNS, EB, Lambda   | SQS, SNS
Async only?      | YES                    | YES (also SQS ESM)
Recommendation   | Prefer Destinations    | Legacy option
```

---

## Layers

Lambda Layers let you share code and dependencies across functions.

### Use Cases
- Shared utility libraries
- Large dependencies (numpy, Pillow) — keep function package small
- Custom runtimes
- Security agents, monitoring tools

### Creating a Layer

```bash
# 1. Create layer content
mkdir -p python/lib/python3.12/site-packages
pip install requests -t python/lib/python3.12/site-packages

# 2. Zip and publish
zip -r layer.zip python/
aws lambda publish-layer-version \
    --layer-name my-requests-layer \
    --zip-file fileb://layer.zip \
    --compatible-runtimes python3.12

# 3. Attach to function
aws lambda update-function-configuration \
    --function-name my-function \
    --layers arn:aws:lambda:us-east-1:123:layer:my-requests-layer:1
```

### Layer Limits

```
Max layers per function:  5
Max unzipped size:        250MB total (function + all layers)
Layer file locations:
  Python: /opt/python/
  Node.js: /opt/nodejs/node_modules/
  Java:    /opt/java/lib/
```

---

## Container Images

Deploy Lambda as Docker containers — up to 10GB images.

```dockerfile
# Dockerfile
FROM public.ecr.aws/lambda/python:3.12

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY app.py ${LAMBDA_TASK_ROOT}

# Set handler
CMD ["app.handler"]
```

```bash
# Build and push to ECR
aws ecr create-repository --repository-name my-lambda-repo

docker build -t my-lambda .
docker tag my-lambda:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/my-lambda:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/my-lambda:latest

# Create function from image
aws lambda create-function \
    --function-name my-container-function \
    --package-type Image \
    --code ImageUri=123456789.dkr.ecr.us-east-1.amazonaws.com/my-lambda:latest \
    --role arn:aws:iam::123456789:role/lambda-role
```

---

## Lambda Extensions

Extensions run alongside your function in the same execution environment.

```
Types:
  Internal: registered during Init phase, runs in same process
  External: separate process, runs before/after handler

Use cases:
  - Capture diagnostic info (traces, logs, metrics)
  - Fetch secrets/config before invocation
  - Crash reporting (Datadog, New Relic, Dynatrace agents)
  - Custom runtimes

Extension lifecycle:
  INIT: extension registers for INVOKE and SHUTDOWN events
  INVOKE: receives event, runs in parallel with function
  SHUTDOWN: 2 seconds to clean up
```

---

## Concurrency

### How Concurrency Works

```
Concurrent executions = requests being processed simultaneously

Example: 100 simultaneous API calls → 100 concurrent Lambda instances

AWS Account limit: 1,000 concurrent per region (soft limit)
Can be increased via Service Quotas

Formula:
  Concurrency = RPS × Average_Duration_in_seconds
  Example: 500 req/s × 0.1s = 50 concurrent
```

### Concurrency Types

```
UNRESERVED CONCURRENCY
  - Shared pool from account limit
  - Functions compete for capacity
  - No guarantee for any single function

RESERVED CONCURRENCY
  - Guarantees a function will always have N executions
  - Also CAPS the function at N (throttle above limit)
  - Other functions cannot use reserved capacity
  - Cost: FREE

PROVISIONED CONCURRENCY
  - Pre-initializes N execution environments
  - Eliminates cold starts for those N environments
  - Cost: ~$0.015 per GB-hour provisioned
  - Use for latency-sensitive functions
```

```python
# Set reserved concurrency (throttle + guarantee)
aws lambda put-function-concurrency \
    --function-name my-function \
    --reserved-concurrent-executions 50

# Set provisioned concurrency (eliminate cold starts)
aws lambda put-provisioned-concurrency-config \
    --function-name my-function \
    --qualifier PROD \
    --provisioned-concurrent-executions 10
```

### Throttling Behavior

```
When concurrency limit is hit:

Synchronous: returns 429 TooManyRequestsException → client retries
Asynchronous: retries with exponential backoff for 6 hours → DLQ
SQS ESM: messages stay in queue, Lambda retries
Kinesis ESM: iterator blocked, retries until data expires
```

---

## Monitoring & Observability

### Key CloudWatch Metrics

```
Metric                  | What It Tells You
────────────────────────┼───────────────────────────────────────
Invocations             | Total function calls
Errors                  | Failed invocations (exceptions)
Duration                | Execution time (min/avg/max/p99)
Throttles               | Rejected invocations (too many concurrent)
ConcurrentExecutions    | Current parallel instances
IteratorAge             | Kinesis/DynamoDB stream lag (ms)
DeadLetterErrors        | Failed DLQ deliveries
```

### CloudWatch Alarms to Create

```bash
# Error rate alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Lambda-High-Error-Rate" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --dimensions Name=FunctionName,Value=my-function \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions arn:aws:sns:us-east-1:123:alerts

# P99 duration alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "Lambda-High-P99-Duration" \
    --metric-name Duration \
    --namespace AWS/Lambda \
    --extended-statistic p99 \
    --threshold 5000 \
    --comparison-operator GreaterThanThreshold
```

### X-Ray Tracing

```python
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()  # automatically traces boto3, requests, httplib

@xray_recorder.capture('process_order')
def process_order(order):
    with xray_recorder.in_subsegment('validate'):
        validate_order(order)
    with xray_recorder.in_subsegment('save_to_db'):
        save_order(order)

def handler(event, context):
    xray_recorder.put_annotation('orderId', event['orderId'])
    xray_recorder.put_metadata('event', event)
    process_order(event)
```

### Structured Logging

```python
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    # Structured log — searchable in CloudWatch Insights
    logger.info(json.dumps({
        'level': 'INFO',
        'requestId': context.aws_request_id,
        'function': context.function_name,
        'event_type': event.get('detail-type'),
        'order_id': event.get('detail', {}).get('orderId'),
        'message': 'Processing order'
    }))
```

### CloudWatch Logs Insights Queries

```sql
-- Error rate by function
fields @timestamp, @message
| filter @message like /ERROR/
| stats count(*) as errors by bin(5m)

-- Top slowest invocations
fields @timestamp, @duration, @requestId
| sort @duration desc
| limit 20

-- Cold start frequency
fields @timestamp, @initDuration
| filter @initDuration > 0
| stats count(*) as coldStarts by bin(1h)

-- Memory usage vs allocated
fields @timestamp, @maxMemoryUsed, @memorySize
| stats max(@maxMemoryUsed) as maxUsed, 
        avg(@maxMemoryUsed) as avgUsed,
        avg(@memorySize) as allocated
        by bin(1h)
```

---

## Code Examples

### Full Production Lambda Function

```python
import json
import logging
import os
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# Init outside handler — reused across invocations
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])


def handler(event, context):
    request_id = context.aws_request_id
    
    logger.info(json.dumps({
        'requestId': request_id,
        'message': 'Received event',
        'eventType': event.get('httpMethod', 'unknown')
    }))
    
    try:
        # Parse and validate input
        body = json.loads(event.get('body', '{}'))
        if not body.get('orderId'):
            return response(400, {'error': 'orderId is required'})
        
        # Business logic
        result = get_order(body['orderId'])
        
        logger.info(json.dumps({
            'requestId': request_id,
            'message': 'Order retrieved',
            'orderId': body['orderId']
        }))
        
        return response(200, result)
        
    except ClientError as e:
        code = e.response['Error']['Code']
        logger.error(json.dumps({
            'requestId': request_id,
            'message': 'DynamoDB error',
            'errorCode': code,
            'error': str(e)
        }))
        return response(503, {'error': 'Service temporarily unavailable'})
    
    except Exception as e:
        logger.error(json.dumps({
            'requestId': request_id,
            'message': 'Unexpected error',
            'error': str(e)
        }), exc_info=True)
        return response(500, {'error': 'Internal server error'})


def get_order(order_id):
    result = table.get_item(Key={'orderId': order_id})
    if 'Item' not in result:
        raise ValueError(f'Order {order_id} not found')
    return result['Item']


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, default=str)
    }
```

---

## Best Practices

### DO

```
✓ Initialize SDK clients outside the handler (connection reuse)
✓ Use environment variables for configuration
✓ Implement idempotency (safe to run twice)
✓ Use DLQ or Destinations for error handling
✓ Set reserved concurrency to protect downstream services
✓ Use structured JSON logging
✓ Enable X-Ray tracing
✓ Use Layers for shared dependencies
✓ Right-size memory (run Lambda Power Tuning)
✓ Validate all inputs at the handler boundary
✓ Use Secrets Manager for credentials
✓ Tag functions for cost allocation
```

### DON'T

```
✗ Hard-code credentials or secrets
✗ Use global mutable state (thread-safety issues)
✗ Ignore the return value from async calls
✗ Set timeouts too long (idle cost, cascading failures)
✗ Put all logic in one mega-function (violates SRP)
✗ Write to /tmp and expect it to persist across invocations
✗ Use Lambda for long-running batch jobs (use Fargate/Batch)
✗ Poll in a loop inside Lambda (use SQS/EventBridge instead)
✗ Ignore cold starts in latency-sensitive paths
✗ Deploy as root user (use least-privilege IAM)
```

---

*Next: [02-api-gateway.md](02-api-gateway.md)*

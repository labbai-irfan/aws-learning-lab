# 11 — Serverless Troubleshooting Playbook

> Systematic debug approach for every serverless service.

---

## Lambda Troubleshooting

### Error: Function Times Out

```
Symptom: "Task timed out after X.XX seconds"
```

**Investigation:**
```bash
# 1. Check X-Ray trace for slow subsegments
aws xray get-traces --trace-ids <traceId>

# 2. Check CloudWatch Logs for slow operations
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "REPORT" \
    --query "events[].message" \
    | grep "Duration"

# 3. CloudWatch Logs Insights
fields @timestamp, @duration, @billedDuration, @maxMemoryUsed
| filter @duration > 10000
| sort @duration desc
| limit 20
```

**Common Causes & Fixes:**

| Cause | Fix |
|---|---|
| No timeout on HTTP client | Add `timeout=5` to requests.get() |
| DB connection cold start | Initialize connection outside handler |
| Lambda in VPC, no ENI ready | Use VPC Endpoints, increase memory |
| DynamoDB throttling | Check ConsumedCapacity, increase capacity |
| Large payload processing | Process in chunks, increase memory |
| Infinite loop in code | Add loop counter/break condition |

---

### Error: Lambda Out of Memory

```
Symptom: "Runtime exited with error: signal: killed"
         OR: @maxMemoryUsed equals @memorySize
```

**Investigation:**
```sql
-- CloudWatch Logs Insights
fields @timestamp, @maxMemoryUsed, @memorySize
| filter @maxMemoryUsed = @memorySize
| sort @timestamp desc
```

**Fixes:**
- Increase Lambda memory (128MB increments, up to 10GB)
- Stream large files instead of loading into memory
- Process smaller batches
- Use `/tmp` for intermediate data (not heap)
- Check for memory leaks (accumulated data in global scope)

---

### Error: Lambda Throttled

```
Symptom: "Rate exceeded" or 429 ThrottleException
```

**Investigation:**
```bash
# Check concurrent executions
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name ConcurrentExecutions \
    --dimensions Name=FunctionName,Value=my-function \
    --statistics Maximum \
    --period 60 \
    --start-time 2026-06-17T00:00:00Z \
    --end-time 2026-06-17T23:59:00Z

# Check throttles
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Throttles \
    --dimensions Name=FunctionName,Value=my-function \
    --statistics Sum \
    --period 300
```

**Fixes:**
- Request concurrency limit increase via Service Quotas
- Set reserved concurrency appropriately
- Implement exponential backoff in callers
- Use SQS to buffer async invocations

---

### Error: Permission Denied / Access Denied

```
Symptom: "AccessDeniedException" or "is not authorized to perform"
```

**Debug Lambda IAM:**
```bash
# Check what role Lambda is using
aws lambda get-function-configuration --function-name my-function \
    --query "Role"

# Check role policies
ROLE_NAME=$(aws lambda get-function-configuration \
    --function-name my-function \
    --query "Role" --output text | cut -d'/' -f2)

aws iam list-attached-role-policies --role-name $ROLE_NAME
aws iam get-role-policy --role-name $ROLE_NAME --policy-name <name>

# Simulate policy evaluation
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::123:role/my-lambda-role \
    --action-names "dynamodb:PutItem" \
    --resource-arns "arn:aws:dynamodb:us-east-1:123:table/Orders"
```

**Common Missing Permissions:**
```json
{
  "Statement": [
    { "Effect": "Allow", "Action": "logs:*", "Resource": "*" },
    { "Effect": "Allow", "Action": ["xray:PutTraceSegments", "xray:PutTelemetryRecords"], "Resource": "*" },
    { "Effect": "Allow", "Action": "ec2:CreateNetworkInterface", "Resource": "*" }
  ]
}
```

---

### Error: Lambda Cold Start Too Slow

```
Symptom: initDuration > 2000ms in CloudWatch Logs
```

**Investigation:**
```sql
-- Find cold start frequency and duration
fields @timestamp, @initDuration, @duration
| filter @initDuration > 0
| stats 
    count(*) as coldStarts,
    avg(@initDuration) as avgInit,
    max(@initDuration) as maxInit,
    avg(@duration) as avgDuration
  by bin(1h)
```

**Optimization Checklist:**

```
□ Is the deployment package minimal? (< 10MB ideal)
  → Remove unused dependencies
  → Use tree-shaking (webpack/esbuild for Node.js)
  
□ Are heavy imports at top level?
  → Move heavy imports inside handler or lazy-load
  
□ Using Java/.NET? 
  → Enable Lambda SnapStart
  → Or switch to Python/Node.js for cold-start-sensitive functions
  
□ Is provisioned concurrency set?
  → Set for p95 concurrent executions at peak

□ Lambda in VPC?
  → Remove if not needed (adds 100-400ms cold start)
  → If needed: use /64 IPv6 subnet (faster ENI creation)
```

---

### Error: Lambda ENI Limit

```
Symptom: Lambda in VPC fails sporadically with network errors
         "Error: connect ETIMEDOUT"
```

**Cause:** Each Lambda instance in a VPC uses an ENI. Default limit is 250–350 per region.

**Check:**
```bash
# Count ENIs used by Lambda
aws ec2 describe-network-interfaces \
    --filters Name=description,Values="*lambda*" \
    --query 'length(NetworkInterfaces)'
```

**Fix:**
- Request ENI limit increase
- Reduce Lambda concurrency
- Use VPC Endpoints instead of public IP for AWS service calls
- Use Hyperplane ENI (modern Lambda VPC networking — no ENI limit)

---

## API Gateway Troubleshooting

### Error: 502 Bad Gateway

```
Symptom: Client receives 502, no Lambda logs
```

**Causes & Investigation:**
```bash
# 1. Check API Gateway execution logs
# Enable in Stage Settings → CloudWatch Settings → Log Level = INFO

# 2. Check Lambda logs immediately
aws logs tail /aws/lambda/my-function --since 5m --format short

# Common 502 causes:
# a) Lambda returns wrong response format
#    Expected: { statusCode: 200, body: "string", headers: {} }
#    Wrong:    { status: 200, ... }  or  returning dict for body

# b) Lambda exception not handled
#    Step 1: Add try/catch in Lambda
#    Step 2: Return proper error response

# c) Lambda not invokable by API Gateway
#    Check Lambda resource-based policy:
aws lambda get-policy --function-name my-function
```

---

### Error: 403 Forbidden from API Gateway

```
Causes:
  1. Missing Authorization header (Cognito/Lambda Authorizer configured)
  2. Lambda Authorizer returned Deny policy
  3. Resource policy blocking the request (IP, VPC, account)
  4. API key required but not provided
  5. CORS preflight failing (OPTIONS request blocked)
```

**CORS Fix:**
```python
# Lambda must return CORS headers
return {
    'statusCode': 200,
    'headers': {
        'Access-Control-Allow-Origin': 'https://myapp.com',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    },
    'body': json.dumps(result)
}
```

---

### Error: 429 Too Many Requests

```
Causes:
  1. Stage throttling (default 10,000 RPS, 5,000 burst)
  2. Usage plan limit exceeded (API key quota)
  3. Lambda throttling (API Gateway returns 429 to client)
```

```bash
# Check throttle metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name 4XXError \
    --dimensions Name=ApiName,Value=my-api Name=Stage,Value=prod \
    --statistics Sum \
    --period 60
```

---

## SQS Troubleshooting

### Problem: Messages Accumulating in Queue

```
Symptom: ApproximateNumberOfMessagesVisible keeps growing
```

**Investigation Checklist:**
```
□ Is Lambda event source mapping enabled?
  → Check ESM status: aws lambda list-event-source-mappings
  → Check for State=Disabled

□ Is Lambda being throttled?
  → Check Lambda Throttles metric
  → May need to increase concurrency limit

□ Is Lambda erroring on every message?
  → Check CloudWatch Logs for Lambda errors
  → May need to fix the bug

□ Is Lambda processing slower than arrival rate?
  → Increase batch size
  → Increase Lambda memory
  → Add more Lambda concurrency

□ Is the queue a FIFO queue with one stuck message group?
  → One failed message blocks the whole group
  → Check DLQ or fix the stuck message
```

---

### Problem: Messages Going to DLQ Unexpectedly

```
Causes:
  1. Lambda exception (unhandled)
  2. Lambda timeout (message becomes visible, retried until maxReceiveCount)
  3. Message body not valid JSON (Lambda json.loads() fails)
  4. Lambda out of memory
  5. DynamoDB table doesn't exist or wrong name
```

**Debug Lambda on DLQ message:**
```python
# Read DLQ message and test locally
import boto3, json

sqs = boto3.client('sqs')
response = sqs.receive_message(
    QueueUrl='https://sqs.us-east-1.amazonaws.com/123/my-dlq',
    MaxNumberOfMessages=1
)

message = response['Messages'][0]
print(f"Message ID: {message['MessageId']}")
print(f"Receive count: {message['Attributes']['ApproximateReceiveCount']}")
print(f"Body: {message['Body']}")
print(f"Sent time: {message['Attributes']['SentTimestamp']}")
```

---

### Problem: Duplicate Message Processing

```
Causes:
  1. Visibility timeout < Lambda processing time
  2. ReportBatchItemFailures not configured → whole batch retried
  3. SQS Standard (at-least-once) + no idempotency
```

**Fix:**
```bash
# Check visibility timeout
aws sqs get-queue-attributes \
    --queue-url $QUEUE_URL \
    --attribute-names VisibilityTimeout

# Check Lambda function timeout
aws lambda get-function-configuration \
    --function-name my-function \
    --query "Timeout"

# Rule: VisibilityTimeout > Lambda Timeout × 1.5
# If Lambda timeout = 60, set VT to at least 90
aws sqs set-queue-attributes \
    --queue-url $QUEUE_URL \
    --attributes VisibilityTimeout=90
```

---

## EventBridge Troubleshooting

### Problem: Events Not Reaching Target

```
Causes:
  1. Event pattern doesn't match (most common)
  2. Target doesn't have permission
  3. Rule is disabled
  4. Wrong event bus
  5. Target throttled or failed (no DLQ configured)
```

**Test Event Pattern:**
```bash
# Test if a sample event matches your rule
aws events test-event-pattern \
    --event-pattern '{"source": ["com.myapp.orders"], "detail-type": ["OrderPlaced"]}' \
    --event '{
        "source": "com.myapp.orders",
        "detail-type": "OrderPlaced",
        "detail": {"orderId": "123"}
    }'

# Output: {"Result": true}   ← event matches
# Output: {"Result": false}  ← event does NOT match
```

**Check Rule State:**
```bash
# List rules on custom bus
aws events list-rules --event-bus-name orders-bus

# Check specific rule
aws events describe-rule --name my-rule --event-bus-name orders-bus

# Enable disabled rule
aws events enable-rule --name my-rule --event-bus-name orders-bus
```

**Check Target Permissions:**
```bash
# Lambda must have resource-based policy allowing EventBridge
aws lambda get-policy --function-name my-function
# Look for Principal: "events.amazonaws.com"

# Add permission if missing
aws lambda add-permission \
    --function-name my-function \
    --statement-id EventBridgeInvoke \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --source-arn arn:aws:events:us-east-1:123:rule/my-rule
```

**Check DLQ on Target:**
```bash
# Enable DLQ for event delivery failures
aws events put-targets --rule my-rule \
    --targets '[{
        "Id": "target",
        "Arn": "arn:aws:lambda:...:function:my-function",
        "DeadLetterConfig": {
            "Arn": "arn:aws:sqs:us-east-1:123:eventbridge-dlq"
        }
    }]'
```

---

## Step Functions Troubleshooting

### Problem: Execution Failed with States.Runtime

```
Symptom: Error "States.Runtime", Cause "An error occurred while executing..."
```

**Investigation:**
```bash
# Get execution details
aws stepfunctions describe-execution \
    --execution-arn arn:aws:states:...:execution:MyStateMachine:exec-id

# Get execution history
aws stepfunctions get-execution-history \
    --execution-arn arn:aws:states:...:execution:MyStateMachine:exec-id \
    --query "events[?type=='TaskFailed']"
```

**Look for:**
- `LambdaFunctionFailed` — check Lambda CloudWatch Logs
- `LambdaFunctionTimedOut` — increase Lambda timeout or Step Functions task timeout
- `States.Timeout` — step exceeded TimeoutSeconds setting
- `ActivityFailed` — activity worker failed

---

### Problem: Execution Stuck (State Not Progressing)

```
Causes:
  1. WaitForTaskToken — external system never called SendTaskSuccess
  2. Lambda hanging (infinite loop, waiting for external call with no timeout)
  3. Activity worker not polling
```

**Check:**
```bash
# Check current state of execution
aws stepfunctions describe_execution \
    --execution-arn $EXECUTION_ARN \
    --query "status"

# Force execution failure if stuck
aws stepfunctions stop-execution \
    --execution-arn $EXECUTION_ARN \
    --error "ManualStop" \
    --cause "Execution stuck — manual intervention"
```

**For Task Token pattern:**
- Verify Lambda stored the task token correctly
- Verify external system received the task token
- Check heartbeat: if `HeartbeatSeconds` set, call `send_task_heartbeat` to extend timeout
- Check execution history for `TaskStateEntered` to get the task token

---

## Monitoring Dashboard Setup

### Key Metrics to Monitor (CloudWatch Dashboard)

```
Lambda:
  ├── Errors (sum, per function)
  ├── Duration P50/P99 (per function)
  ├── Throttles (sum)
  ├── ConcurrentExecutions (max)
  └── IteratorAge (for Kinesis/DynamoDB Streams)

API Gateway:
  ├── 4XXError rate (%)
  ├── 5XXError rate (%)
  ├── Latency P99
  └── Count (req/min)

SQS:
  ├── ApproximateNumberOfMessagesVisible (main queue)
  ├── ApproximateNumberOfMessagesVisible (DLQ)
  ├── ApproximateAgeOfOldestMessage
  └── NumberOfMessagesSent vs NumberOfMessagesDeleted

EventBridge:
  ├── FailedInvocations (per rule)
  └── MatchedEvents (per rule)

Step Functions:
  ├── ExecutionsFailed
  ├── ExecutionsTimedOut
  └── ExecutionTime
```

### Recommended Alarms

```bash
# Lambda error rate > 1%
aws cloudwatch put-metric-alarm \
    --alarm-name "Lambda-Error-Rate-High" \
    --metrics '[
        {"Id":"errors","MetricStat":{"Metric":{"Namespace":"AWS/Lambda","MetricName":"Errors","Dimensions":[{"Name":"FunctionName","Value":"my-function"}]},"Period":60,"Stat":"Sum"}},
        {"Id":"invocations","MetricStat":{"Metric":{"Namespace":"AWS/Lambda","MetricName":"Invocations","Dimensions":[{"Name":"FunctionName","Value":"my-function"}]},"Period":60,"Stat":"Sum"}}
    ]' \
    --comparison-operator GreaterThanThreshold \
    --threshold 0.01 \
    --expression "errors/invocations"

# DLQ has messages (any = alert)
aws cloudwatch put-metric-alarm \
    --alarm-name "DLQ-Messages-Present" \
    --namespace AWS/SQS \
    --metric-name ApproximateNumberOfMessagesVisible \
    --dimensions Name=QueueName,Value=my-dlq \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --period 60 \
    --evaluation-periods 1 \
    --statistic Sum \
    --alarm-actions arn:aws:sns:us-east-1:123:alerts
```

---

## Quick Debug Commands

```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/my-function --follow --format short

# Get last 100 Lambda error messages
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --filter-pattern "ERROR" \
    --limit 100 \
    --query "events[].message" \
    --output text

# Check SQS queue depth
aws sqs get-queue-attributes \
    --queue-url $QUEUE_URL \
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible

# Peek at SQS message without consuming it
aws sqs receive-message \
    --queue-url $QUEUE_URL \
    --visibility-timeout 0 \
    --max-number-of-messages 1

# Check EventBridge rule targets
aws events list-targets-by-rule \
    --rule my-rule \
    --event-bus-name orders-bus

# List Step Functions executions with status
aws stepfunctions list-executions \
    --state-machine-arn arn:aws:states:...:stateMachine:MyMachine \
    --status-filter FAILED \
    --max-results 10
```

---

## Escalation Decision Tree

```
Event not processed?
│
├── Check: Does event exist in source?
│   └── NO → Publisher bug (not sending event)
│
├── Check: Is rule/trigger enabled?
│   └── NO → Enable rule/trigger
│
├── Check: Does event match filter/pattern?
│   └── NO → Fix pattern or event attributes
│
├── Check: Does target have permission?
│   └── NO → Add resource policy
│
├── Check: Did Lambda receive event?
│   (CloudWatch Logs)
│   └── NO → EventBridge/SNS/SQS delivery failure → check DLQ
│
├── Check: Did Lambda succeed?
│   └── NO → Check Lambda error logs → fix code
│
└── Check: Did downstream (DynamoDB, etc.) succeed?
    └── NO → Check downstream service → IAM, throttling, connectivity
```

---

*Last updated: June 2026 | Phase 10 — Serverless Learning Path*

# Project 03: Serverless Data Pipeline

**Difficulty:** Intermediate  
**Services:** S3 + Lambda + SQS + DynamoDB + EventBridge + Glue

---

## Architecture

```
Data Sources
  │
  ├── CSV Upload     → S3 (raw-data bucket)
  ├── API Events     → S3 (via Kinesis Firehose)
  └── DB Export      → S3 (via RDS snapshot export)
         │
         │ S3 Event Notification (ObjectCreated)
         ▼
      SQS Queue (data-pipeline-queue)
         │
         │ Lambda ESM (batch=10, window=60s)
         ▼
  Lambda: FileProcessor
         │
         ├── Parse & validate
         ├── Transform
         ├── Write to DynamoDB (processed records)
         └── PutEvent to EventBridge
                │
                ├── Rule: CSV processed  → Glue Job trigger
                ├── Rule: Error detected → SNS alert
                └── Rule: All records    → Analytics Lambda
                                                │
                                                └── Aggregate & write to S3 (parquet)
```

---

## Lambda: File Processor

```python
import json
import boto3
import csv
import io
import os
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')
table = dynamodb.Table(os.environ['OUTPUT_TABLE'])

def handler(event, context):
    failed_items = []
    
    for record in event['Records']:
        message_id = record['messageId']
        
        try:
            body = json.loads(record['body'])
            bucket = body['Records'][0]['s3']['bucket']['name']
            key = body['Records'][0]['s3']['object']['key']
            
            result = process_file(bucket, key)
            
            # Publish completion event
            events.put_events(Entries=[{
                'Source': 'com.myapp.pipeline',
                'DetailType': 'FileProcessed',
                'Detail': json.dumps({
                    'bucket': bucket,
                    'key': key,
                    'recordsProcessed': result['count'],
                    'duration': result['duration']
                }),
                'EventBusName': 'pipeline-bus'
            }])
            
        except ValidationError as e:
            # Permanent error — log and skip
            print(f"Validation failed for {message_id}: {e}")
            # Don't add to failed_items → message goes to DLQ after maxReceiveCount
            publish_error_event(str(e), record)
            
        except Exception as e:
            # Transient error — retry
            print(f"Transient error for {message_id}: {e}")
            failed_items.append({'itemIdentifier': message_id})
    
    return {'batchItemFailures': failed_items}


def process_file(bucket, key):
    start = datetime.utcnow()
    
    # Download file
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')
    
    # Parse based on file type
    if key.endswith('.csv'):
        records = parse_csv(content)
    elif key.endswith('.json') or key.endswith('.jsonl'):
        records = parse_jsonl(content)
    else:
        raise ValidationError(f"Unsupported file type: {key}")
    
    # Validate and transform
    processed = []
    errors = []
    
    for i, record in enumerate(records):
        try:
            transformed = transform_record(record)
            processed.append(transformed)
        except Exception as e:
            errors.append({'row': i+1, 'error': str(e), 'data': record})
    
    if errors:
        save_error_report(bucket, key, errors)
    
    # Batch write to DynamoDB
    with table.batch_writer() as batch:
        for record in processed:
            batch.put_item(Item=record)
    
    duration = (datetime.utcnow() - start).total_seconds()
    
    return {
        'count': len(processed),
        'errors': len(errors),
        'duration': duration
    }


def parse_csv(content):
    reader = csv.DictReader(io.StringIO(content))
    return list(reader)


def parse_jsonl(content):
    records = []
    for line in content.strip().split('\n'):
        if line:
            records.append(json.loads(line))
    return records


def transform_record(record):
    # Validate required fields
    required = ['id', 'timestamp', 'value']
    for field in required:
        if field not in record:
            raise ValidationError(f"Missing required field: {field}")
    
    return {
        'recordId': record['id'],
        'timestamp': record['timestamp'],
        'value': float(record['value']),
        'processedAt': datetime.utcnow().isoformat(),
        'source': 'pipeline'
    }


def save_error_report(bucket, key, errors):
    error_key = key.replace('raw/', 'errors/') + '.errors.json'
    s3.put_object(
        Bucket=bucket,
        Key=error_key,
        Body=json.dumps(errors, indent=2),
        ContentType='application/json'
    )


def publish_error_event(error_msg, record):
    events.put_events(Entries=[{
        'Source': 'com.myapp.pipeline',
        'DetailType': 'ProcessingError',
        'Detail': json.dumps({
            'messageId': record['messageId'],
            'error': error_msg
        }),
        'EventBusName': 'pipeline-bus'
    }])


class ValidationError(Exception):
    pass
```

---

## S3 → SQS Event Notification Setup

```bash
# 1. Create SQS queue with policy allowing S3
aws sqs create-queue --queue-name data-pipeline-queue

# Add SQS policy to allow S3 to send messages
aws sqs set-queue-attributes \
    --queue-url $QUEUE_URL \
    --attributes '{
        "Policy": "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [{
                \"Effect\": \"Allow\",
                \"Principal\": {\"Service\": \"s3.amazonaws.com\"},
                \"Action\": \"sqs:SendMessage\",
                \"Resource\": \"arn:aws:sqs:us-east-1:123:data-pipeline-queue\",
                \"Condition\": {
                    \"ArnEquals\": {
                        \"aws:SourceArn\": \"arn:aws:s3:::my-raw-data-bucket\"
                    }
                }
            }]
        }"
    }'

# 2. Configure S3 to notify SQS on object creation
aws s3api put-bucket-notification-configuration \
    --bucket my-raw-data-bucket \
    --notification-configuration '{
        "QueueConfigurations": [{
            "QueueArn": "arn:aws:sqs:us-east-1:123:data-pipeline-queue",
            "Events": ["s3:ObjectCreated:*"],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {"Name": "prefix", "Value": "raw/"},
                        {"Name": "suffix", "Value": ".csv"}
                    ]
                }
            }
        }]
    }'
```

---

## Cost Profile (1GB/day of CSV files)

```
S3 storage: ~$0.02/GB/month = ~$0.60/month
Lambda: ~10,000 invocations × 5s × 1GB = $8.33/month
DynamoDB on-demand: ~$5/month
SQS: ~$0.001/month
EventBridge: ~$0.001/month
Total: ~$14/month

vs Glue ETL job (1 DPU/hour):
  $0.44/DPU-hour × 24h = $10.56/day = $316/month
  Serverless is 20x cheaper at this scale
```

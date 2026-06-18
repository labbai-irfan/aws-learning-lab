# 02 — API Gateway: REST, HTTP & WebSocket APIs

---

## Table of Contents
1. [API Types Comparison](#api-types-comparison)
2. [REST API Deep Dive](#rest-api-deep-dive)
3. [HTTP API](#http-api)
4. [WebSocket API](#websocket-api)
5. [Authorizers](#authorizers)
6. [Request/Response Mapping](#requestresponse-mapping)
7. [Throttling & Quotas](#throttling--quotas)
8. [Caching](#caching)
9. [Custom Domains](#custom-domains)
10. [Integration Types](#integration-types)
11. [Code Examples](#code-examples)

---

## API Types Comparison

```
Feature                    | REST API      | HTTP API    | WebSocket API
───────────────────────────┼───────────────┼─────────────┼───────────────
Price (per 1M calls)       | $3.50         | $1.00       | $1.00 + msgs
Latency                    | ~10ms         | ~6ms        | persistent
Lambda Proxy Integration   | YES           | YES         | YES
AWS Service Integration    | YES           | Limited     | YES
Request Validation         | YES           | No          | No
Request Transformation     | YES (VTL)     | No          | No
Response Transformation    | YES (VTL)     | No          | No
API Keys / Usage Plans     | YES           | No          | No
AWS WAF                    | YES           | No          | No
Edge Optimized             | YES           | No          | No
Private API                | YES           | No          | No
Caching                    | YES           | No          | No
Cognito Authorizer         | YES           | YES (JWT)   | YES
Lambda Authorizer          | YES           | YES         | YES
IAM Auth                   | YES           | YES         | YES
mTLS                       | YES           | YES         | No
Custom Domains             | YES           | YES         | YES
VPC Link                   | YES           | YES         | No
WebSocket routes           | No            | No          | YES
───────────────────────────┴───────────────┴─────────────┴───────────────
Best for:                  | Full control  | Most APIs   | Real-time
```

**Decision Rule:**
- Default to **HTTP API** — it's 71% cheaper and covers 90% of use cases
- Use **REST API** when you need: WAF, caching, API keys, VTL transformations, private API
- Use **WebSocket** for: chat, live dashboards, real-time collaboration

---

## REST API Deep Dive

### Architecture

```
Client
  │
  ▼
CloudFront (Edge Optimized) or Regional Endpoint
  │
  ▼
API Gateway (Stage: /prod)
  │
  ├─ /orders          GET  → Lambda: list-orders
  │                   POST → Lambda: create-order
  │
  ├─ /orders/{id}     GET    → Lambda: get-order
  │                   PUT    → Lambda: update-order
  │                   DELETE → Lambda: delete-order
  │
  └─ /health          GET → Mock Integration: {"status":"ok"}
```

### Resource Policy (IP Allowlist)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:us-east-1:123:abc123/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ["203.0.113.0/24", "198.51.100.5/32"]
        }
      }
    }
  ]
}
```

### Stage Variables

```
Stage variables are key-value pairs in each stage (dev/prod)

Example: use stage variable to point to different Lambda aliases
  stageVariable: lambdaAlias = "PROD"

Integration URI:
  arn:aws:apigateway:us-east-1:lambda:path/functions/
  arn:aws:lambda:us-east-1:123:function:my-func:${stageVariables.lambdaAlias}/invocations

Stage: dev  → lambdaAlias = "DEV"   → hits Lambda:DEV alias
Stage: prod → lambdaAlias = "PROD"  → hits Lambda:PROD alias
```

### Request Validation

```json
{
  "openapi": "3.0.1",
  "paths": {
    "/orders": {
      "post": {
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["customerId", "items"],
                "properties": {
                  "customerId": { "type": "string" },
                  "items": {
                    "type": "array",
                    "minItems": 1,
                    "items": {
                      "type": "object",
                      "required": ["productId", "quantity"],
                      "properties": {
                        "productId": { "type": "string" },
                        "quantity": { "type": "integer", "minimum": 1 }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

API Gateway rejects invalid requests with 400 before Lambda is invoked — saves Lambda cost and protects your function.

---

## HTTP API

### When to Use

HTTP API is the modern default. Use it for:
- Public REST APIs backed by Lambda
- JWT/OIDC authentication (Cognito, Auth0, Okta)
- CORS handling
- Private integrations (VPC Link to ALB, ECS, etc.)

### HTTP API Configuration (SAM)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: python3.12
    MemorySize: 512
    Timeout: 30

Resources:
  OrdersApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: prod
      CorsConfiguration:
        AllowOrigins:
          - "https://myapp.com"
        AllowMethods:
          - GET
          - POST
          - PUT
          - DELETE
        AllowHeaders:
          - Content-Type
          - Authorization
        MaxAge: 600
      Auth:
        Authorizers:
          CognitoAuth:
            IdentitySource: $request.header.Authorization
            JwtConfiguration:
              Audience:
                - !Ref UserPoolClient
              Issuer: !Sub "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPool}"
        DefaultAuthorizer: CognitoAuth

  ListOrdersFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: orders.list_handler
      CodeUri: src/
      Events:
        ListOrders:
          Type: HttpApi
          Properties:
            ApiId: !Ref OrdersApi
            Method: GET
            Path: /orders
            Auth:
              Authorizer: CognitoAuth

  CreateOrderFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: orders.create_handler
      CodeUri: src/
      Events:
        CreateOrder:
          Type: HttpApi
          Properties:
            ApiId: !Ref OrdersApi
            Method: POST
            Path: /orders
```

### JWT Claims in Lambda

```python
def handler(event, context):
    # HTTP API passes JWT claims in requestContext
    claims = event['requestContext']['authorizer']['jwt']['claims']
    user_id = claims['sub']            # Cognito user ID
    email = claims['email']
    groups = claims.get('cognito:groups', [])
    
    if 'admin' not in groups:
        return response(403, {'error': 'Insufficient permissions'})
    
    # ... proceed with authorized request
```

---

## WebSocket API

### Use Cases
- Real-time chat applications
- Live sports scores / stock tickers
- Multiplayer game state
- Collaborative document editing
- Live customer support

### Connection Lifecycle

```
Client connects:   → $connect route → Lambda (save connectionId to DynamoDB)
Client sends msg:  → $default route → Lambda (broadcast to other clients)
Client disconnects → $disconnect route → Lambda (remove from DynamoDB)

API GW assigns each connection a unique connectionId
Lambda can push to any connectionId via Management API
```

### WebSocket Backend Lambda

```python
import json
import boto3
import os
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def handler(event, context):
    route_key = event['requestContext']['routeKey']
    connection_id = event['requestContext']['connectionId']
    domain = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    
    api_gw = boto3.client('apigatewaymanagementapi',
        endpoint_url=f"https://{domain}/{stage}")
    
    if route_key == '$connect':
        return handle_connect(connection_id, event)
    elif route_key == '$disconnect':
        return handle_disconnect(connection_id)
    elif route_key == '$default':
        return handle_message(connection_id, event, api_gw)


def handle_connect(connection_id, event):
    # Save connection (optionally extract user from query params)
    user_id = event.get('queryStringParameters', {}).get('userId', 'anonymous')
    table.put_item(Item={
        'connectionId': connection_id,
        'userId': user_id,
        'ttl': int(time.time()) + 7200  # 2 hour TTL
    })
    return {'statusCode': 200}


def handle_disconnect(connection_id):
    table.delete_item(Key={'connectionId': connection_id})
    return {'statusCode': 200}


def handle_message(connection_id, event, api_gw):
    body = json.loads(event.get('body', '{}'))
    message = body.get('message', '')
    
    # Broadcast to all connected clients
    connections = table.scan()['Items']
    
    for conn in connections:
        try:
            api_gw.post_to_connection(
                ConnectionId=conn['connectionId'],
                Data=json.dumps({
                    'from': connection_id,
                    'message': message
                })
            )
        except api_gw.exceptions.GoneException:
            # Client disconnected without clean disconnect
            table.delete_item(Key={'connectionId': conn['connectionId']})
    
    return {'statusCode': 200}
```

---

## Authorizers

### 1. IAM Authorization (SigV4)

```
Best for: service-to-service, AWS CLI/SDK calls
Client signs request with AWS credentials
API GW validates signature
```

```python
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

def call_private_api(url, payload):
    session = boto3.Session()
    credentials = session.get_credentials()
    
    request = AWSRequest(method='POST', url=url, data=json.dumps(payload))
    SigV4Auth(credentials, 'execute-api', 'us-east-1').add_auth(request)
    
    return requests.post(url, 
        data=json.dumps(payload),
        headers=dict(request.headers))
```

### 2. Lambda Authorizer (Token or Request)

```python
# Token-based Lambda Authorizer
# Receives: Authorization header
# Returns: IAM policy (Allow/Deny)

import jwt  # PyJWT

def handler(event, context):
    token = event['authorizationToken'].replace('Bearer ', '')
    
    try:
        # Validate JWT
        payload = jwt.decode(token, 
            key=get_public_key(),
            algorithms=['RS256'],
            audience='my-api')
        
        return build_policy(
            principal_id=payload['sub'],
            effect='Allow',
            resource=event['methodArn'],
            context={
                'userId': payload['sub'],
                'email': payload.get('email'),
                'role': payload.get('custom:role', 'user')
            }
        )
    
    except jwt.ExpiredSignatureError:
        raise Exception('Unauthorized')  # 401
    except jwt.InvalidTokenError:
        raise Exception('Unauthorized')


def build_policy(principal_id, effect, resource, context=None):
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
    }
    if context:
        policy['context'] = context
    return policy
```

### 3. Cognito Authorizer (JWT)

```
REST API: Built-in Cognito User Pool Authorizer
HTTP API: JWT Authorizer configured with Cognito issuer URL

REST API flow:
  Client → API GW → Cognito validates token → Lambda
  
HTTP API flow:
  Client → API GW → validates JWT locally (no Cognito call) → Lambda
  HTTP API JWT is faster (no external call) but less flexible
```

### Authorizer Caching

```
Default TTL: 300 seconds (5 minutes)
Range: 0 (disabled) – 3600 seconds

With caching: authorizer Lambda called once, result cached per token
Without caching: authorizer called on every request

Cache key: Authorization header value (token-based)
           Full request (request-based authorizer)

Cost impact: caching reduces Lambda invocations = lower cost
```

---

## Request/Response Mapping

REST API uses **Velocity Template Language (VTL)** to transform requests/responses.

### Integration Request Mapping

```velocity
## Map API Gateway event to backend format
#set($inputRoot = $input.path('$'))
{
  "operation": "create_order",
  "payload": {
    "customerId": "$inputRoot.customerId",
    "items": $input.json('$.items'),
    "requestId": "$context.requestId",
    "userId": "$context.authorizer.userId"
  }
}
```

### Integration Response Mapping

```velocity
## Map backend response to API response
#set($result = $input.path('$.body'))
#if($result.error)
  #set($context.responseOverride.status = 400)
  {
    "error": "$result.error",
    "requestId": "$context.requestId"
  }
#else
  {
    "orderId": "$result.orderId",
    "status": "$result.status"
  }
#end
```

### HTTP API: No Transformation
HTTP API uses **lambda proxy integration only** — the raw event goes to Lambda and the raw response comes back. Transform in your Lambda code instead.

---

## Throttling & Quotas

### Throttling Hierarchy

```
Account Level (us-east-1): 10,000 RPS, 5,000 burst
     │
     └─ API Stage Level: set per-stage limits
            │
            └─ Method Level: set per-method limits
                   │
                   └─ Usage Plan: per API key limit
```

### Setting Throttling

```python
# Via AWS CLI
aws apigateway update-stage \
    --rest-api-id abc123 \
    --stage-name prod \
    --patch-operations \
        op=replace,path=/defaultRouteSettings/throttlingBurstLimit,value=1000 \
        op=replace,path=/defaultRouteSettings/throttlingRateLimit,value=500

# Per-method throttling
aws apigateway update-stage \
    --rest-api-id abc123 \
    --stage-name prod \
    --patch-operations \
        "op=replace,path=/~1orders/POST/throttling/rateLimit,value=100"
```

### Usage Plans & API Keys

```
API Keys → group under Usage Plans
Usage Plans define:
  - Throttle: requests per second
  - Burst: token bucket size
  - Quota: requests per day/week/month

Use case: monetize API, rate-limit partners, tier-based access
```

---

## Caching

Available on REST API only.

```
Cache key: method + path + (optionally query params, headers)
Cache TTL: 300s default, 0-3600s range
Cache size: 0.5GB, 1.6GB, 6.1GB, 13.5GB, 28.4GB, 58.2GB, 118GB, 237GB

Approximate cost:
  0.5GB: ~$14/month
  6.1GB: ~$46/month

When to use caching:
  - GET endpoints with expensive Lambda/DB lookups
  - Data that changes infrequently (< TTL frequency)
  - High traffic endpoints (amortize cache cost)

Cache invalidation:
  - Header: Cache-Control: max-age=0  (per-request bypass)
  - CloudFormation/CLI to flush entire cache
  - TTL expiry
```

---

## Custom Domains

```bash
# 1. Request ACM certificate (must be in us-east-1 for edge-optimized)
aws acm request-certificate \
    --domain-name api.myapp.com \
    --validation-method DNS \
    --region us-east-1

# 2. Create custom domain in API Gateway
aws apigateway create-domain-name \
    --domain-name api.myapp.com \
    --endpoint-configuration types=REGIONAL \
    --regional-certificate-arn arn:aws:acm:us-east-1:123:certificate/abc

# 3. Create base path mapping
aws apigateway create-base-path-mapping \
    --domain-name api.myapp.com \
    --rest-api-id xyz789 \
    --stage prod \
    --base-path v1

# 4. Add CNAME in Route 53
# api.myapp.com → xyz789.execute-api.us-east-1.amazonaws.com
```

---

## Integration Types

| Type | Use Case |
|---|---|
| **Lambda Proxy** | Lambda function — full event object passed |
| **Lambda** | Lambda with VTL request/response mapping |
| **HTTP Proxy** | Forward to HTTP endpoint as-is |
| **HTTP** | Forward to HTTP with VTL transformation |
| **AWS** | Invoke AWS services directly (SQS, DynamoDB, etc.) |
| **Mock** | Return static response without backend |

### Direct DynamoDB Integration (no Lambda)

```json
{
  "type": "AWS",
  "httpMethod": "POST",
  "uri": "arn:aws:apigateway:us-east-1:dynamodb:action/GetItem",
  "requestTemplates": {
    "application/json": {
      "TableName": "Orders",
      "Key": {
        "orderId": { "S": "$input.params('orderId')" }
      }
    }
  }
}
```

---

## Code Examples

### Lambda Handler for API Gateway Events

```python
import json

def handler(event, context):
    """Handles both REST API and HTTP API events."""
    
    # HTTP method
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method')
    
    # Path parameters
    path_params = event.get('pathParameters') or {}
    
    # Query parameters
    query_params = event.get('queryStringParameters') or {}
    
    # Body (API GW sends body as string)
    raw_body = event.get('body', '{}') or '{}'
    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return error_response(400, 'Invalid JSON body')
    
    # Headers (case-insensitive in HTTP API)
    headers = event.get('headers') or {}
    
    # Auth context (Lambda Authorizer or Cognito)
    authorizer = event.get('requestContext', {}).get('authorizer', {})
    user_id = authorizer.get('userId') or authorizer.get('jwt', {}).get('claims', {}).get('sub')
    
    # Route to handler
    if method == 'GET' and path_params.get('id'):
        return get_order(path_params['id'], user_id)
    elif method == 'POST':
        return create_order(body, user_id)
    else:
        return error_response(405, 'Method not allowed')


def get_order(order_id, user_id):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'orderId': order_id, 'userId': user_id})
    }

def create_order(body, user_id):
    return {
        'statusCode': 201,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'message': 'Order created', 'userId': user_id})
    }

def error_response(status_code, message):
    return {
        'statusCode': status_code,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'error': message})
    }
```

---

*Next: [03-eventbridge.md](03-eventbridge.md)*

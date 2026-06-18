# Project 02: Real-Time Notification System

**Difficulty:** Intermediate  
**Services:** API Gateway WebSocket + Lambda + DynamoDB + SNS

---

## Architecture

```
Mobile/Web Client
  │
  ├── WebSocket connect → API GW WS → Lambda ($connect) → DynamoDB
  │                                                       (save connectionId)
  │
  ├── Send message     → API GW WS → Lambda ($default)  → Broadcast to all
  │
  └── Disconnect       → API GW WS → Lambda ($disconnect) → DynamoDB
                                                           (remove connectionId)

External Events (SNS Topic)
  │
  └── Lambda (push to WS clients)
            │ Get all connectionIds from DynamoDB
            └── API GW Management API → each client
```

---

## Lambda: Connection Manager

```python
import boto3
import json
import os
import time

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['CONNECTIONS_TABLE'])

def handler(event, context):
    route = event['requestContext']['routeKey']
    connection_id = event['requestContext']['connectionId']
    domain = event['requestContext']['domainName']
    stage = event['requestContext']['stage']
    
    if route == '$connect':
        return on_connect(event, connection_id)
    elif route == '$disconnect':
        return on_disconnect(connection_id)
    elif route == '$default':
        return on_message(event, connection_id, domain, stage)
    
    return {'statusCode': 400, 'body': 'Unknown route'}


def on_connect(event, connection_id):
    query = event.get('queryStringParameters') or {}
    user_id = query.get('userId', 'anonymous')
    channel = query.get('channel', 'general')
    
    table.put_item(Item={
        'connectionId': connection_id,
        'userId': user_id,
        'channel': channel,
        'connectedAt': int(time.time()),
        'ttl': int(time.time()) + 7200  # 2-hour TTL
    })
    
    return {'statusCode': 200, 'body': 'Connected'}


def on_disconnect(connection_id):
    table.delete_item(Key={'connectionId': connection_id})
    return {'statusCode': 200, 'body': 'Disconnected'}


def on_message(event, connection_id, domain, stage):
    body = json.loads(event.get('body', '{}'))
    message_type = body.get('type')
    
    if message_type == 'ping':
        send_message(connection_id, domain, stage, {'type': 'pong'})
    elif message_type == 'subscribe':
        subscribe_to_channel(connection_id, body.get('channel'))
    elif message_type == 'message':
        broadcast_to_channel(body.get('channel'), body.get('data'), domain, stage)
    
    return {'statusCode': 200, 'body': 'Message processed'}


def send_message(connection_id, domain, stage, data):
    api_gw = boto3.client('apigatewaymanagementapi',
        endpoint_url=f"https://{domain}/{stage}")
    
    try:
        api_gw.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(data).encode()
        )
    except api_gw.exceptions.GoneException:
        # Stale connection — remove
        table.delete_item(Key={'connectionId': connection_id})


def broadcast_to_channel(channel, data, domain, stage):
    # Get all connections subscribed to this channel
    response = table.query(
        IndexName='channel-index',
        KeyConditionExpression='channel = :ch',
        ExpressionAttributeValues={':ch': channel}
    )
    
    for item in response['Items']:
        send_message(item['connectionId'], domain, stage, {
            'type': 'message',
            'channel': channel,
            'data': data
        })
```

---

## Lambda: SNS-triggered Push (External Events)

```python
def handler(event, context):
    """Triggered by SNS → pushes notification to all WebSocket clients."""
    
    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])
        attributes = record['Sns'].get('MessageAttributes', {})
        
        user_id = attributes.get('userId', {}).get('Value')
        channel = attributes.get('channel', {}).get('Value', 'general')
        
        notification = {
            'type': 'notification',
            'title': message.get('title'),
            'body': message.get('body'),
            'data': message.get('data')
        }
        
        if user_id:
            # Push to specific user's connections
            push_to_user(user_id, notification)
        else:
            # Broadcast to channel
            push_to_channel(channel, notification)


def push_to_user(user_id, notification):
    # Query GSI by userId
    response = table.query(
        IndexName='userId-index',
        KeyConditionExpression='userId = :uid',
        ExpressionAttributeValues={':uid': user_id}
    )
    
    for item in response['Items']:
        send_message(item['connectionId'], 
                     os.environ['WS_DOMAIN'],
                     os.environ['WS_STAGE'], 
                     notification)
```

---

## Client-Side JavaScript

```javascript
class RealtimeClient {
    constructor(wsUrl) {
        this.wsUrl = wsUrl;
        this.ws = null;
        this.reconnectAttempts = 0;
        this.maxReconnects = 5;
    }

    connect(userId, channel = 'general') {
        const url = `${this.wsUrl}?userId=${userId}&channel=${channel}`;
        this.ws = new WebSocket(url);
        
        this.ws.onopen = () => {
            console.log('Connected to WebSocket');
            this.reconnectAttempts = 0;
            this.startHeartbeat();
        };
        
        this.ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.handleMessage(data);
        };
        
        this.ws.onclose = (event) => {
            console.log('WebSocket closed:', event.code);
            this.stopHeartbeat();
            if (this.reconnectAttempts < this.maxReconnects) {
                const delay = Math.pow(2, this.reconnectAttempts) * 1000;
                setTimeout(() => {
                    this.reconnectAttempts++;
                    this.connect(userId, channel);
                }, delay);
            }
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }

    handleMessage(data) {
        switch (data.type) {
            case 'notification':
                this.showNotification(data.title, data.body);
                break;
            case 'message':
                this.displayMessage(data.channel, data.data);
                break;
            case 'pong':
                console.log('Heartbeat OK');
                break;
        }
    }

    startHeartbeat() {
        this.heartbeatInterval = setInterval(() => {
            if (this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify({ type: 'ping' }));
            }
        }, 30000); // every 30 seconds
    }

    stopHeartbeat() {
        clearInterval(this.heartbeatInterval);
    }

    sendMessage(channel, data) {
        this.ws.send(JSON.stringify({ type: 'message', channel, data }));
    }

    showNotification(title, body) {
        if (Notification.permission === 'granted') {
            new Notification(title, { body });
        }
    }
}

// Usage
const client = new RealtimeClient('wss://abc123.execute-api.us-east-1.amazonaws.com/prod');
client.connect('user-456', 'orders');
```

---

## DynamoDB Table Design

```
Table: WebSocketConnections
PK: connectionId (String)

GSI-1: userId-index
  PK: userId (String)
  
GSI-2: channel-index
  PK: channel (String)

Attributes:
  connectionId, userId, channel, connectedAt, ttl

TTL: Set to 2 hours from connection time
     (auto-cleanup stale connections)
```

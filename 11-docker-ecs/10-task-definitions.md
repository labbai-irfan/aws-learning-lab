# Module 10 — Task Definitions

> The task definition is the **blueprint** ECS uses to run containers: which image(s), how much CPU/RAM, ports, env vars, secrets, logging, volumes, health checks, and IAM roles. It's versioned (revisions) and immutable. This module dissects every field that matters.

---

## 1. What a Task Definition Is

Think of it as a `docker run` (or `docker-compose` service) expressed as JSON that ECS can schedule anywhere. It is **immutable and versioned**: every change creates a new **revision** (`hrms-auth:1`, `:2`, `:3`). Services point at a revision; deploying = pointing at a newer one.

```
   Task Definition  "hrms-auth"
   ├── revision 1  (image :1.4.0, 0.25 vCPU)
   ├── revision 2  (image :1.4.1)
   └── revision 3  (image :1.4.2, 0.5 vCPU)   ◄── service runs this
```

A task definition can contain **multiple containers** that are always scheduled **together** on the same host/microVM (app + sidecar like X-Ray or a log router). One service-per-container is the common case; co-locate only tightly-coupled helpers.

---

## 2. Anatomy (annotated)

```json
{
  "family": "hrms-auth",                     // the name; revisions group under it
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",                    // required for Fargate
  "cpu": "512",                               // TASK-level: 0.5 vCPU
  "memory": "1024",                           // TASK-level: 1 GB
  "runtimePlatform": { "cpuArchitecture": "X86_64", "operatingSystemFamily": "LINUX" },
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn":      "arn:aws:iam::123456789012:role/hrmsAuthTaskRole",
  "containerDefinitions": [
    {
      "name": "auth",
      "image": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/hrms-auth:1.4.2",
      "essential": true,                      // if it dies, the whole task stops
      "portMappings": [
        { "containerPort": 5000, "protocol": "tcp" }
      ],
      "environment": [
        { "name": "NODE_ENV", "value": "production" },
        { "name": "DB_HOST",  "value": "hrms-db.xxxx.ap-south-1.rds.amazonaws.com" }
      ],
      "secrets": [
        { "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-south-1:123456789012:secret:hrms/db-AbCdEf" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hrms-auth",
          "awslogs-region": "ap-south-1",
          "awslogs-stream-prefix": "auth"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"],
        "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 30
      }
    }
  ]
}
```

---

## 3. The Fields That Bite You

| Field | Why it matters | Common mistake |
|---|---|---|
| `cpu` / `memory` (task) | Must be a **valid Fargate combo** ([Module 8 §2](08-fargate.md)) | Invalid combo → registration fails |
| `essential` | An essential container's exit stops the whole task | Sidecar marked essential kills the app |
| `portMappings.containerPort` | Must match the port your app listens on **and** the ALB target group port | Mismatch → unhealthy targets, 502 |
| `executionRoleArn` | Lets **ECS** pull image + write logs | Missing → `CannotPullContainerError` |
| `taskRoleArn` | Lets **your app** call AWS (S3, Secrets) | Confused with execution role → `AccessDenied` at runtime |
| `secrets` vs `environment` | Secrets injected from Secrets Manager/SSM; env is plaintext in the def | Putting passwords in `environment` 🔒 |
| `logConfiguration` | No log config → you're blind | Forgetting the log group exists |

💡 **Two roles, one sentence:** *Execution role = ECS's permissions to set the task up. Task role = your code's permissions while running.*

---

## 4. Environment vs Secrets

```jsonc
// ❌ plaintext — visible to anyone who can read the task definition
"environment": [ { "name": "DB_PASSWORD", "value": "hunter2" } ]

// ✅ injected at runtime from Secrets Manager / SSM Parameter Store
"secrets": [
  { "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:...:secret:hrms/db-AbCdEf:password::" }
]
```
🔒 Use `secrets` for anything sensitive. The execution role needs `secretsmanager:GetSecretValue` (or `ssm:GetParameters` + `kms:Decrypt`) on those ARNs. ECS injects them as env vars the app reads normally — your code doesn't change.

---

## 5. Logging to CloudWatch

The `awslogs` driver streams stdout/stderr to CloudWatch Logs. Create the log group first (or enable auto-create):

```bash
aws logs create-log-group --log-group-name /ecs/hrms-auth
aws logs put-retention-policy --log-group-name /ecs/hrms-auth --retention-in-days 30
```
Then read logs: CloudWatch → Log groups → `/ecs/hrms-auth` → stream `auth/<task-id>`. Or use **FireLens** (Fluent Bit sidecar) to route logs elsewhere.

---

## 6. Volumes & Health Checks

**EFS volume** (shared persistent storage — [Module 4](04-volumes.md)):
```json
"volumes": [
  { "name": "uploads",
    "efsVolumeConfiguration": {
      "fileSystemId": "fs-0abc123", "transitEncryption": "ENABLED",
      "authorizationConfig": { "accessPointId": "fsap-0def456", "iam": "ENABLED" } } }
],
"containerDefinitions": [
  { "name": "employee", "mountPoints": [ { "sourceVolume": "uploads", "containerPath": "/app/uploads" } ], ... }
]
```

**Health check** lets ECS know a container is actually serving (separate from the ALB health check). `startPeriod` gives slow apps grace before failures count. ⚠️ Set it generous enough for cold starts or ECS will kill-loop a healthy-but-slow app.

---

## 7. Register, List, Update

```bash
# register a new revision from a JSON file
aws ecs register-task-definition --cli-input-json file://hrms-auth.taskdef.json

# list revisions of a family
aws ecs list-task-definitions --family-prefix hrms-auth

# describe a specific revision
aws ecs describe-task-definition --task-definition hrms-auth:3

# deregister an old revision (cleanup)
aws ecs deregister-task-definition --task-definition hrms-auth:1
```

**Deploy flow:** build new image → push to ECR (new tag) → register a new task-def revision pointing at that tag → update the service to the new revision (Module 11). The revision is your immutable, rollback-able artifact.

---

## 8. Multi-Container (sidecar) Example Shape

```
   Task "hrms-employee"
   ├── container: employee  (essential, :5000, your app)
   └── container: xray-daemon (sidecar, :2000/udp, traces)  ← shares localhost & task ENI
```
The app talks to the sidecar over `127.0.0.1` (same task = same network namespace, [Module 5 §6](05-networks.md)).

---

## ✅ Module 10 Checklist
```
[ ] Can read every key field in a task definition
[ ] Know execution role vs task role cold
[ ] Use secrets (not environment) for credentials
[ ] containerPort matches the app and the ALB target group
[ ] awslogs configured + log group exists with retention
[ ] Understand revisions are immutable + how a deploy bumps them
```

➡️ Next: [11-services.md](11-services.md) — keeping tasks running and scaling them.

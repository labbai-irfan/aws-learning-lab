# Module 11 — Services

> A Service keeps a desired number of tasks running, registers them with a load balancer, replaces failures, rolls out new versions safely, and autoscales on demand. This is what turns a task definition into a always-on, scalable API.

---

## 1. What a Service Does

```
   Service "hrms-auth-svc"  (desired count = 3)
        │  scheduler watches running vs desired
        ├── task A ─┐
        ├── task B ─┼─ registered in ALB target group ◄── traffic
        └── task C ─┘
        │
        │  task B dies → ECS launches a replacement to restore "3"
        │  new task-def revision → rolling deployment
        │  CPU high → Application Auto Scaling adds task D, E...
```

Responsibilities:
- **Maintain desired count** (self-healing — replaces unhealthy/stopped tasks).
- **Load balancing** — register/deregister tasks with an ALB **target group**.
- **Deployments** — rolling (default) or blue/green (CodeDeploy), with health gates and rollback.
- **Autoscaling** — add/remove tasks on metrics.
- **Placement** — spread tasks across AZs for HA.

---

## 2. Create a Service (Fargate, behind an ALB)

```bash
aws ecs create-service \
  --cluster hrms \
  --service-name hrms-auth-svc \
  --task-definition hrms-auth:3 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-priv-a,subnet-priv-b],securityGroups=[sg-auth],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...:targetgroup/hrms-auth-tg/abc,containerName=auth,containerPort=5000" \
  --health-check-grace-period-seconds 60 \
  --deployment-configuration "minimumHealthyPercent=100,maximumPercent=200"
```

Key inputs:
- **`--desired-count`** — how many tasks to keep running.
- **`--load-balancers`** — wires tasks into a target group; `containerName`+`containerPort` must match the task def ([Module 10 §3](10-task-definitions.md)).
- **`--health-check-grace-period-seconds`** — ignore ALB health checks during slow startup (else ECS kills booting tasks). ⚠️ A too-short grace period is a top cause of deploy kill-loops.
- **subnets/SG** — the `awsvpc` placement and firewall.

---

## 3. The ALB Connection

The ALB ([Phase 07](../07-elb-autoscaling/README.md)) routes by path/host to **target groups**; the service keeps each target group populated with healthy tasks.

```
   Internet ─► ALB :443 ─┬─ path /api/auth/* ─► auth-tg  ◄─ hrms-auth-svc tasks
                          ├─ path /api/emp/*  ─► emp-tg   ◄─ hrms-employee-svc tasks
                          └─ path /          ─► fe-tg    ◄─ hrms-frontend-svc tasks
```
- **Target type must be `ip`** for Fargate (each task is an IP/ENI), not `instance`.
- The target group **health check** path (e.g. `/health`) must return 200, or tasks are drained and you get 502s.
- **Deregistration delay** (connection draining, default 300s) lets in-flight requests finish on scale-in/deploy — pair with SIGTERM handling ([Module 3 §5](03-containers.md)).

---

## 4. Deployments — Rolling (default)

ECS replaces tasks gradually, controlled by two knobs:

| Setting | Meaning |
|---|---|
| `minimumHealthyPercent` | Lowest % of desired kept running **during** deploy (100 = never drop below capacity) |
| `maximumPercent` | Highest % allowed (200 = can double up while rolling) |

```
 desired=2, min=100%, max=200%:
   start 2 old ─► launch 2 new (now 4) ─► new healthy in ALB ─► drain+stop 2 old ─► 2 new
```
ECS uses **deployment circuit breaker** to auto-rollback if new tasks fail to stabilize:
```bash
--deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},minimumHealthyPercent=100,maximumPercent=200"
```

**Blue/Green** (via CodeDeploy) spins up a parallel "green" task set, shifts ALB traffic (all-at-once / canary / linear), and can roll back instantly by shifting traffic back — zero in-place risk, at the cost of more setup.

---

## 5. Updating a Service

```bash
# deploy a new image: bump task-def revision
aws ecs update-service --cluster hrms --service hrms-auth-svc \
  --task-definition hrms-auth:4

# change capacity
aws ecs update-service --cluster hrms --service hrms-auth-svc --desired-count 4

# force a fresh deployment (e.g. re-pull :latest — avoid in prod) 
aws ecs update-service --cluster hrms --service hrms-auth-svc --force-new-deployment

# watch it roll out
aws ecs describe-services --cluster hrms --services hrms-auth-svc \
  --query 'services[0].deployments'
```

---

## 6. Application Auto Scaling

Scale tasks automatically. Register the service as a scalable target, then attach a policy.

```bash
# 1) register scalable target (min 2, max 10 tasks)
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/hrms/hrms-auth-svc \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 --max-capacity 10

# 2) target-tracking policy: keep avg CPU at 60%
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/hrms/hrms-auth-svc \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu60 --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 60.0,
    "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"},
    "ScaleInCooldown": 120, "ScaleOutCooldown": 60 }'
```

| Policy type | Use |
|---|---|
| **Target tracking** | "Keep CPU/memory/requests-per-target at X" — easiest, default choice |
| **Step scaling** | Different sized steps per alarm threshold |
| **Scheduled** | Predictable peaks (scale up before business hours) |

💡 `ALBRequestCountPerTarget` is often a better signal than CPU for web APIs — scales on actual traffic.

---

## 7. Service Discovery (service-to-service)

For internal calls (auth → employee) without an ALB, use **ECS Service Connect** or **Cloud Map**: services register DNS names like `employee.hrms.local` resolvable inside the VPC ([Module 6 §3](06-container-architecture.md)).

```
   auth task ──► http://employee.hrms.local:5000  (Cloud Map DNS) ──► employee tasks
```

---

## 8. Observe & Debug a Service

```bash
aws ecs describe-services --cluster hrms --services hrms-auth-svc   # events, deployments
aws ecs list-tasks --cluster hrms --service-name hrms-auth-svc
# the "events" array explains WHY tasks aren't starting (no capacity, can't pull, unhealthy)
```
The **service events** stream is the first place to look when "desired=3 but running=0" (Module 13).

---

## ✅ Module 11 Checklist
```
[ ] Created a Fargate service behind an ALB target group (target type = ip)
[ ] containerName/containerPort match task def + target group
[ ] Set a sane health-check grace period
[ ] Understand min/max healthy percent + circuit breaker rollback
[ ] Configured target-tracking autoscaling (CPU or request count)
[ ] Know where service events live for debugging
```

➡️ Next: [12-clusters.md](12-clusters.md) — the capacity and organization layer.

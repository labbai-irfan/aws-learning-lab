# Module 12 — Clusters

> A cluster is the logical boundary that groups your services/tasks and provides their **capacity**. This module covers cluster types, capacity providers (Fargate, Fargate Spot, EC2 ASG), bin-packing, organization strategy, and Container Insights.

---

## 1. What a Cluster Is

A cluster is two things at once:
1. **A logical grouping** — a namespace for services, tasks, and their metrics/permissions.
2. **A capacity pool** — the compute tasks actually run on (Fargate microVMs, or EC2 instances you provide).

```
   CLUSTER "hrms-prod"
   ├── capacity: FARGATE + FARGATE_SPOT  (and/or an EC2 ASG)
   ├── service: hrms-frontend-svc  (2 tasks)
   ├── service: hrms-auth-svc      (2 tasks)
   ├── service: hrms-employee-svc  (3 tasks)
   ├── service: hrms-payroll-svc   (2 tasks)
   └── one-off tasks: hrms-migrate (run + exit)
```

With **Fargate** the cluster has no hosts to see — capacity is summoned per task. With **EC2** the cluster has registered container instances (an Auto Scaling Group running the ECS agent).

---

## 2. Create Clusters

```bash
# Fargate cluster (default for this course) with Container Insights on
aws ecs create-cluster \
  --cluster-name hrms-prod \
  --capacity-providers FARGATE FARGATE_SPOT \
  --settings name=containerInsights,value=enabled

aws ecs list-clusters
aws ecs describe-clusters --clusters hrms-prod \
  --query 'clusters[0].{name:clusterName,active:activeServicesCount,running:runningTasksCount}'
```

---

## 3. Capacity Providers

A capacity provider tells ECS **where** to get compute and lets you blend sources with a **strategy** (base + weight):

| Provider | What |
|---|---|
| `FARGATE` | On-demand serverless microVMs (reliable) |
| `FARGATE_SPOT` | Spare capacity, ~70% cheaper, can be reclaimed |
| EC2 ASG provider | Your own instances; supports managed scaling + termination protection |

**Strategy example** — always keep 1 on-demand task, burst the rest cheaply on Spot:
```bash
aws ecs put-cluster-capacity-providers \
  --cluster hrms-prod \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
     capacityProvider=FARGATE,base=1,weight=1 \
     capacityProvider=FARGATE_SPOT,base=0,weight=4
```
- **base** — minimum tasks on this provider before weighting applies.
- **weight** — relative share of tasks **beyond** the base.
- Result: 1st task on FARGATE, then ~4 Spot for every 1 on-demand. 💰 Big savings on stateless services; ⚠️ keep singletons/stateful off pure Spot ([Module 8 §6](08-fargate.md)).

---

## 4. EC2 Launch Type & Bin-Packing

If you run the EC2 launch type, the cluster's container instances are an **Auto Scaling Group**. ECS places tasks using **placement strategies**:

| Strategy | Effect |
|---|---|
| `binpack` (cpu/memory) | Pack tasks tightly → fewer instances → lower cost |
| `spread` (AZ / instance) | Distribute for availability |
| `random` | No preference |

```bash
# example placement: spread across AZs, then binpack by memory
--placement-strategy type=spread,field=attribute:ecs.availability-zone \
                     type=binpack,field=memory
```
**Cluster Auto Scaling (CAS)** with a managed EC2 capacity provider adds/removes instances to fit pending tasks — so you don't manually size the ASG. Fargate skips all of this (no instances).

⚠️ EC2 trap: tasks stuck PENDING with *"no container instances met requirements"* = the ASG has no room (CPU/mem) — scale it out or right-size tasks (Module 13).

---

## 5. How Many Clusters? (organization strategy)

| Strategy | When |
|---|---|
| **One cluster per environment** (dev / staging / prod) | Most common; clean blast-radius + IAM separation |
| **One cluster per team / app** | Strong isolation, separate cost tracking |
| **Shared cluster, many services** | Simpler, good for small orgs / Fargate (capacity is per-task anyway) |

💡 On **Fargate**, a cluster is mostly a logical/billing/permissions boundary (capacity is elastic), so favor **separation by environment** (`hrms-dev`, `hrms-prod`) for safety. On **EC2**, cluster size also affects how well you bin-pack, so consolidating workloads can save money.

🔒 Use cluster boundaries + IAM + tags to keep prod credentials and capacity away from dev experimentation. Tag everything (`Environment=prod`, `App=hrms`) for cost allocation.

---

## 6. Container Insights & Monitoring

Enabling **Container Insights** (per §2, or account-wide) gives CloudWatch dashboards and metrics per cluster/service/task: CPU, memory, network, task counts, and (with the enhanced tier) per-container detail.

```bash
# turn it on for an existing cluster
aws ecs update-cluster-settings --cluster hrms-prod \
  --settings name=containerInsights,value=enabled
```
Key metrics to alarm on (ties into [Phase 09 CloudWatch](../09-cloudwatch/README.md)):
- `CPUUtilization` / `MemoryUtilization` (service) → drives autoscaling.
- `RunningTaskCount` vs desired → service health.
- `DesiredTaskCount` flapping → deploy or capacity problems.

---

## 7. Cleanup

```bash
# scale services to 0, delete them, then the cluster
aws ecs update-service --cluster hrms-prod --service hrms-auth-svc --desired-count 0
aws ecs delete-service  --cluster hrms-prod --service hrms-auth-svc --force
aws ecs delete-cluster  --cluster hrms-prod
```
💰 A Fargate cluster with **no running tasks costs nothing**, but the **ALB, NAT Gateway, RDS, and EFS** keep billing — delete those too when tearing down (see capstone cleanup).

---

## ✅ Module 12 Checklist
```
[ ] Created a Fargate cluster with capacity providers + Container Insights
[ ] Can write a base+weight strategy mixing FARGATE and FARGATE_SPOT
[ ] Understand bin-pack vs spread placement (EC2 launch type)
[ ] Have an environment-based cluster strategy (dev/prod)
[ ] Tag clusters/services for cost allocation
[ ] Know what still bills after tasks stop (ALB/NAT/RDS/EFS)
```

➡️ Next: [13-troubleshooting-handbook.md](13-troubleshooting-handbook.md) — when things break.

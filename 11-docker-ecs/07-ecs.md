# Module 7 — Amazon ECS

> ECS (Elastic Container Service) is AWS's container orchestrator. It schedules, runs, heals, and scales your containers. This module covers the object model, the two launch types (Fargate vs EC2), and how the pieces connect — the foundation for Modules 8–12.

---

## 1. What ECS Is (and Isn't)

ECS is a **managed control plane** that answers: *where should this container run, how many copies, and how do I keep them healthy?* You give it images (from ECR) and blueprints (Task Definitions); it places and supervises the containers.

- **ECS** — AWS-native orchestrator. Simpler, deeply integrated (IAM, ALB, CloudWatch, VPC). No control plane to manage, no cost for the control plane itself.
- **EKS** — managed **Kubernetes**. More portable/feature-rich, steeper learning curve, control-plane fee. Choose if you need the k8s ecosystem or multi-cloud.

This phase uses ECS — the fastest path from "I have a Docker image" to "it's running, scaled, behind HTTPS."

---

## 2. The ECS Object Model

```
   CLUSTER  (logical boundary + capacity)
      │
      ├── SERVICE  (keeps N tasks running, ties to ALB, autoscales)
      │      │
      │      └── TASK  (a running unit = 1+ containers, scheduled together)
      │             │
      │             └── CONTAINER(s)  ← defined by the TASK DEFINITION
      │
      └── TASK DEFINITION  (the blueprint: image, cpu/mem, ports, env, secrets, logs, role)
```

| Object | One-liner | Module |
|---|---|---|
| **Task Definition** | The blueprint — *what* to run and *how* | [10](10-task-definitions.md) |
| **Task** | A running instance of a task definition (1+ containers) | this |
| **Service** | Maintains desired count + ALB + autoscaling | [11](11-services.md) |
| **Cluster** | Logical group + the capacity tasks run on | [12](12-clusters.md) |
| **Launch type** | Fargate (serverless) or EC2 (you own hosts) | [8](08-fargate.md) |

💡 Task vs Service: a **Task** is "run this once" (a one-off job/migration). A **Service** is "keep this running and scale it" (a long-lived API). Same task definition, different scheduler.

---

## 3. Tasks vs Services

```
   RUN TASK (standalone)             SERVICE (long-running)
   ─────────────────────             ──────────────────────
   • runs once, then exits           • maintains desired count (e.g. 3)
   • batch jobs, DB migrations,       • replaces failed tasks automatically
     cron-style work                  • registers tasks with an ALB target group
   • aws ecs run-task                 • rolling deployments + rollback
                                       • Application Auto Scaling
```

```bash
# one-off task (e.g. run DB migrations)
aws ecs run-task --cluster hrms --launch-type FARGATE \
  --task-definition hrms-migrate:3 \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-aaa],securityGroups=[sg-bbb],assignPublicIp=DISABLED}"
```

---

## 4. Launch Types: Fargate vs EC2

```
   FARGATE                              EC2
   ───────                              ───
   AWS runs the hosts (microVMs)        You run an Auto Scaling Group of EC2
   You pick task CPU/mem only           You manage AMIs, patching, capacity
   Pay per task vCPU+GB/sec             Pay for the EC2 instances (filled or not)
   No host to SSH into                  Full host control (GPU, custom kernels, daemonsets)
   Best default                         Best for steady high scale / special hardware / cost tuning
```

| Decide by | Pick |
|---|---|
| "I just want to run containers, no ops" | **Fargate** |
| Spiky/low/dev workloads | **Fargate** (no idle host cost) |
| Need GPUs, special instances, host access | **EC2** |
| Very large, steady fleet where bin-packing saves money | **EC2** (or Fargate Spot) |

This phase defaults to **Fargate** (Module 8). The same task definition can target either — only the cluster's capacity differs.

---

## 5. How ECS Connects to the Rest of AWS

```
   ECR ──image──► ECS Task ──logs──► CloudWatch Logs
                    │  ENI in your VPC (awsvpc)
                    ├──registered──► ALB Target Group ──► clients
                    ├──secrets──────► Secrets Manager / SSM
                    ├──assumes──────► Task Role (app's AWS permissions)
                    └──pulled by────► Execution Role (pull image, write logs)
```

Two IAM roles you'll meet constantly (Module 10):
- **Task Execution Role** — lets *ECS* pull the image from ECR and push logs to CloudWatch.
- **Task Role** — lets *your app code* call AWS (e.g. read an S3 bucket, a Secrets Manager secret).

---

## 6. Minimal "Hello ECS" Path

The full HRMS deployment is the capstone; here's the shape of the workflow you'll repeat:

```
1. Build image            docker build -t app .
2. Push to ECR            (Module 9)
3. Register task def      describes the container (Module 10)
4. Create cluster         Fargate cluster (Module 12)
5. Create service         desired=2, behind ALB, autoscale (Module 11)
6. ECS schedules tasks    pulls image, starts containers, registers w/ ALB
7. Update                 new image → new task def revision → rolling deploy
```

```bash
# create a bare Fargate cluster (capacity comes from Fargate itself)
aws ecs create-cluster --cluster-name hrms \
  --capacity-providers FARGATE FARGATE_SPOT \
  --settings name=containerInsights,value=enabled
aws ecs list-clusters
```

---

## 7. ECS vs the Local Docker You Already Know

| Local Docker | ECS |
|---|---|
| `docker run` | Run task |
| `docker-compose up` (keep running) | Service |
| `docker-compose.yml` | Task definition (per task) + services |
| Your laptop/EC2 host | Cluster capacity (Fargate/EC2) |
| `docker pull` from Hub | Pull from ECR |
| Restart policy | Service desired-count self-healing |
| Manual scaling | Application Auto Scaling |

---

## ✅ Module 7 Checklist
```
[ ] Can draw Cluster → Service → Task → Container + Task Definition
[ ] Know Task (run once) vs Service (keep running/scale)
[ ] Can choose Fargate vs EC2 for a workload
[ ] Know the two IAM roles (execution vs task)
[ ] Created an empty Fargate cluster
```

➡️ Next: [08-fargate.md](08-fargate.md) — serverless containers in depth.

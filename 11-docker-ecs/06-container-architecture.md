# Module 6 — Container & Microservices Architecture

> How the pieces fit together: the layered container architecture, the monolith→microservices transition, communication and data patterns, the 12-factor app, and the HRMS reference architecture you'll build in the capstone.

---

## 1. Container Architecture (the full stack)

```
 ┌─────────────────────────────────────────────────────────────┐
 │  APPLICATION         your code + dependencies (one image)     │
 ├─────────────────────────────────────────────────────────────┤
 │  CONTAINER RUNTIME   containerd / runc  (start/stop process)  │
 ├─────────────────────────────────────────────────────────────┤
 │  CONTAINER ENGINE    Docker / Fargate agent (build, pull, run)│
 ├─────────────────────────────────────────────────────────────┤
 │  OS KERNEL           namespaces (isolation) + cgroups (limits)│
 ├─────────────────────────────────────────────────────────────┤
 │  HOST                EC2 instance / Fargate microVM           │
 ├─────────────────────────────────────────────────────────────┤
 │  ORCHESTRATOR        Amazon ECS  (schedules where/how many)   │
 └─────────────────────────────────────────────────────────────┘
```

**Orchestration** is the layer that turns "I can run a container" into "I run 30 copies of 6 services across 3 AZs, replace the dead ones, roll out new versions with zero downtime, and scale on load." That layer is **ECS** (Modules 7–12) — or Kubernetes/EKS elsewhere.

What an orchestrator gives you:
- **Scheduling** — place tasks on capacity that fits (CPU/RAM).
- **Self-healing** — restart/replace failed tasks to maintain desired count.
- **Scaling** — add/remove tasks on metrics (CPU, requests).
- **Service discovery & load balancing** — route traffic to healthy tasks.
- **Rolling deploys & rollback** — ship new versions safely.

---

## 2. Monolith vs Microservices

```
   MONOLITH                              MICROSERVICES
 ┌────────────────────┐         ┌────────┐ ┌────────┐ ┌────────┐
 │ auth │ emp │ pay    │         │ auth   │ │ employee│ │ payroll │
 │ ─────────────────  │         │ service│ │ service │ │ service │
 │ one codebase       │         └───┬────┘ └───┬────┘ └───┬────┘
 │ one deploy         │             │  own DB  │  own DB  │ own DB
 │ one DB             │         ┌───▼──┐   ┌───▼──┐   ┌───▼──┐
 └────────────────────┘         │ authDB│  │ empDB │  │ payDB │
   scale = clone whole thing    └──────┘   └──────┘   └──────┘
                                 scale each independently
```

| | Monolith | Microservices |
|---|---|---|
| Deploy | All-or-nothing | Per service, independently |
| Scale | Whole app | Only the hot service |
| Tech choices | One stack | Per-service freedom |
| Blast radius | A bug can take down everything | Failure isolated to one service |
| Team ownership | Shared codebase, more coordination | One team owns a service end-to-end |
| Operational cost | Low | Higher (more moving parts, observability needed) |
| Right when | Small team, early product, simple domain | Large team, distinct domains, independent scaling |

⚠️ Microservices are **not free** — you trade code complexity for **distributed-systems complexity** (network calls fail, data is eventually consistent, you need tracing). Start monolithic; split when team/scale pain is real. Containers + ECS make either choice operationally smooth.

---

## 3. Communication Patterns

**Synchronous (request/response)** — service calls service and waits.
```
 frontend ──HTTP──► API/ALB ──► auth-service ──HTTP──► employee-service
```
- Simple, immediate. But couples availability (callee down → caller errors). Use **timeouts, retries with backoff, and circuit breakers**.

**Asynchronous (events/queues)** — service emits an event; others react later.
```
 payroll-service ──"PayrollRun"──► SQS / SNS / EventBridge ──► email-service
                                                            └► audit-service
```
- Decoupled, resilient, absorbs spikes. But eventually consistent and harder to trace.

**Service discovery** — how a service finds another:
- Local Docker: DNS on a user-defined bridge ([Module 5](05-networks.md)).
- ECS: **Service Connect** / **Cloud Map** (`auth.hrms.local`) or an **internal ALB**.

---

## 4. Data Patterns

- **Database-per-service** — each service owns its data; others reach it only through that service's API. Prevents hidden coupling.
- **No shared database** between services for writes (the anti-pattern that turns "micro" services back into a distributed monolith).
- **Saga pattern** — multi-service transactions become a sequence of local transactions + compensating actions (no distributed 2-phase commit).
- **CQRS / read replicas** — separate read and write models when read load dominates.

In the HRMS capstone we keep it pragmatic: separate **logical schemas** per service on a managed **RDS** instance (cost-sane for learning), with the clear rule that a service touches only its own schema.

---

## 5. Cross-Cutting Concerns

These are solved **outside** each service so you don't reimplement them N times:

| Concern | Where it lives |
|---|---|
| TLS termination, routing | **ALB** (path/host rules) |
| AuthN/AuthZ | auth-service + JWT validated at the edge/gateway |
| Config & secrets | **SSM Parameter Store / Secrets Manager** (injected per task) |
| Logging | stdout → **CloudWatch Logs** (per Module 10) |
| Metrics | **CloudWatch** / Container Insights |
| Tracing | **AWS X-Ray** (sidecar) for request flow across services |
| Service mesh (optional) | App Mesh / Service Connect |

The **sidecar pattern**: a helper container in the same task (X-Ray daemon, log router, proxy) sharing the task's network/volumes — handles a cross-cutting concern next to the app without changing app code.

---

## 6. The 12-Factor App (container-native design)

A checklist for services that behave well in a container platform:

1. **Codebase** — one repo per service, tracked in git.
2. **Dependencies** — declared explicitly (package.json) and isolated (image).
3. **Config** — in the **environment**, not the code (Module 10 env/secrets).
4. **Backing services** — DB/cache/queue are attachable resources via URL/creds.
5. **Build, release, run** — strictly separate stages (build image → release w/ config → run).
6. **Processes** — **stateless**; persist state in backing services (Module 4).
7. **Port binding** — the app exports its own service via a port.
8. **Concurrency** — scale out by running **more processes** (more tasks), not bigger ones.
9. **Disposability** — fast startup, graceful SIGTERM shutdown (Module 3 §5).
10. **Dev/prod parity** — same image everywhere; keep gaps small.
11. **Logs** — treat as event streams to **stdout**; the platform routes them.
12. **Admin processes** — run migrations/one-offs as one-shot tasks.

💡 Factors **3, 6, 9, 11** are exactly what makes a container freely schedulable, scalable, and replaceable on ECS. Violating "stateless" (6) is the #1 reason a service "won't scale."

---

## 7. HRMS Reference Architecture (what the capstone builds)

```
                              Internet
                                 │ https://hrms.example.com
                                 ▼
                    ┌──────── Application Load Balancer (ACM TLS) ────────┐
                    │  /            → frontend TG                          │
                    │  /api/auth/*  → auth TG                              │
                    │  /api/emp/*   → employee TG                          │
                    │  /api/pay/*   → payroll TG                           │
                    └──┬───────────┬────────────┬───────────┬─────────────┘
                       ▼           ▼            ▼           ▼
   ECS Cluster   ┌─frontend─┐ ┌─auth────┐ ┌─employee┐ ┌─payroll─┐   (each = a Service:
   (Fargate)     │ React+   │ │ Node    │ │ Node    │ │ Node    │    desired count, ALB
                 │ Nginx    │ │ :5000   │ │ :5000   │ │ :5000   │    target, autoscaling)
                 └──────────┘ └────┬────┘ └────┬────┘ └────┬────┘
                                   └───────────┼───────────┘
                                               ▼ (private subnets)
                          Amazon RDS (MySQL)  ·  ElastiCache (Redis)  ·  EFS (uploads)

   Supporting: ECR (images) · CloudWatch (logs+metrics) · Secrets Manager (DB creds)
               Security Groups per task · NAT GW for outbound · X-Ray (tracing)
```

- Each box on the bottom row is an **ECS Service** running a **Task** from a **Task Definition**, pulling its **image from ECR**, on a **Fargate** cluster — the exact vocabulary of Modules 7–12.
- Stateless services scale horizontally; all state lives in RDS/ElastiCache/EFS.

---

## ✅ Module 6 Checklist
```
[ ] Can name the container architecture layers (app→runtime→engine→kernel→host→orchestrator)
[ ] Can argue monolith vs microservices for a given team/scale
[ ] Know sync vs async + when to use each
[ ] Database-per-service / no shared write DB
[ ] Can recite the 12 factors that matter for containers (3,6,9,11)
[ ] Can read the HRMS reference architecture and map each box to ECS terms
```

➡️ Next: [07-ecs.md](07-ecs.md) — Amazon ECS, the orchestrator.

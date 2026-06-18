# Module 8 — AWS Fargate

> Fargate is the **serverless** compute engine for ECS: you specify CPU/memory per task and AWS runs it on managed microVMs — no EC2 to provision, patch, or scale. This module covers the model, sizing, pricing, networking, and Fargate Spot.

---

## 1. The Fargate Idea

With Fargate you stop thinking about hosts entirely. There is **no cluster of EC2 instances to manage** — no AMIs, no patching, no "is there room for one more task?" You declare a task's CPU and memory; AWS finds capacity, launches a dedicated microVM, runs your task, and bills you per second.

```
   EC2 launch type                  Fargate launch type
   ────────────────                 ────────────────────
   You: size & patch instances      You: size the TASK (cpu/mem)
   You: ensure capacity exists       AWS: provisions a right-sized microVM
   Pay: per instance (idle too)      Pay: per task vCPU + GB, per second
   Bin-pack tasks onto hosts         1 task = its own isolated microVM
```

🔒 Each Fargate task runs in its **own kernel/microVM** (Firecracker) — stronger isolation than co-tenant containers on a shared host.

---

## 2. Task Sizing (the only knobs)

Fargate CPU and memory come in **valid combinations** — memory range depends on the vCPU you pick:

| vCPU (`cpu`) | Memory options (`memory`) |
|---|---|
| 0.25 (256) | 0.5, 1, 2 GB |
| 0.5 (512) | 1–4 GB (1 GB steps) |
| 1 (1024) | 2–8 GB |
| 2 (2048) | 4–16 GB |
| 4 (4096) | 8–30 GB |
| 8 (8192) | 16–60 GB |
| 16 (16384) | 32–120 GB |

```json
{
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",          // 0.5 vCPU at the TASK level
  "memory": "1024"       // 1 GB at the TASK level
}
```
⚠️ `cpu`/`memory` here are **task-level** (shared by all containers in the task). You may *also* set per-container `cpu`/`memory`/`memoryReservation` limits inside that budget (Module 10). Pick a combination from the table or the task won't register.

💡 Right-sizing: start small (0.25–0.5 vCPU / 0.5–1 GB) for a Node API, watch CloudWatch utilization, then adjust. Over-provisioning is the #1 Fargate cost leak.

---

## 3. Ephemeral Storage

Each Fargate task gets **20 GB** ephemeral storage by default, expandable to **200 GB** — gone when the task stops. For persistence, mount **EFS** ([Module 4](04-volumes.md)).

```json
{ "ephemeralStorage": { "sizeInGiB": 40 } }
```

---

## 4. Networking — Always `awsvpc`

Fargate **only** supports the `awsvpc` network mode: each task gets its own ENI and a private IP in your subnet, secured by a Security Group ([Module 5](05-networks.md) §6).

- **Private subnet + NAT** (recommended): tasks have no public IP; outbound (e.g. pulling from ECR, calling APIs) goes through a **NAT Gateway**. Inbound comes only via the ALB.
- **Public subnet + `assignPublicIp=ENABLED`**: needed if a task in a public subnet must reach the internet/ECR without NAT. Cheaper for dev, less secure.

```
   ALB (public subnet)
     │
     ▼
   Fargate task (private subnet, ENI 10.0.10.x, SG: allow 5000 from ALB SG)
     │ outbound
     ▼
   NAT Gateway ──► Internet / ECR / Secrets Manager
```
⚠️ Classic gotcha: a Fargate task in a **private subnet with no NAT and no VPC endpoints can't pull its image from ECR** → task stuck in PENDING then fails. Fix: add a NAT Gateway *or* VPC endpoints for ECR + S3 + CloudWatch Logs (Module 13).

---

## 5. Pricing Model

You pay for **vCPU-seconds + GB-seconds** from image pull start until the task stops (per-second, 1-minute minimum). No charge for idle hosts because there are none.

Rough example (ap-south-1-ish rates, *check the calculator*): a `0.25 vCPU / 0.5 GB` task running 24×7 ≈ **a few dollars/month**. Three small services at desired-count 2 each is still modest — and scales to zero cost when you delete them.

💰 Levers:
- **Right-size** tasks (§2). 
- **Fargate Spot** for fault-tolerant/stateless tasks — up to ~70% cheaper (§6).
- **Scale in** aggressively off-peak (Module 11 autoscaling).
- **Compute Savings Plans** for steady baseline usage.

Estimate at https://calculator.aws/.

---

## 6. Fargate Spot

`FARGATE_SPOT` runs tasks on spare capacity at a deep discount, but AWS can **reclaim** them with a ~2-minute SIGTERM warning. Perfect for stateless, horizontally-scaled services that tolerate a task disappearing.

```bash
aws ecs create-cluster --cluster-name hrms \
  --capacity-providers FARGATE FARGATE_SPOT

# a service can split desired count across providers:
#   base 1 on FARGATE (always-on) + the rest weighted to FARGATE_SPOT
```
A common HRMS pattern: **1 task base on FARGATE** (guaranteed) + **extra tasks on FARGATE_SPOT** (cheap burst) via a capacity-provider strategy (Module 12). ⚠️ Don't put a stateful/singleton workload entirely on Spot.

---

## 7. When NOT to Use Fargate

- Need **GPUs** or specific instance types → EC2 launch type.
- Need **host-level** access, custom kernel modules, or daemonset-style agents → EC2.
- **Very large, steady** fleets where reserved EC2 + bin-packing beats per-task pricing → EC2 (model it).
- Per-task overhead matters for **thousands of tiny short tasks** → batch/Lambda may fit better.

For everything in this course (and most web microservices), **Fargate is the right default**.

---

## ✅ Module 8 Checklist
```
[ ] Can pick a valid cpu/memory combination
[ ] Understand task-level vs container-level limits
[ ] Know Fargate is awsvpc-only and how outbound (NAT/endpoints) works
[ ] Can explain the per-second vCPU+GB pricing and 3 cost levers
[ ] Know when Fargate Spot is safe and the base+spot pattern
[ ] Can name a case where EC2 launch type wins
```

➡️ Next: [09-ecr.md](09-ecr.md) — storing your images privately.

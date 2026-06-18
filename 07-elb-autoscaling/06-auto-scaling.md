# 06 — EC2 Auto Scaling (ASG, Launch Templates & Scaling Policies)

> Load balancers spread traffic; **Auto Scaling** makes sure there are the right number of healthy instances *behind* them. Together they give you a self-healing, elastic, highly-available tier. This module is referenced by EC2, ELB, and CI/CD — it's the glue.

**By the end you can:**
- Build a Launch Template + Auto Scaling Group across multiple AZs.
- Choose the right scaling policy (target tracking / step / scheduled / predictive).
- Wire an ASG to an ALB target group with health checks and connection draining.
- Do zero-downtime deploys with instance refresh, and understand lifecycle hooks & warm pools.

**Prerequisites:** [01 — ELB Core Concepts](01-elb-core-concepts.md), [Phase 03 — EC2](../03-ec2/README.md), [Phase 04 — VPC](../04-vpc-networking/README.md).

---

## 1. The mental model

```
            ┌──────────────── Auto Scaling Group (ASG) ────────────────┐
 Launch     │   min=2   desired=3   max=8     across AZ-a / AZ-b / AZ-c │
 Template ─►│                                                          │
 (AMI +     │   [EC2]      [EC2]      [EC2]      ...scale out on demand │
  type +    │    AZ-a       AZ-b       AZ-a                            │
  SG +      └───────┬─────────┬──────────┬───────────────────────────┘
  userdata)         │         │          │   registers targets
                    ▼         ▼          ▼
                 ┌──────────── ALB Target Group ────────────┐
                 │   health checks /healthz                 │
                 └──────────────────────────────────────────┘
                                 ▲
                            Internet (via ALB)
```

- **Launch Template** = the blueprint for new instances (AMI, instance type, key pair, security groups, IAM instance profile, user data). *(Launch Configurations are legacy — always use Launch Templates; they support versioning, mixed instances, and Spot.)*
- **Auto Scaling Group (ASG)** = the controller that keeps `desired` healthy instances running, spread across the subnets/AZs you give it, replacing any that fail.

---

## 2. The three numbers: min / desired / max

```
min      = floor — ASG never goes below this (HA baseline, e.g. 2 for multi-AZ)
desired  = current target — ASG works to keep exactly this many running
max      = ceiling — scaling never exceeds this (cost guardrail)
```
Scaling policies change **desired** between **min** and **max**. 💡 Set `min ≥ 2` across `≥ 2 AZs` so the loss of one instance or one AZ never takes you to zero.

---

## 3. Health checks & self-healing

| Health check type | Source | Detects |
|---|---|---|
| **EC2** (default) | Instance status checks | Hardware/OS failure, failed boot |
| **ELB** | Target group health check | App-level failure (HTTP 500, hung process) |

⚠️ **Turn on ELB health checks** for app tiers — otherwise an instance whose app has crashed but whose OS is fine stays "healthy" and keeps receiving traffic. With ELB checks on, the ASG **terminates and replaces** the failing instance automatically.

- **Health check grace period** (e.g. 300s) — don't health-check an instance until it's had time to boot + start the app. Too short = boot loop of terminations.
- **Connection draining / deregistration delay** (on the target group) — finish in-flight requests before removing a target.

---

## 4. Scaling policies — pick the right one

| Policy | How it works | Best for |
|---|---|---|
| **Target Tracking** ✅ | "Keep avg CPU at 50%" — ASG computes the math | **Default choice**; simplest, most common |
| **Step Scaling** | Add N instances per alarm threshold band | Fine-grained reaction to big metric jumps |
| **Simple Scaling** | One adjustment per alarm, then cooldown | Legacy; superseded by step/target |
| **Scheduled** | Change capacity at a time/date | Known patterns ("scale to 10 at 9am Mon-Fri") |
| **Predictive** | ML forecasts load, pre-scales ahead of it | Recurring daily/weekly cyclical traffic |

```
Target Tracking example (the 90% case):
  Metric: ASGAverageCPUUtilization   Target: 50%
  → traffic rises, CPU hits 70% → ASG adds instances until avg returns to ~50%
  → traffic falls, CPU drops to 20% → ASG removes instances (down to min)
```

💡 You can combine: **scheduled** (baseline for known peaks) + **target tracking** (handle the unexpected). Custom metrics (e.g. SQS queue depth, requests-per-target) make great scaling triggers for worker tiers.

**Cooldowns / warm-up:** prevent thrashing by ignoring further scaling actions until new instances are contributing metrics. Target-tracking uses an *instance warm-up* instead of a global cooldown.

---

## 5. Zero-downtime deploys: Instance Refresh

```
New AMI / Launch Template version
        │
        ▼
Instance Refresh  →  replaces instances in batches
   MinHealthyPercentage = 90%   (keep 90% serving while rolling)
   InstanceWarmup       = 300s  (wait before counting a new instance healthy)
   → optional checkpoints + rollback on failure
```
This is the native way to roll out a new AMI or config across an ASG without downtime — and it underpins **rolling deployments** in [Phase 12 — CI/CD](../12-cicd/README.md). (Blue/green and canary use CodeDeploy / two target groups; see the CI/CD phase.)

---

## 6. Lifecycle hooks & warm pools (advanced)

- **Lifecycle hooks** pause an instance at `Pending:Wait` (launch) or `Terminating:Wait` (shutdown) so you can run setup (register with config mgmt, warm caches) or cleanup (drain, deregister, flush logs) before it serves or dies.
- **Warm pools** keep pre-initialized, stopped instances ready so scale-out is near-instant for slow-booting apps (you pay only for storage while stopped).
- **Termination policy** decides *which* instance to remove on scale-in (default: oldest launch template, then closest to billing hour). Use **instance scale-in protection** to shield instances doing critical work.

---

## 7. Cost & capacity options

- **Mixed instances policy** in the Launch Template: blend On-Demand + **Spot** across multiple instance types/AZs for big savings on fault-tolerant tiers (e.g. "70% Spot, 30% On-Demand, diversify across m5/m5a/m6i").
- Scale-in to a low `min` off-peak; pair with **scheduled scaling** for predictable lulls.
- ASGs themselves are **free** — you pay only for the EC2/EBS they run.
- 💰 A too-low `max` causes throttled growth and dropped users under load; a too-high `max` risks runaway cost. Alarm on `GroupDesiredCapacity` nearing `max`.

---

## 8. HRMS example

```
Route 53  →  ALB (public subnets, 2 AZs)
                │  forward /  and /api/*
                ▼
       Target Group (health /api/health, 200 OK)
                ▲   registers/deregisters automatically
   ┌────────────┴───── ASG ─────────────┐
   │ Launch Template: HRMS AMI, t3.small │
   │ min 2 · desired 2 · max 6           │
   │ Target tracking: CPU 50% + ALB      │
   │   RequestCountPerTarget = 1000      │
   │ ELB health checks ON, grace 300s    │
   └─────────────────────────────────────┘
                │
                ▼
        RDS MySQL Multi-AZ (private subnets)
```
Payroll-run days spike CPU → ASG scales to 4–6; nights drop back to 2. An instance that fails its `/api/health` check is replaced within minutes with **no human action**.

---

## 9. Minimal CLI walkthrough

```bash
# 1) Launch template
aws ec2 create-launch-template --launch-template-name hrms-lt \
  --version-description v1 \
  --launch-template-data '{"ImageId":"ami-xxxx","InstanceType":"t3.small",
     "SecurityGroupIds":["sg-xxxx"],"IamInstanceProfile":{"Name":"hrms-ec2-role"}}'

# 2) ASG across 2 private subnets, attached to a target group
aws autoscaling create-auto-scaling-group --auto-scaling-group-name hrms-asg \
  --launch-template LaunchTemplateName=hrms-lt,Version='$Latest' \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "subnet-aaa,subnet-bbb" \
  --target-group-arns arn:aws:elasticloadbalancing:...:targetgroup/hrms-tg/xxxx \
  --health-check-type ELB --health-check-grace-period 300

# 3) Target-tracking policy: keep CPU at 50%
aws autoscaling put-scaling-policy --auto-scaling-group-name hrms-asg \
  --policy-name cpu50 --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{"PredefinedMetricSpecification":
     {"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'
```

---

## 10. Common pitfalls ⚠️

- ELB health checks left **off** → crashed apps keep getting traffic, never replaced.
- Grace period **too short** → instances killed mid-boot (termination loop).
- ASG in **one AZ / one subnet** → no AZ resilience (defeats the purpose).
- `max` too low → can't absorb spikes; `min` too low → cold every morning.
- Scaling on the wrong metric (CPU when the bottleneck is queue depth or memory).
- Forgetting that **instance refresh** (not "edit the template") is what rolls out a new AMI.

---

## 11. Quick reference

```
Launch Template  → blueprint (AMI, type, SG, IAM, userdata) — versioned
ASG              → min/desired/max + subnets + health checks; self-heals
Health check     → use ELB type for app tiers
Target Tracking  → default policy ("keep CPU at X%")
Scheduled        → known time-based capacity changes
Predictive       → ML pre-scaling for cyclical load
Instance Refresh → zero-downtime AMI/template rollout (rolling deploy)
Lifecycle hooks  → run setup/cleanup before serve/terminate
Warm pools       → pre-baked stopped instances for fast scale-out
Mixed instances  → On-Demand + Spot for cost savings
```

**Official docs:** EC2 Auto Scaling — https://docs.aws.amazon.com/autoscaling/ec2/userguide/

---

*Next: [02 — Architectures](02-architectures.md) ties ASG + ALB into full HA designs · [03 — Labs](03-labs.md) builds one. Back to [ELB & Auto Scaling README](README.md).*

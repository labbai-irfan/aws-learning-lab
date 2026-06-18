# Module 2 — Production Architectures

> How to assemble ALB/NLB, target groups, health checks, and Auto Scaling into **highly-available, multi-server, self-healing** systems. Diagrams + the reasoning behind each choice.

**Covers:** High Availability design · Multi-Server deployment · Auto Scaling integration · routing patterns (path/host/microservices) · Blue/Green & Canary · NLB & internal LB patterns · 4 reference production architectures.

---

## 1. High Availability (HA) design principles

HA = **no single point of failure** and **automatic recovery**. With ELB, you get there by spreading every layer across **at least two Availability Zones**.

```
                         Region (e.g. ap-south-1)
   ┌───────────────────────────────────────────────────────────────┐
   │                                                                 │
   │   AZ-a                              AZ-b                         │
   │   ┌──────────────┐                  ┌──────────────┐            │
   │   │ public subnet│   ALB node       │ public subnet│  ALB node  │
   │   └──────┬───────┘                  └──────┬───────┘            │
   │          │                                  │                    │
   │   ┌──────▼───────┐                  ┌──────▼───────┐            │
   │   │private subnet│  EC2 (app)       │private subnet│  EC2 (app) │
   │   └──────┬───────┘                  └──────┬───────┘            │
   │          │                                  │                    │
   │   ┌──────▼───────┐                  ┌──────▼───────┐            │
   │   │private subnet│  RDS primary     │private subnet│  RDS standby│
   │   └──────────────┘                  └──────────────┘            │
   └───────────────────────────────────────────────────────────────┘
        Lose an entire AZ and the site stays up.
```

**The HA rules of thumb:**
1. **≥2 AZs everywhere** — ALB subnets, app instances, RDS (Multi-AZ).
2. **≥2 healthy targets per AZ** so losing one instance doesn't overload its AZ.
3. **The LB itself is already HA** — AWS runs redundant nodes per AZ for you; you just enable ≥2 subnets.
4. **Health checks must be honest** — they're what makes failover automatic.
5. **State lives outside the instances** — DB in RDS, sessions in Redis/DynamoDB, files in S3 — so any instance is disposable.
6. **Capacity headroom (N+1)** — provision so the fleet survives losing one AZ's worth of instances.

⚠️ **The #1 HA mistake:** putting the ALB in subnets from only one AZ, or all app instances in one AZ. You've "added a load balancer" but kept the single point of failure. Always check your subnet/AZ spread.

---

## 2. Multi-Server deployment

Moving from one box to a fleet behind an ALB. The key shift: instances become **interchangeable and disposable**.

```
                         ┌──────── ALB (2 AZs) ────────┐
   Route 53 ──HTTPS──►   │  HTTP:80 → 301 → HTTPS:443  │
                         └──────────────┬───────────────┘
                                        │ forward
                                        ▼
                              Target Group  (/healthz)
                          ┌─────────────┬─────────────┐
                          ▼             ▼             ▼
                       EC2-a         EC2-b         EC2-c
                       (AZ-a)        (AZ-b)        (AZ-a)
                          └─────────────┴─────────────┘
                                        │
                                        ▼
                            RDS (Multi-AZ) · ElastiCache · S3
```

### Making instances identical (so the LB can treat them as one)
- **Golden AMI** or **user-data bootstrap** so every instance comes up configured the same.
- **Externalize everything stateful:** DB → RDS, sessions → ElastiCache/DynamoDB, uploads → S3, secrets → SSM Parameter Store / Secrets Manager.
- **One health endpoint** (`/healthz`) every instance exposes.
- **No `localhost`-only assumptions** — config comes from env/SSM, not a file edited by hand on one box.

### Deploying new code without downtime (manual fleet)
1. Build a new AMI / push new code.
2. Replace instances **one AZ/instance at a time** (rolling), letting the deregistration delay drain each.
3. Health checks gate the new instance into rotation before the old one leaves.

💡 In practice you automate this with an **Auto Scaling Group + instance refresh** (next section) or a CodeDeploy blue/green deployment.

---

## 3. Auto Scaling integration

This is where ELB becomes truly powerful. The **Auto Scaling Group (ASG)** owns the fleet; the **target group** is how the ALB finds it.

```
   Launch Template (AMI + instance type + user-data + SG)
            │
            ▼
   ┌─────────────── Auto Scaling Group ───────────────┐
   │  min=2  desired=2  max=8                          │
   │  spans subnets in AZ-a + AZ-b                     │
   │  attached to ──► Target Group  ◄── ALB forwards   │
   │  health check type: ELB (use the TG health check) │
   └───────────────────────────────────────────────────┘
            ▲                         │
            │ scale-out / scale-in    ▼
   CloudWatch alarm           registers/deregisters
   (CPU > 60% / ALB           targets automatically
    RequestCountPerTarget)
```

### How they connect
- The ASG references the **target group ARN(s)** → as it launches/terminates instances, it **auto-registers/deregisters** them with the target group. You never touch targets by hand.
- Set the ASG **health check type to `ELB`** (not just `EC2`) so the ASG **replaces** instances the load balancer marks unhealthy — not only ones that fail the hypervisor check.
- A **scaling policy** drives `desired` capacity up/down.

🛠️ Attach an ASG to a target group and use ELB health checks:
```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name asg-web \
  --launch-template LaunchTemplateId=<lt-id>,Version='$Latest' \
  --min-size 2 --max-size 8 --desired-capacity 2 \
  --vpc-zone-identifier "<private-subnet-az-a>,<private-subnet-az-b>" \
  --target-group-arns <tg-arn> \
  --health-check-type ELB --health-check-grace-period 90
```

### Choosing the scaling signal
| Metric | Good for |
|--------|----------|
| **Target tracking on CPU** (e.g. keep avg 50%) | Simple, CPU-bound apps |
| **`ALBRequestCountPerTarget`** target tracking | Request-driven apps — scales on *traffic*, not just CPU. Often the best signal. |
| Custom CloudWatch metric (queue depth, latency) | Worker fleets, async pipelines |

🛠️ Target-tracking on requests-per-target (e.g. 1000 req/target):
```bash
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name asg-web \
  --policy-name tt-req-per-target \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification":{
      "PredefinedMetricType":"ALBRequestCountPerTarget",
      "ResourceLabel":"<alb-id>/<targetgroup-id>"
    },
    "TargetValue":1000.0
  }'
```

⚠️ **Health-check grace period:** give new instances enough time to boot + warm up before the ASG starts evaluating ELB health, or they get killed mid-boot in a loop. Match it to your real startup time (90–300s).

💡 **Slow start** on the target group ramps traffic to a freshly-healthy instance gradually — pair with grace period for cache/JIT warm-up.

---

## 4. Routing patterns (ALB)

### Path-based routing — monolith → microservices
```
   ALB (one listener HTTPS:443)
     ├─ /api/orders/*  → TG-orders   (orders service fleet)
     ├─ /api/users/*   → TG-users    (users service fleet)
     ├─ /static/*      → TG-static   (or redirect to S3/CloudFront)
     └─ default        → TG-web      (React/static frontend)
```
One ALB, one cert, one DNS name fronts many independently-scaled services. Each service = its own target group + ASG.

### Host-based routing — multi-tenant / multi-app
```
   ALB
     ├─ app.example.com    → TG-app
     ├─ admin.example.com  → TG-admin
     └─ api.example.com    → TG-api
   (SNI serves the right cert per host)
```

### Header / weighted routing — canary
```
   Rule: IF header X-Canary = true  → TG-green (new version)
   Default (weighted): 95% → TG-blue, 5% → TG-green
```

---

## 5. Blue/Green & Canary deployments

**Blue/Green:** run two identical fleets; shift traffic from old (blue) to new (green) instantly, roll back instantly.
```
   t0:  listener → 100% TG-blue (v1)          [green idle, warmed]
   t1:  validate green via test rule/host
   t2:  listener → 100% TG-green (v2)         [blue idle = instant rollback]
   t3:  if green healthy for N min → tear down blue
```

**Canary:** shift a *small slice* first using weighted target groups (e.g. 5% → green), watch error/latency metrics, then ramp 25% → 50% → 100%.

💡 Tools that automate this: **AWS CodeDeploy** (blue/green for ASG + ALB), **ECS/EKS** rolling/blue-green, or your own pipeline flipping listener weights. The ELB primitive underneath is always **weighted forward actions across two target groups**.

---

## 6. NLB patterns

### NLB for static IPs in front of an ALB
Some enterprise clients allow-list **IP addresses**, but you want ALB's L7 routing. Chain them:
```
   Client (allow-lists fixed EIPs)
        │
        ▼
   NLB (Elastic IP per AZ — stable, allow-listable)
        │  target-type: alb
        ▼
   ALB (path/host routing, TLS, WAF)
        │
        ▼
   Target Groups → ASG fleets
```

### NLB for non-HTTP / extreme scale
```
   IoT devices (MQTT/TCP:8883) ─► NLB TCP:8883 ─► TG ─► broker fleet (sees real client IP)
   Game clients (UDP)          ─► NLB UDP       ─► TG ─► game servers
```

### Internal load balancers (private, no internet)
Mark the LB **`internal`** (no public IPs) to balance **service-to-service** traffic inside the VPC:
```
   Frontend fleet ──► Internal ALB ──► Backend API fleet ──► Internal NLB ──► DB proxy fleet
```
Internal LBs get private IPs only and are reachable from inside the VPC / peered networks / VPN.

---

## 7. Security architecture around the LB

```
   Internet
      │  (only 80/443 from 0.0.0.0/0)
      ▼
   [ALB Security Group]  inbound: 80,443 from 0.0.0.0/0 ; outbound: to app SG
      │
      ▼
   [App Instance SG]  inbound: 8080 ONLY from the ALB's security group  ◄── key trick
      │
      ▼
   [RDS SG]  inbound: 3306 ONLY from the App SG
```

🔒 **The SG-references-SG pattern is the core of LB security:** app instances accept traffic **only from the ALB's security group**, not from `0.0.0.0/0`. Instances live in **private subnets** with no public IP. The only thing the internet can reach is the ALB.

🔒 Add **AWS WAF** to the ALB for L7 protection (SQLi/XSS/rate-limiting/geo-blocking). WAF attaches to ALB (and CloudFront/API Gateway), **not** to NLB.

⚠️ **NLB source-IP note:** because NLB can preserve the client IP, your **target SG must allow the client CIDRs**, not the LB SG. This trips people up constantly — see [troubleshooting](05-troubleshooting.md).

---

## 8. Reference Architecture A — Classic HA web app (the 80% case)

```
   Route 53 (ALIAS shop.example.com → ALB)
        │  HTTPS
        ▼
   ┌──────────────── ALB (public subnets AZ-a/AZ-b) ────────────────┐
   │  Listener 80  → redirect 301 → HTTPS:443                        │
   │  Listener 443 → ACM cert, TLS-1.2+ policy → forward TG-web      │
   │  + AWS WAF                                                       │
   └────────────────────────────────────────────────────────────────┘
        │
        ▼   TG-web  (health: GET /healthz, 200, interval 15s)
   ┌──────────────── Auto Scaling Group (private subnets) ──────────┐
   │  min 2 / desired 2 / max 8 · health-check-type ELB             │
   │  target-tracking: ALBRequestCountPerTarget = 1000              │
   │     EC2(AZ-a)   EC2(AZ-b)   ... scales out under load          │
   └────────────────────────────────────────────────────────────────┘
        │
        ▼
   RDS Multi-AZ (private)  ·  ElastiCache Redis (sessions)  ·  S3 (uploads)
```
**Why it's good:** survives an AZ loss, scales on real traffic, stateless instances, TLS managed by ACM, locked-down SGs. This is the architecture the [labs](03-labs.md) build.

---

## 9. Reference Architecture B — Microservices on one ALB

```
   ALB (HTTPS:443)
     ├─ /api/orders/*  → TG-orders → ASG-orders
     ├─ /api/users/*   → TG-users  → ASG-users
     ├─ /api/pay/*     → TG-pay    → ASG-pay
     └─ default        → TG-web    → ASG-web (frontend)
```
Each service scales independently, deploys independently, has its own health check. One ALB, one cert, one entry point. Add per-service path rules as you split the monolith.

---

## 10. Reference Architecture C — Static-IP enterprise ingress

```
   Partner firewall (allow-lists 3 EIPs)
        │
        ▼
   NLB (EIP per AZ, TCP:443)  ── target-type: alb ──►  ALB (L7 routing + WAF)
                                                            │
                                                            ▼
                                                     TG fleets / ASGs
```
**Why:** satisfies "we only allow fixed IPs" while keeping ALB features behind it.

---

## 11. Reference Architecture D — Tiered internal services

```
   Internet ─► Public ALB ─► Frontend ASG
                                  │ (calls)
                                  ▼
                          Internal ALB ─► Backend API ASG
                                              │
                                              ▼
                                       RDS / internal NLB → data services
```
Each tier scales and deploys independently; only the front ALB is internet-facing. Everything else is private.

---

## ✅ Module 2 checklist
- [ ] I can draw a 2-AZ HA architecture and name every single point of failure I removed.
- [ ] I can explain how an ASG auto-registers targets and why `health-check-type ELB` matters.
- [ ] I can pick a scaling signal (CPU vs RequestCountPerTarget) and justify it.
- [ ] I can design path/host routing for a microservices split on one ALB.
- [ ] I can describe blue/green & canary in terms of weighted target groups.
- [ ] I can secure the tier with SG-references-SG and explain the NLB source-IP exception.

➡️ Next: [03-labs.md](03-labs.md) — build Reference Architecture A end to end.

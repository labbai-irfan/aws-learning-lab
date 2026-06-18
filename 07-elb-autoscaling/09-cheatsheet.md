# 09 — ELB & Auto Scaling Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-elb-core-concepts.md) & [06 — Auto Scaling](06-auto-scaling.md).

## Load balancer types
| | **ALB** | **NLB** | **GWLB** |
|---|---|---|---|
| Layer | 7 (HTTP/S) | 4 (TCP/UDP/TLS) | 3 (GENEVE) |
| Routing | path/host/header/method | port (5-tuple) | appliance insertion |
| Static IP | No (DNS) | **Yes (EIP/AZ)** | — |
| Source IP | `X-Forwarded-For` | **Preserved** | — |
| Use | web apps, microservices | extreme scale, non-HTTP, static IP | firewalls/IDS inline |
- CLB = legacy, don't build new.

## Components
```
Listener (port+proto, TLS terminates here)
  └─ Rules (ALB: path/host/header) → Target Group (health checks + stickiness)
        └─ Targets (instance / ip / lambda / alb)  — only HEALTHY get traffic
```

## Health checks
- Config lives on the **target group**. Use a light `/healthz` (don't hammer the DB).
- ASG **health-check type = ELB** → unhealthy instances are terminated + replaced.
- 502 = bad target response · 503 = no healthy targets · 504 = target timeout.

## TLS / certs
- **ACM** = free, auto-renewing certs for ALB/NLB/CloudFront/API GW (can't export to raw EC2).
- **SNI** = many certs/domains on one HTTPS listener. Redirect 80→443 via a listener rule.

## Stickiness / cross-zone / draining
- Stickiness: ALB cookie · NLB source-IP flow. Prefer **stateless** apps (sessions in Redis).
- Cross-zone: **ALB on (free)**, **NLB off by default** (may incur inter-AZ cost).
- Deregistration delay = connection draining (finish in-flight requests, default ~300s).

## Auto Scaling
| Concept | Note |
|---|---|
| **Launch Template** | versioned blueprint (AMI/type/SG/IAM/userdata) — prefer over Launch Config |
| **min / desired / max** | floor / current target / ceiling |
| **Target tracking** ✅ | "keep CPU at 50%" — default policy |
| **Step / Simple** | threshold-based (legacy: simple) |
| **Scheduled** | known time-based capacity |
| **Predictive** | ML pre-scaling for cyclical load |
| **Instance Refresh** | zero-downtime AMI/template rollout (rolling) |
| **Lifecycle hooks / warm pools** | setup-cleanup / fast scale-out |

## Exam triggers 💡
- "Path/host routing for microservices" → **ALB**. "Static IP / UDP / millions rps" → **NLB**.
- "Inline firewall appliance" → **GWLB**. "Free auto-renew certs" → **ACM**.
- "Replace failed instances automatically" → **ASG + ELB health check**.
- "Keep average CPU at X%" → **target tracking**. "9am Monday spike" → **scheduled**.
- "Zero-downtime new AMI" → **instance refresh**. "Scale workers on backlog" → **SQS depth metric**.

## Gotchas ⚠️
- ALB needs subnets in **≥2 AZs**; ASG should span ≥2 AZs with `min ≥ 2`.
- Health-check grace period too short → ASG kills booting instances (loop).
- Delete the LB after labs — hourly charge runs 24/7.
- Apex domain → use a Route 53 **Alias** (not CNAME) to the ALB.

---
*Back to [ELB & Auto Scaling README](README.md).*

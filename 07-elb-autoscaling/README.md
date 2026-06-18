# Phase 07 — Elastic Load Balancing (ELB) Complete Learning Repository

> A hands-on, production-focused course on **AWS Elastic Load Balancing** — Application Load Balancer (ALB), Network Load Balancer (NLB), Target Groups, Health Checks, SSL/TLS Termination, and Sticky Sessions — culminating in a **highly-available, auto-scaling, multi-AZ production architecture**.

Authored as a structured program by an **AWS Load Balancing Architect**. Builds on [Phase 03 — EC2](../03-ec2/README.md), [Phase 06 — RDS](../06-rds/README.md), and [Phase 04 — VPC](../04-vpc-networking/README.md). Every module has explanations, ASCII diagrams, real CLI commands, and practice material.

---

## 🎯 Who This Is For
- Anyone who can launch EC2 instances and now wants to run **more than one server** behind a single endpoint.
- Developers moving from "one big EC2 box" to a **highly-available, auto-scaling** design.
- Candidates preparing for **AWS Solutions Architect / SysOps Associate** and DevOps interviews.

**Prerequisites:** An AWS account with MFA + a billing budget, a working VPC with ≥2 public and ≥2 private subnets across 2 AZs (see [Phase 04 — VPC](../04-vpc-networking/README.md)), and at least one deployable app (the [Phase 03 capstone](../03-ec2/project/README.md) works perfectly).

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | ELB Core Concepts (all topics) | [01-elb-core-concepts.md](01-elb-core-concepts.md) | 4 hrs |
| 2 | **EC2 Auto Scaling** (ASG · Launch Templates · scaling policies · instance refresh) | [06-auto-scaling.md](06-auto-scaling.md) | 2 hrs |
| 3 | Production Architectures (HA / Multi-Server / Auto Scaling) | [02-architectures.md](02-architectures.md) | 2 hrs |
| 4 | Labs (hands-on, console + CLI) | [03-labs.md](03-labs.md) | 5 hrs |
| 5 | 50 Production Scenarios | [04-scenarios.md](04-scenarios.md) | 2.5 hrs |
| 6 | Troubleshooting Guide | [05-troubleshooting.md](05-troubleshooting.md) | 1.5 hrs |

**Total:** ~18 hours.

---

## 📚 Topics Covered

**Core building blocks** (Module 1)
- ALB · NLB · Gateway Load Balancer (overview) · Listeners & Rules · Target Groups · Targets (instance / IP / Lambda / ALB) · Health Checks · SSL/TLS Termination · ACM Certificates · SNI · Sticky Sessions · Cross-Zone Load Balancing · Connection Draining (Deregistration Delay)

**Architecture & operations** (Module 2)
- High Availability Design · Multi-Server Deployment · Auto Scaling Integration · Blue/Green & Canary · Path/Host-based routing · Microservices fan-out · Production reference architectures

**Practice**
- Hands-on labs · 50 production scenarios · troubleshooting playbook

---

## ⚡ ELB Mental Model (60-second overview)

```
                          Internet (clients)
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │   LOAD BALANCER (ALB/NLB) │  ← DNS name, spans ≥2 AZs
                    │   • lives in ≥2 subnets   │
                    │   • has a Security Group  │  (ALB only; NLB ~ passthrough)
                    └──────────────────────────┘
                                 │
                            LISTENER  (port + protocol, e.g. HTTPS:443)
                                 │   • SSL/TLS terminates here (ACM cert)
                                 │   • RULES route by path/host/header (ALB)
                                 ▼
                       ┌──────────────────┐
                       │   TARGET GROUP   │  ← health checks live here
                       │  protocol/port   │     stickiness config lives here
                       └──────────────────┘
                          │      │      │
                          ▼      ▼      ▼
                       Target Target Target   (EC2 / IP / Lambda)
                       AZ-a    AZ-b   AZ-a     only HEALTHY targets get traffic
```

**In words:** A **load balancer** gives you one stable DNS name. A **listener** checks the incoming port/protocol (and for HTTPS, **terminates TLS** using an **ACM certificate**). The listener's **rules** decide which **target group** handles the request (ALB can route by path/host/header). The target group runs **health checks** and only sends traffic to **healthy targets**, optionally pinning a user to one target with **sticky sessions**. Pair it with an **Auto Scaling Group** so unhealthy/under-provisioned capacity is replaced automatically.

---

## 🔑 ELB in One Line per Topic

| Topic | One-liner |
|-------|-----------|
| **ALB** | Layer 7 (HTTP/HTTPS) LB with path/host routing — for web apps & microservices |
| **NLB** | Layer 4 (TCP/UDP/TLS) LB, ultra-low latency, static IPs — for extreme scale/non-HTTP |
| **GWLB** | Layer 3 LB for inserting firewalls/IDS appliances inline (overview only) |
| **Listener** | A port+protocol the LB listens on (HTTP:80, HTTPS:443, TCP:3306) |
| **Rule** | ALB listener logic: "if path = /api/* → forward to api target group" |
| **Target Group** | A pool of backends + the health-check config that guards them |
| **Health Check** | Periodic probe; unhealthy targets stop receiving traffic |
| **SSL Termination** | LB decrypts HTTPS so backends can speak plain HTTP |
| **ACM** | Free, auto-renewing TLS certificates for ALB/NLB |
| **SNI** | Multiple HTTPS certs/domains on one listener |
| **Sticky Session** | Pin a client to one target via a cookie (ALB) or 5-tuple (NLB) |
| **Cross-Zone LB** | Spread load evenly across targets in ALL AZs, not just per-AZ |
| **Deregistration Delay** | Connection draining — finish in-flight requests before removing a target |

---

## ⚖️ ALB vs NLB — the decision in 20 seconds

| | **ALB** | **NLB** |
|---|---------|---------|
| OSI Layer | 7 (HTTP/HTTPS/gRPC) | 4 (TCP/UDP/TLS) |
| Routing | Path, host, header, query, method | Port only (5-tuple) |
| Performance | High | **Ultra-low latency, millions of req/s** |
| Static IP | No (DNS name only) | **Yes — 1 Elastic IP per AZ** |
| TLS termination | Yes | Yes (or TCP passthrough) |
| WebSocket / HTTP/2 | Yes | (TCP passthrough works) |
| Preserve source IP | No (use `X-Forwarded-For`) | **Yes, natively** |
| Sticky sessions | Cookie-based (app/duration) | Source-IP (flow) based |
| Typical use | Web apps, REST APIs, microservices | Gaming, IoT, MQTT, databases, allow-listed static IPs |

**Rule of thumb:** Default to **ALB** for anything HTTP. Reach for **NLB** when you need static IPs, non-HTTP protocols, source-IP preservation, or extreme throughput. (Classic Load Balancer is legacy — don't build new on it.)

---

## 🛠️ What You'll Build (Module 2 + Labs)

A production-grade, self-healing web tier:
```
   Route 53 ──► ACM-secured HTTPS ──► ┌──────────── ALB (public subnets, 2 AZs) ───────────┐
                                       │  HTTP:80 → redirect → HTTPS:443 (TLS terminates)   │
                                       └────────────────────────────────────────────────────┘
                                                          │  forward
                                                          ▼
                                           Target Group  (health checks /healthz)
                                              │                         │
                                       ┌──────┴───────┐         ┌───────┴──────┐
                                       │ EC2  AZ-a    │         │ EC2  AZ-b    │   ← Auto Scaling Group
                                       │ (private)    │         │ (private)    │     scales 2→N on CPU/req
                                       └──────────────┘         └──────────────┘
                                                          │
                                                          ▼
                                              RDS Multi-AZ (private subnets)
```
Full step-by-step in [03-labs.md](03-labs.md).

---

## 📌 Conventions
- 🛠️ = run this · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `$` = run as normal user · CLI examples use **AWS CLI v2**
- Replace placeholders in `<angle-brackets>` (e.g. `<vpc-id>`, `<subnet-id>`) with your own IDs.

---

## 💰 Cost Note (read before you build)
ELB is **not free-tier-generous** — you pay an hourly charge **plus** an LCU/NLCU usage charge whether or not traffic flows.
- ALB ≈ **$0.0225/hr** (~$16/mo) + LCU charges.
- NLB ≈ **$0.0225/hr** (~$16/mo) + NLCU charges.
- 💡 **Delete the load balancer** when you finish a lab — the hourly charge runs 24/7.
- Always confirm current numbers at the pricing link below.

---

## 📖 Official References
- ELB docs: https://docs.aws.amazon.com/elasticloadbalancing/
- ALB guide: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- NLB guide: https://docs.aws.amazon.com/elasticloadbalancing/latest/network/
- ELB pricing: https://aws.amazon.com/elasticloadbalancing/pricing/
- ACM (certificates): https://docs.aws.amazon.com/acm/

---

*Start with [01-elb-core-concepts.md](01-elb-core-concepts.md).* 🚀

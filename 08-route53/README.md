# Phase 08 — Amazon Route 53 Complete Learning Repository

> A hands-on, architecture-focused course on **Amazon Route 53** — AWS's scalable DNS and domain registration service. From "what is DNS?" to wiring a custom domain + HTTPS onto your React front end and Node API, with routing policies, health checks, and failover.

Authored as a structured program by an **AWS DNS Expert**. Builds on [Phase 01 — AWS Fundamentals](../01-aws-fundamentals/README.md), [Phase 03 — EC2](../03-ec2/README.md), and [Phase 05 — S3](../05-s3/README.md). Every module has explanations, diagrams, real commands, and practice questions.

---

## 🎯 Who This Is For
- Anyone who finished earlier phases and wants to put apps on a real domain.
- Developers who need **custom domains + HTTPS** for front ends and APIs.
- Candidates preparing for **AWS Solutions Architect / SysOps Associate** and DevOps interviews.

**Prerequisites:** An AWS account with MFA + a billing budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). A registered domain helps for the hands-on parts (you can register one inside the labs).

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | Route 53 Core Concepts (all topics) | [01-route53-core-concepts.md](01-route53-core-concepts.md) | 3.5 hrs |
| 2 | Architectures (Domain / SSL / React / API) | [02-architectures.md](02-architectures.md) | 1.5 hrs |
| 3 | Labs (hands-on) | [03-labs.md](03-labs.md) | 3 hrs |
| 4 | Troubleshooting | [04-troubleshooting.md](04-troubleshooting.md) | 1 hr |
| 5 | 100 Interview Questions | [05-100-interview-questions.md](05-100-interview-questions.md) | 2 hrs |
| 6 | 50 Scenario Questions | [06-50-scenario-questions.md](06-50-scenario-questions.md) | 2 hrs |
| 7 | 100 MCQs | [07-100-mcqs.md](07-100-mcqs.md) | 2 hrs |
| 8 | Cheat Sheet (1-page revision) | [08-cheatsheet.md](08-cheatsheet.md) | 30 min |

**Total:** ~15 hours.

---

## 📚 Topics Covered

**Core building blocks** (Module 1)
- DNS Basics · Domain Registration · Hosted Zones · A Records · CNAME · Alias · MX · TXT · Routing Policies · Health Checks · Failover Routing

**Architecture & operations**
- Domain Architecture · SSL Architecture · React Deployment Domain Setup · Backend API Domain Setup (Module 2)
- Labs (Module 3) · Troubleshooting (Module 4)

**Practice**
- 100 interview questions · 50 scenario questions

---

## ⚡ DNS / Route 53 Mental Model (60-second overview)

```
   USER types  https://app.example.com
        │
        ▼
   1. Browser asks a DNS RESOLVER for app.example.com
        │
        ▼
   2. Resolver walks the DNS hierarchy:
        Root (.) ─► TLD (.com) ─► Authoritative name servers for example.com
                                          │
                                          ▼
                              ┌──────────────────────────────┐
                              │  ROUTE 53 HOSTED ZONE          │
                              │  example.com                   │
                              │   A/Alias  app   → CloudFront  │
                              │   A/Alias  api   → ALB         │
                              │   MX       @     → mail server │
                              │   TXT      @     → SPF/verify  │
                              │   NS / SOA (zone metadata)     │
                              └──────────────────────────────┘
        │
        ▼
   3. Resolver returns the IP/target ─► browser connects ─► (TLS via ACM) ─► your app
```

**In words:** DNS is the internet's phone book — it turns names (`app.example.com`) into addresses. **Route 53** is AWS's managed DNS: you **register** a domain (or bring one), create a **hosted zone** (the container for your records), and add **records** (A, CNAME, Alias, MX, TXT…) that tell resolvers where to send traffic. **Routing policies** and **health checks** let you control *which* answer is returned and route around failures.

---

## 🔑 Route 53 in One Line per Topic

| Topic | One-liner |
|-------|-----------|
| **DNS Basics** | The system that resolves names → IP addresses |
| **Domain Registration** | Buy/manage a domain name (Route 53 is also a registrar) |
| **Hosted Zone** | The container of DNS records for a domain |
| **A Record** | Maps a name → an IPv4 address (AAAA = IPv6) |
| **CNAME** | Maps a name → another name (not allowed at the zone apex) |
| **Alias** | Route 53's free A/AAAA-like record pointing to AWS resources, works at the apex |
| **MX** | Directs email to mail servers |
| **TXT** | Arbitrary text — SPF/DKIM/DMARC, domain verification |
| **Routing Policies** | How Route 53 chooses which record to return (simple/weighted/latency/failover/geo/multivalue) |
| **Health Checks** | Monitors endpoints so DNS can route away from unhealthy ones |
| **Failover Routing** | Automatically send traffic to a standby when primary is unhealthy |

---

## 🛠️ What You'll Wire Up

```
   example.com  ─Alias─►  CloudFront ─► S3 (React build)   [front end + HTTPS via ACM]
   api.example.com ─Alias─► ALB ─► EC2 (Node API)          [backend + HTTPS via ACM]
   @ MX ─► email provider     @ TXT ─► SPF/domain verify
   Health checks + failover ─► standby Region/endpoint
```
Full step-by-step in [02-architectures.md](02-architectures.md) and [03-labs.md](03-labs.md).

---

## 📌 Conventions
- 🛠️ = run this · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `example.com` = your domain · the **apex/root/zone apex** = `example.com` with no subdomain

---

## 📖 Official References
- Route 53 docs: https://docs.aws.amazon.com/route53/
- Routing policies: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html
- Health checks: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html
- Pricing: https://aws.amazon.com/route53/pricing/

---

*Start with [01-route53-core-concepts.md](01-route53-core-concepts.md).* 🚀

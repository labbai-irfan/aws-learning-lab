# Phase 13 — Advanced AWS: Enterprise Cloud Architecture

> A production-grade, architect-level course covering **CloudFront · ElastiCache/Redis · SQS · SNS · Terraform · CloudFormation · WAF · Shield · Organizations · Multi-Account Strategy** — plus full enterprise, multi-region, DR, SaaS, and DevOps architecture blueprints.

Authored as a structured program by a **Principal Cloud Architect**. Builds on all prior phases (EC2, S3, RDS, CloudWatch, VPC, Security, ELB, CI/CD). Every module contains architecture diagrams, production-grade code, IaC examples, and real-world patterns.

---

## 🎯 Who This Is For
- Cloud architects and senior engineers designing **enterprise-scale AWS systems**.
- DevOps / Platform engineers implementing **Terraform or CloudFormation** at scale.
- Anyone preparing for **AWS Solutions Architect Professional / DevOps Pro / Security Specialty** certification or senior technical interviews.

**Prerequisites:** All previous phases (1–8) or equivalent hands-on AWS experience.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here | [README.md](README.md) | 20 min |
| 1 | CloudFront — Global CDN & Edge | [01-cloudfront.md](01-cloudfront.md) | 3 hrs |
| 2 | ElastiCache & Redis — Caching at Scale | [02-elasticache-redis.md](02-elasticache-redis.md) | 3 hrs |
| 3 | SQS & SNS — Messaging & Events | [03-sqs-sns.md](03-sqs-sns.md) | 3 hrs |
| 4 | Terraform — IaC for AWS | [04-terraform.md](04-terraform.md) | 4 hrs |
| 5 | CloudFormation — Native IaC | [05-cloudformation.md](05-cloudformation.md) | 3 hrs |
| 6 | WAF & Shield — Edge Security | [06-waf-shield.md](06-waf-shield.md) | 2 hrs |
| 7 | Organizations & Multi-Account Strategy | [07-organizations-multi-account.md](07-organizations-multi-account.md) | 3 hrs |
| 8 | Enterprise Architecture Patterns | [08-enterprise-architecture.md](08-enterprise-architecture.md) | 4 hrs |
| 9 | Multi-Region Architecture & Disaster Recovery | [09-multi-region-dr.md](09-multi-region-dr.md) | 4 hrs |
| 10 | Scalability Design | [10-scalability-design.md](10-scalability-design.md) | 3 hrs |
| 11 | Security Architecture | [11-security-architecture.md](11-security-architecture.md) | 3 hrs |
| 12 | DevOps Architecture | [12-devops-architecture.md](12-devops-architecture.md) | 3 hrs |
| 13 | SaaS & Multi-Tenant Architecture | [13-saas-multi-tenant.md](13-saas-multi-tenant.md) | 3 hrs |
| 14 | Enterprise Case Studies | [14-enterprise-case-studies.md](14-enterprise-case-studies.md) | 3 hrs |
| 15 | Troubleshooting Handbook | [15-troubleshooting-handbook.md](15-troubleshooting-handbook.md) | 2 hrs |
| 16 | 200 Interview Questions | [16-200-interview-questions.md](16-200-interview-questions.md) | 4 hrs |
| 17 | 200 MCQs | [17-200-mcqs.md](17-200-mcqs.md) | 4 hrs |
| 18 | Cheat Sheet (1-page revision) | [18-cheatsheet.md](18-cheatsheet.md) | 30 min |
| 19 | **Capstone:** Production HRMS Infrastructure | [project/README.md](project/README.md) | 10+ hrs |

**Total:** ~60 hours.

---

## 📚 Core Topics

| Service / Topic | Module | What You'll Master |
|---|---|---|
| **CloudFront** | 1 | Distributions, origins, caching, Lambda@Edge, signed URLs, geo-restriction |
| **ElastiCache / Redis** | 2 | Cluster mode, replication groups, TTL strategy, cache patterns, failover |
| **SQS** | 3 | Standard vs FIFO, DLQ, visibility timeout, fan-out, deduplication |
| **SNS** | 3 | Topics, subscriptions, fan-out, filtering, mobile push, cross-account |
| **Terraform** | 4 | Providers, modules, state, workspaces, remote backends, CI/CD pipelines |
| **CloudFormation** | 5 | Templates, stacks, StackSets, drift, nested stacks, CDK |
| **WAF** | 6 | Web ACLs, managed rules, rate limiting, IP sets, bot control |
| **Shield** | 6 | Standard vs Advanced, DDoS protection, Route 53, SRT |
| **Organizations** | 7 | SCPs, OUs, consolidated billing, account vending, Control Tower |
| **Multi-Account** | 7 | Landing Zone, security account, log archive, network hub |

---

## 🏗️ Architecture Blueprints

| Blueprint | Module |
|---|---|
| Enterprise Architecture (Hub-Spoke, Transit Gateway) | [08](08-enterprise-architecture.md) |
| Multi-Region Active-Active / Active-Passive | [09](09-multi-region-dr.md) |
| Disaster Recovery (RTO/RPO matrix) | [09](09-multi-region-dr.md) |
| Scalability (auto-scaling, caching, async, partitioning) | [10](10-scalability-design.md) |
| Security (Zero Trust, defense in depth, CSPM) | [11](11-security-architecture.md) |
| DevOps (GitOps, blue/green, canary, platform engineering) | [12](12-devops-architecture.md) |
| SaaS Multi-Tenant (silo/pool/bridge, data isolation) | [13](13-saas-multi-tenant.md) |

---

## 🏭 Capstone: Production HRMS Infrastructure

Terraform + CloudFormation for a **real HRMS** with:
```
   Multi-Account (Org)
     ├─ Network Account    VPC · Transit Gateway · Direct Connect stub
     ├─ Security Account   GuardDuty · Security Hub · Config · WAF · Shield Adv
     ├─ Log Archive        CloudTrail · VPC Flow Logs · Config Snapshots
     └─ HRMS Prod          CloudFront → ALB → ECS (Fargate) → RDS Multi-AZ
                           ElastiCache Redis · SQS payroll queue · SNS alerts
                           Terraform IaC · CodePipeline CI/CD · CloudWatch stack
```
Full Terraform code + CloudFormation templates in [project/](project/).

---

## 📌 Conventions
- 🛠️ = command · 💰 = cost · ⚠️ = gotcha · 🔒 = security · 💡 = tip · 🏗️ = architecture decision
- All IaC examples: Terraform ≥ 1.5, AWS provider ≥ 5.x, CloudFormation YAML.
- Account IDs / ARNs use placeholders (`ACCT`, `REGION`).

---

*Start with [01-cloudfront.md](01-cloudfront.md).* 🚀

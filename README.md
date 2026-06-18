# AWS Mastery Roadmap — Beginner to Advanced Cloud Architect & DevOps Engineer

> A complete, self-paced, **production-grade** AWS curriculum: 13 sequenced phases that take you from "what is the cloud?" to designing and deploying enterprise, multi-account, multi-region architectures. Every phase has plain-English notes, ASCII architecture diagrams, real CLI/code, hands-on labs, MCQs, interview questions, scenarios, troubleshooting, and a hands-on project.

Built around a real-world **HRMS** application (React + TypeScript + Vite · Node.js + Express + Prisma · MySQL) so every concept maps to something you actually ship.

---

## 🗺️ The Learning Path (follow in order)

> The folder numbers **are** the curriculum order. Each phase builds on the ones before it.

| # | Phase | What you learn | Key services |
|---|-------|----------------|--------------|
| 01 | [AWS Fundamentals](01-aws-fundamentals/README.md) | Cloud concepts, global infra, shared responsibility, accounts, billing | Regions/AZs, IAM intro, Free Tier, Budgets |
| 02 | [IAM & Security](02-iam-security/README.md) | Least-privilege from day one: users, roles, policies, KMS, secrets, guardrails, incident response | IAM, KMS, Secrets Manager, Organizations/SCP |
| 03 | [EC2 (Compute)](03-ec2/README.md) | Launch, secure & deploy a full-stack app on a server | EC2, EBS, AMI, Security Groups, Nginx, PM2 |
| 04 | [VPC & Networking](04-vpc-networking/README.md) | Build the private network everything else lives in | VPC, subnets, route tables, NAT, SG/NACL |
| 05 | [S3 (Storage)](05-s3/README.md) | Object storage, static hosting, presigned URLs, lifecycle | S3, CloudFront (intro), lifecycle, encryption |
| 06 | [RDS (Databases)](06-rds/README.md) | Managed MySQL, migrate from local, Prisma, backups, HA | RDS MySQL, Multi-AZ, RDS Proxy, snapshots |
| 07 | [ELB & Auto Scaling](07-elb-autoscaling/README.md) | High availability, health checks, TLS, scaling fleets | ALB, NLB, Target Groups, ACM, Auto Scaling |
| 08 | [Route 53 (DNS)](08-route53/README.md) | Domains, records, routing policies, failover | Route 53, alias records, health checks |
| 09 | [CloudWatch & Monitoring](09-cloudwatch/README.md) | Metrics, logs, dashboards, alarms, alerting, playbooks | CloudWatch, Logs Insights, Alarms, SNS |
| 10 | [Serverless](10-serverless/README.md) | Event-driven compute & messaging | Lambda, API Gateway, EventBridge, SQS, SNS, Step Functions |
| 11 | [Docker & ECS/Fargate](11-docker-ecs/README.md) | Containerize and run microservices on AWS | Docker, ECR, ECS, Fargate, task definitions |
| 12 | [CI/CD](12-cicd/README.md) | Automated build/test/deploy, blue-green & canary | GitHub Actions, CodeBuild/Deploy/Pipeline |
| 13 | [Advanced AWS](13-advanced-aws/README.md) | Edge, caching, IaC, multi-account, DR, enterprise & SaaS architecture | CloudFront, ElastiCache, WAF/Shield, Terraform, CloudFormation, Organizations |

**Estimated total:** ~300–350 hours of focused study + labs.

---

## 🧭 Why this order? (dependency graph)

```
01 Fundamentals
      │
02 IAM & Security ───────────── (used by every phase below)
      │
03 EC2 ──► 04 VPC ──► 05 S3 ──► 06 RDS
                         │          │
                         └────► 07 ELB + Auto Scaling ──► 08 Route 53
                                          │
                                09 CloudWatch & Monitoring
                                          │
                                   10 Serverless
                                          │
                         11 Docker/ECS ──► 12 CI/CD
                                          │
                                  13 Advanced AWS (IaC, DR, multi-account)
```

- **Security (02) comes early** — IAM, key pairs and security groups are used from EC2 onward.
- **VPC (04) comes before RDS (06)** — databases need private subnets and DB subnet groups.
- **Docker/ECS (11) comes before CI/CD (12)** — the CI/CD labs deploy containers to ECS.

This corrected sequence is the output of a full repository audit — see **[REPOSITORY-AUDIT-AND-ROADMAP.md](REPOSITORY-AUDIT-AND-ROADMAP.md)** for the reasoning, gap analysis, and roadmap.

---

## 🎓 Certification Tracks

Pick a target and follow the phases that matter most for it.

| Certification | Phases to focus on | This repo's readiness |
|---|---|---|
| **Cloud Practitioner (CLF-C02)** | 01, 02, 03, 05, 06 + billing | ~88% — exam-ready |
| **Solutions Architect Associate (SAA-C03)** | 01–13 (breadth) | ~82% — close remaining breadth + mocks |
| **Developer Associate (DVA-C02)** | 02, 10, 12 (DynamoDB, Cognito, X-Ray, SAM) | ~82% — strong; add timed mocks |
| **DevOps Engineer Pro (DOP-C02)** | 09, 11, 12, 13 | ~66% — in progress |

**➡️ Full exam-domain → phase/file mapping and study plans: [CERTIFICATION-GUIDE.md](CERTIFICATION-GUIDE.md).**
Original readiness breakdown: [REPOSITORY-AUDIT-AND-ROADMAP.md](REPOSITORY-AUDIT-AND-ROADMAP.md#phase-8--production--certification-readiness).

---

## 🏢 Building the HRMS Project Alongside

This stack — **React/TS/Vite + Node/Express/Prisma + MySQL** — is wired into the curriculum. Each phase contributes infrastructure you actually use. **➡️ Step-by-step build track: [HRMS-TRACK.md](HRMS-TRACK.md)** (the exact task to do to *your* app in each phase).

| Phase | HRMS contribution |
|---|---|
| 03 EC2 | First deploy of the Express API + Vite build on a single box |
| 04 VPC | Private subnets for MySQL, public subnets for the load balancer |
| 05 S3 | Employee documents, payslip PDFs, avatars, static SPA hosting |
| 06 RDS | Migrate your local MySQL → RDS MySQL with Prisma |
| 07 ELB | HTTPS + high availability for the API |
| 08 Route 53 | `hrms.yourdomain.com` + failover |
| 09 CloudWatch | API/DB/payroll-job alarms and dashboards |
| 10 Serverless | Async payroll runs, notifications, report generation |
| 11 Docker/ECS | Containerized, autoscaling microservices |
| 12 CI/CD | Zero-downtime deploys |
| 13 Advanced | CloudFront SPA, ElastiCache sessions, SQS payroll queue, WAF, Terraform IaC |

**Production target architecture:**
```
Route 53 → CloudFront (Vite SPA + S3) ─┐
                                        ├→ ALB → ECS Fargate (Express+Prisma) → RDS MySQL Multi-AZ
WAF/Shield ─────────────────────────────┘            │              │
                                          ElastiCache Redis     SQS (payroll) → Lambda workers
                              CloudWatch + SNS alerts · CI/CD · Terraform IaC
```

---

## 📁 Repository Conventions

Each phase folder follows a consistent content checklist (see **[STANDARDS.md](STANDARDS.md)**):

```
NN-phase-name/
├── README.md                 ← start here: roadmap, prerequisites, mental model
├── 01..NN-*.md               ← notes, architecture, cost, security, labs, troubleshooting
├── NN-100-mcqs.md            ← practice MCQs (where present)
├── NN-100-interview-questions.md
├── NN-50-scenario-questions.md
└── project/ (or projects/)   ← hands-on capstone(s)
```

**Symbol legend used throughout:** 💡 tip · ⚠️ gotcha · 🛠️ hands-on · 💰 cost · 🔒 security · 🏗️ architecture decision.

**Quick navigation:** 🔎 [SERVICES-INDEX.md](SERVICES-INDEX.md) — *"where is service X taught?"* · 📖 [GLOSSARY.md](GLOSSARY.md) — key terms · 📐 [STANDARDS.md](STANDARDS.md) — conventions.

---

## 🚀 How to Use This Repo

1. **Start at [Phase 01](01-aws-fundamentals/README.md)** and work the folders in numeric order.
2. Read each phase's `README.md` first — it's the map for that phase.
3. Do the **labs** and **project** in each phase; learning sticks when you build.
4. Test yourself with the **MCQs / interview / scenario** files before moving on.
5. Building the HRMS app? Follow the per-phase HRMS contributions above.

---

## 📌 Repository Status & Roadmap

This repo was audited and restructured on **2026-06-17** (duplicate phase numbers resolved, dependency order corrected, broken links fixed), then filled out: every phase now has notes, architecture, labs, troubleshooting, a cheat sheet, MCQs/interview practice, and a project; new modules added (DynamoDB, Auto Scaling, Cognito, X-Ray, Systems Manager, AWS Config, EFS/FSx, Kinesis, SAM/Beanstalk); plus a [services index](SERVICES-INDEX.md), [glossary](GLOSSARY.md), and [certification guide](CERTIFICATION-GUIDE.md). A **[CI guard](.github/workflows/repo-guard.yml)** enforces no broken links / duplicate phase numbers on every push. The original audit and remaining external items (timed mock exams, a few SAA breadth specialties) are tracked in the **[Improvement Roadmap](REPOSITORY-AUDIT-AND-ROADMAP.md#final--improvement-roadmap)**.

## 📖 Official AWS References

- [AWS Documentation](https://docs.aws.amazon.com/) · [Free Tier](https://aws.amazon.com/free/) · [Pricing Calculator](https://calculator.aws/) · [Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

*License: content [CC BY 4.0](LICENSE), code samples MIT. Start learning → [Phase 01 — AWS Fundamentals](01-aws-fundamentals/README.md). 🚀*

# Phase 03 — Amazon EC2 Complete Learning Repository

> A hands-on, production-focused course on **Amazon EC2 (Elastic Compute Cloud)** — from first instance launch to deploying a real **React + Node.js + MySQL** application with Nginx, PM2, SSL, and a custom domain.

Authored as a structured program by an **AWS Compute Specialist**. Builds on [Phase 01 — AWS Fundamentals](../01-aws-fundamentals/README.md). Every module has explanations, diagrams, real commands, and practice questions.

---

## 🎯 Who This Is For
- Anyone who finished Phase 01 (AWS Fundamentals) and wants real compute skills.
- Developers who need to **deploy full-stack apps** on AWS.
- Candidates preparing for **AWS Solutions Architect / SysOps Associate** and DevOps interviews.

**Prerequisites:** An AWS account with MFA + a billing budget (see [Phase 01 setup guide](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Basic Linux/terminal comfort helps but isn't required — Module 5 teaches it.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | EC2 Core Concepts (all topics) | [01-ec2-core-concepts.md](01-ec2-core-concepts.md) | 4 hrs |
| 2 | Complete EC2 Architecture + Diagrams | [02-ec2-architecture.md](02-ec2-architecture.md) | 1 hr |
| 3 | Instance Selection Guide | [03-instance-selection-guide.md](03-instance-selection-guide.md) | 1 hr |
| 4 | Cost Calculation | [04-cost-calculation.md](04-cost-calculation.md) | 1 hr |
| 5 | SSH + Linux Administration | [05-ssh-and-linux-admin.md](05-ssh-and-linux-admin.md) | 2 hrs |
| 6 | Nginx + PM2 Setup | [06-nginx-and-pm2-setup.md](06-nginx-and-pm2-setup.md) | 2 hrs |
| 7 | Production Deployment (React, Node, MySQL, SSL, Domain) | [07-production-deployment-guide.md](07-production-deployment-guide.md) | 3 hrs |
| 8 | Troubleshooting Guide | [08-troubleshooting-guide.md](08-troubleshooting-guide.md) | 1 hr |
| 9 | 100 MCQs | [09-100-mcqs.md](09-100-mcqs.md) | 2 hrs |
| 10 | 100 Interview Questions | [10-100-interview-questions.md](10-100-interview-questions.md) | 2 hrs |
| 11 | 50 Production Scenarios | [11-50-production-scenarios.md](11-50-production-scenarios.md) | 2 hrs |
| 12 | **Capstone Project:** React + Node + MySQL on EC2 | [project/README.md](project/README.md) | 6+ hrs |

**Total:** ~30 hours.

---

## 📚 Topics Covered

**Core EC2 building blocks** (Module 1)
- EC2 Fundamentals · AMI · Instance Types · Launch Templates · Security Groups · Key Pairs · Elastic IP · EBS · Auto Scaling · Placement Groups · User Data

**Operations & deployment**
- SSH · Linux Administration (Module 5)
- Nginx · PM2 (Module 6)
- React deployment · Node.js deployment · MySQL connection · SSL setup · Domain mapping (Module 7)

**Decision & analysis**
- Complete EC2 architecture (Module 2) · Instance selection (Module 3) · Cost calculation (Module 4) · Troubleshooting (Module 8)

**Practice**
- 100 MCQs · 100 interview questions · 50 production scenarios · 1 capstone project

---

## ⚡ EC2 Mental Model (60-second overview)

```
                    AMI (template: OS + software)
                         |
                    launches into
                         v
   +-------------------- EC2 INSTANCE --------------------+
   |  Instance Type (CPU/RAM/network: t3.micro, m5.large) |
   |  Key Pair (SSH login)                                |
   |  User Data (boot-time script)                        |
   |  +----------------+   +----------------------------+ |
   |  | Root EBS volume|   | Extra EBS data volumes     | |
   |  +----------------+   +----------------------------+ |
   +------------------------------------------------------+
        |                         |                |
   Security Group         Elastic IP (static)   Placement Group
   (virtual firewall)     public address        (HW placement)
        |
   Launch Template -> Auto Scaling Group -> many instances across AZs
        |
   Load Balancer in front for HA + scale
```

**In words:** An **AMI** is a template. You launch it as an **instance** of a chosen **instance type**, log in with a **key pair** over **SSH**, optionally bootstrap with **user data**, attach **EBS** storage, control traffic with a **security group**, give it a stable **Elastic IP**, and scale it with **Launch Templates + Auto Scaling** behind a load balancer.

---

## 🛠️ What You'll Build (Capstone)

A production-style deployment:
```
   Internet ─► Route 53 (domain) ─► Nginx (443, Let's Encrypt SSL)
                                       │  serves React static build (/)
                                       └► reverse-proxy /api ─► Node.js (PM2) :5000 ─► MySQL :3306
```
Full step-by-step commands in [project/README.md](project/README.md).

---

## 📌 Conventions
- 🛠️ = run this command · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `$` = run as normal user · `#` = run as root/sudo

---

## 📖 Official References
- EC2 docs: https://docs.aws.amazon.com/ec2/
- EC2 instance types: https://aws.amazon.com/ec2/instance-types/
- EC2 pricing: https://aws.amazon.com/ec2/pricing/
- Pricing calculator: https://calculator.aws/

---

*Start with [01-ec2-core-concepts.md](01-ec2-core-concepts.md).* 🚀

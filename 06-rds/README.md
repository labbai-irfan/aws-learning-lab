# Phase 06 — Amazon RDS Complete Learning Repository

> A hands-on, production-focused course on **Amazon RDS (Relational Database Service)** — from your first managed database to running a real **HRMS** application on a Multi-AZ MySQL cluster with read replicas, automated backups, point-in-time recovery, Prisma, and connection pooling.

Authored as a structured program by an **AWS Database Architect**. Builds on [Phase 03 — Amazon EC2](../03-ec2/README.md) and [Phase 05 — Amazon S3](../05-s3/README.md). Every module has explanations, diagrams, real AWS CLI / SQL commands, and practice questions.

---

## 🎯 Who This Is For
- Developers who deploy apps on EC2 and want a **managed, highly-available database** instead of self-hosting MySQL.
- Backend engineers migrating a **local MySQL** database into the cloud.
- Candidates preparing for **AWS Solutions Architect / Database Specialty / SysOps** interviews.

**Prerequisites:** An AWS account with MFA + a billing budget, a VPC with private subnets (covered in [Phase 04 — VPC](../04-vpc-networking/README.md)), and basic SQL comfort.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | RDS Core Concepts (all topics) | [01-rds-core-concepts.md](01-rds-core-concepts.md) | 4 hrs |
| 2 | Engines: MySQL · PostgreSQL · MariaDB | [02-engines-mysql-postgres-mariadb.md](02-engines-mysql-postgres-mariadb.md) | 2 hrs |
| 3 | Production Database Architecture + Diagrams | [03-production-architecture.md](03-production-architecture.md) | 2 hrs |
| 4 | Migration from Local MySQL | [04-migration-from-local-mysql.md](04-migration-from-local-mysql.md) | 2 hrs |
| 5 | Prisma Integration + Connection Pooling | [05-prisma-and-connection-pooling.md](05-prisma-and-connection-pooling.md) | 2 hrs |
| 6 | Backup, Snapshots, PITR & Disaster Recovery | [06-backup-and-disaster-recovery.md](06-backup-and-disaster-recovery.md) | 2 hrs |
| 7 | Scaling & Cost Optimization | [07-scaling-and-cost-optimization.md](07-scaling-and-cost-optimization.md) | 2 hrs |
| 8 | Security Deep Dive | [08-security-guide.md](08-security-guide.md) | 2 hrs |
| 9 | Monitoring & Performance | [09-monitoring-guide.md](09-monitoring-guide.md) | 1 hr |
| 10 | Troubleshooting Guide | [10-troubleshooting-guide.md](10-troubleshooting-guide.md) | 1 hr |
| 11 | Hands-on Labs | [11-labs.md](11-labs.md) | 3 hrs |
| 12 | 100 MCQs | [12-100-mcqs.md](12-100-mcqs.md) | 2 hrs |
| 13 | 100 Interview Questions | [13-100-interview-questions.md](13-100-interview-questions.md) | 2 hrs |
| 14 | 50 Production Scenarios | [14-50-scenario-questions.md](14-50-scenario-questions.md) | 2 hrs |
| 15 | Cheat Sheet (1-page revision) | [15-cheatsheet.md](15-cheatsheet.md) | 30 min |
| 16 | **Capstone Project:** HRMS MySQL on RDS | [project/README.md](project/README.md) | 6+ hrs |

**Total:** ~35 hours.

---

## 📚 Topics Covered

**Core RDS building blocks** (Module 1)
- RDS Overview · DB Instances · Storage (gp3/io1/magnetic) · **Multi-AZ** · **Read Replicas** · **Parameter Groups** · Option Groups · Subnet Groups · **Automated Backups** · **Snapshots** · **Point-in-Time Recovery (PITR)** · **Failover** · **Monitoring** · **Security**

**Engines** (Module 2)
- MySQL · PostgreSQL · MariaDB — versions, feature differences, when to pick which, RDS vs Aurora

**Architecture & operations**
- Production architecture (Module 3) · Migration from local MySQL via mysqldump & DMS (Module 4) · Prisma + connection pooling (Module 5)

**Resilience & economics**
- Backup strategy · Disaster recovery / cross-region (Module 6) · Scaling & cost optimization (Module 7)

**Practice**
- 100 MCQs · 100 interview questions · 50 production scenarios · Labs · 1 capstone project (HRMS)

---

## ⚡ RDS Mental Model (60-second overview)

```
                 PARAMETER GROUP            OPTION GROUP
              (engine config knobs)     (extra features/plugins)
                       |                        |
                       v                        v
   +----------------------- RDS DB INSTANCE -----------------------+
   |  Engine (MySQL/PostgreSQL/MariaDB) + version                  |
   |  Instance class (db.t3.micro ... db.r6g.2xlarge)             |
   |  Storage (gp3 SSD, autoscaling) + IOPS                        |
   |  Endpoint: hrms.abc123.us-east-1.rds.amazonaws.com:3306       |
   +--------------------------------------------------------------+
        |                    |                       |
   DB Subnet Group      Security Group         Automated Backups
   (private subnets)    (port 3306 from app)   (1-35 days -> PITR)
        |
   MULTI-AZ: synchronous standby in another AZ  --(auto failover)-->
        |
   READ REPLICAS: async copies for read scaling / reporting
```

**In words:** You launch a **DB instance** of a chosen **engine** and **instance class**, place it in a **DB subnet group** (private subnets), lock it down with a **security group**, tune it with a **parameter group**, and connect via its **endpoint**. **Multi-AZ** gives you a synchronous standby for automatic **failover**. **Read replicas** scale reads. **Automated backups** + **snapshots** enable **point-in-time recovery**.

---

## 🛠️ What You'll Build (Capstone)

A production-style HRMS (Human Resource Management System) database:
```
   Internet ─► ALB ─► EC2 (Node.js + Prisma, PM2) ──┐
                                                     │ writes
                          MySQL 8.0 Multi-AZ  ◄──────┘
                          (primary AZ-a / standby AZ-b)
                                │ async
                                ▼
                          Read Replica (reporting / analytics)
                                │
                          Automated backups (7d) + manual snapshots + PITR
```
Full step-by-step build in [project/README.md](project/README.md).

---

## 🔑 The README sections you asked for — where to find them

| Requested topic | Module |
|---|---|
| Production Database Architecture | [03-production-architecture.md](03-production-architecture.md) |
| Migration from Local MySQL | [04-migration-from-local-mysql.md](04-migration-from-local-mysql.md) |
| Prisma Integration | [05-prisma-and-connection-pooling.md](05-prisma-and-connection-pooling.md) |
| Connection Pooling | [05-prisma-and-connection-pooling.md](05-prisma-and-connection-pooling.md) |
| Backup Strategy | [06-backup-and-disaster-recovery.md](06-backup-and-disaster-recovery.md) |
| Disaster Recovery | [06-backup-and-disaster-recovery.md](06-backup-and-disaster-recovery.md) |
| Scaling Strategy | [07-scaling-and-cost-optimization.md](07-scaling-and-cost-optimization.md) |
| Cost Optimization | [07-scaling-and-cost-optimization.md](07-scaling-and-cost-optimization.md) |

---

## 📌 Conventions
- 🛠️ = run this command · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `$` = shell · `SQL>` = run in a database client · `aws rds` = AWS CLI

---

## 📖 Official References
- RDS docs: https://docs.aws.amazon.com/rds/
- RDS for MySQL: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html
- RDS pricing: https://aws.amazon.com/rds/pricing/
- Pricing calculator: https://calculator.aws/
- AWS DMS (migration): https://docs.aws.amazon.com/dms/

---

*Start with [01-rds-core-concepts.md](01-rds-core-concepts.md).* 🚀

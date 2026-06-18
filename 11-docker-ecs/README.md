# Phase 11 — Docker & Amazon ECS Complete Learning Repository

> A hands-on, production-focused course on **containers** — from your first `docker run` to deploying a real multi-service **HRMS (Human Resource Management System)** on **Amazon ECS + Fargate** behind an Application Load Balancer, with **ECR**, **Task Definitions**, **Services**, and **Clusters**.

Authored as a structured program by a **Container Platform Architect**. Builds on [Phase 03 — EC2](../03-ec2/README.md) and [Phase 07 — ELB](../07-elb-autoscaling/README.md). Every module has explanations, diagrams, real commands, and practice.

---

## 🎯 Who This Is For
- Developers who can deploy on a single EC2 box (Phase 03) and now want **portable, reproducible, scalable** deployments.
- Teams moving from a monolith on one server to **microservices on a managed container platform**.
- Candidates preparing for **AWS Solutions Architect / DevOps** interviews and the **Docker** ecosystem.

**Prerequisites:** Docker installed locally (`docker --version`), an AWS account with the CLI configured ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)), and comfort with the Linux/SSH basics from [Phase 03 Module 5](../03-ec2/05-ssh-and-linux-admin.md).

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | Docker Fundamentals | [01-docker-fundamentals.md](01-docker-fundamentals.md) | 2 hrs |
| 2 | Images (Dockerfile, layers, registries) | [02-images.md](02-images.md) | 2 hrs |
| 3 | Containers (lifecycle, run flags, exec) | [03-containers.md](03-containers.md) | 2 hrs |
| 4 | Volumes (persistent data) | [04-volumes.md](04-volumes.md) | 1 hr |
| 5 | Networks (bridge, host, compose, awsvpc) | [05-networks.md](05-networks.md) | 1.5 hrs |
| 6 | Container & Microservices Architecture | [06-container-architecture.md](06-container-architecture.md) | 2 hrs |
| 7 | Amazon ECS (concepts, launch types) | [07-ecs.md](07-ecs.md) | 2 hrs |
| 8 | AWS Fargate (serverless containers) | [08-fargate.md](08-fargate.md) | 1.5 hrs |
| 9 | Amazon ECR (private registry) | [09-ecr.md](09-ecr.md) | 1 hr |
| 10 | Task Definitions | [10-task-definitions.md](10-task-definitions.md) | 2 hrs |
| 11 | Services (scheduling, ALB, autoscaling) | [11-services.md](11-services.md) | 2 hrs |
| 12 | Clusters (capacity, scaling, organization) | [12-clusters.md](12-clusters.md) | 1.5 hrs |
| 13 | Troubleshooting Handbook | [13-troubleshooting-handbook.md](13-troubleshooting-handbook.md) | 2 hrs |
| 14 | 100 MCQs | [14-100-mcqs.md](14-100-mcqs.md) | 2 hrs |
| 15 | 100 Interview Questions | [15-100-interview-questions.md](15-100-interview-questions.md) | 2 hrs |
| 16 | Cheat Sheet (1-page revision) | [16-cheatsheet.md](16-cheatsheet.md) | 30 min |
| 17 | **Capstone:** HRMS Container Deployment on ECS/Fargate | [project/README.md](project/README.md) | 8+ hrs |

**Total:** ~34 hours.

---

## 📚 Topics Covered

**Docker core** (Modules 1–5)
- Docker Fundamentals · Images · Containers · Volumes · Networks

**Architecture** (Module 6)
- Container Architecture · Microservices Architecture · 12-factor mapping

**AWS container platform** (Modules 7–12)
- ECS · Fargate · ECR · Task Definitions · Services · Clusters

**Practice & operations**
- Troubleshooting Handbook (Module 13) · HRMS Capstone Project (Module 14)

---

## ⚡ Container Mental Model (60-second overview)

```
   Dockerfile  (recipe: FROM, COPY, RUN, CMD)
        │  docker build
        ▼
     IMAGE  (immutable, layered, tagged) ──push──►  ECR (registry)
        │  docker run / ECS pulls it
        ▼
   CONTAINER  (running process, isolated namespace + cgroups)
        │
   ┌────┴───────────────┬──────────────────┐
   ▼                    ▼                   ▼
  VOLUME            NETWORK            ENV / SECRETS
 (persist data)  (talk to peers)   (config injected)
```

**On AWS:** A **Task Definition** says *which image(s), how much CPU/RAM, ports, env, secrets, logs*. A **Service** keeps N copies of that task running, registers them with an **ALB**, and **autoscales** them. Tasks run on a **Cluster** — either **Fargate** (serverless, no EC2 to manage) or **EC2** capacity you own.

```
 Cluster ─► Service ─► Task(s) ─► Container(s)  ◄── Task Definition (the blueprint)
                          │
                  runs on Fargate OR EC2
```

---

## 🛠️ What You'll Build (Capstone — HRMS)

A production-style **microservices HRMS** on ECS/Fargate:

```
 Internet ─► ALB (443, ACM cert) ──► /            ─► frontend service (React + Nginx)
                                  ├─► /api/auth/*  ─► auth-service (Node)
                                  ├─► /api/emp/*   ─► employee-service (Node)
                                  └─► /api/pay/*   ─► payroll-service (Node)
                                                          │
                                                          ▼
                                              Amazon RDS (MySQL)  +  ElastiCache
   All images in ECR · tasks on Fargate · logs in CloudWatch · secrets in Secrets Manager
```

Full step-by-step in [project/README.md](project/README.md).

---

## 📌 Conventions
- 🛠️ = run this · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `$` = run as normal user · `#` = run as root/sudo · `(local)` = on your laptop · `(aws)` = AWS CLI

---

## 📖 Official References
- Docker docs: https://docs.docker.com/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Amazon ECS: https://docs.aws.amazon.com/ecs/
- AWS Fargate: https://docs.aws.amazon.com/AmazonECS/latest/userguide/what-is-fargate.html
- Amazon ECR: https://docs.aws.amazon.com/ecr/
- ECS pricing / Fargate pricing: https://aws.amazon.com/fargate/pricing/

---

*Start with [01-docker-fundamentals.md](01-docker-fundamentals.md).* 🚀

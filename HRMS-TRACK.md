# HRMS Build Track — Apply Each Phase to Your Real Project

> A parallel track for shipping your **HRMS** app (React + TypeScript + Vite · Node.js + Express + Prisma · MySQL) to AWS. For each phase, here's the **concrete task to do on your own app** — so you learn by building the thing you're actually shipping.

Work it alongside the [main roadmap](README.md). ✅ each item as you go.

| Phase | Do this to your HRMS app | Outcome |
|---|---|---|
| [01 Fundamentals](01-aws-fundamentals/README.md) | Create the AWS account, enable MFA, set a **Budget** alert, pick a Region. | Account ready, spend guarded |
| [02 IAM & Security](02-iam-security/README.md) | Make a least-privilege **deploy/CI role** and an admin user; no root daily use. | Secure access from day one |
| [03 EC2](03-ec2/README.md) | Deploy Express API + Vite build on **one EC2** (Nginx + PM2 + HTTPS) as a first cut. | App live on a server |
| [04 VPC](04-vpc-networking/README.md) | Create a VPC: **public** subnets (LB/NAT) + **private** subnets (app/MySQL), 2 AZs. | Proper network foundation |
| [05 S3](05-s3/README.md) | Store **employee documents / payslip PDFs / avatars** in a private bucket; host the Vite SPA build. Use **pre-signed URLs** for uploads. | File storage + static hosting |
| [06 RDS](06-rds/README.md) | **Migrate your local MySQL → RDS MySQL** (Multi-AZ); point Prisma `DATABASE_URL` at it; `prisma migrate deploy`. Add **RDS Proxy** if you go serverless. | Managed, HA database |
| [07 ELB + Auto Scaling](07-elb-autoscaling/README.md) | Put the API behind an **ALB** (HTTPS via ACM) with an **ASG** across 2 AZs + `/api/health`. | HA, self-healing API tier |
| [08 Route 53](08-route53/README.md) | Point `hrms.yourdomain.com` + `api.…` at the ALB (ALIAS); add **failover** to a maintenance page. | Real domain + DR DNS |
| [09 CloudWatch + SSM](09-cloudwatch/README.md) | Alarms on API latency/5xx, DB CPU/connections, and the payroll job; logs in CloudWatch; **X-Ray** tracing; manage instances via **Session Manager** (no SSH). | Observability + safe ops |
| [10 Serverless](10-serverless/README.md) | Move async work off the API: **payroll runs, email/notifications, report generation** to Lambda + EventBridge + SQS. Add **Cognito** for login; **DynamoDB** for sessions/audit. | Event-driven + managed auth |
| [11 Docker / ECS](11-docker-ecs/README.md) | Containerize React + Express(+Prisma); push to **ECR**; run on **ECS Fargate** (one service per component) behind the ALB. | Portable, scalable containers |
| [12 CI/CD](12-cicd/README.md) | GitHub Actions (**OIDC**, no keys) → build/test → push image → deploy to ECS; **blue/green** for zero-downtime payroll-period deploys. | Automated, safe shipping |
| [13 Advanced](13-advanced-aws/README.md) | **CloudFront** in front of the SPA + S3; **ElastiCache Redis** for sessions; **SQS** payroll queue; **WAF** on `/login`; codify it all in **Terraform**. | Production-grade platform |

---

## Target production architecture
```
Route 53 → CloudFront (Vite SPA + S3 assets) ─┐
WAF / Shield ──────────────────────────────────┤
                                                ├→ ALB → ECS Fargate (Express + Prisma) → RDS MySQL Multi-AZ
Cognito (login → JWT) ──────────────────────────┘            │                 │
                                                   ElastiCache Redis      SQS (payroll) → Lambda workers
   CloudWatch + X-Ray + SNS alerts · CI/CD via GitHub Actions/CodePipeline · Terraform IaC · Secrets Manager
```

## Suggested order of attack
1. **MVP (phases 01–08):** account → IAM → EC2 → VPC → S3 → RDS → ALB → DNS. You now have a live, HA HRMS.
2. **Operate (09–10):** monitoring/ops, then offload async jobs + add real auth.
3. **Scale (11–13):** containerize, automate deploys, and add the edge/cache/IaC layer.

> Security is continuous: apply the [Phase 02 baseline](02-iam-security/project/README.md) and [HRMS Security Design](02-iam-security/06-hrms-security-design.md) throughout, not at the end.

---
*See also: [README.md](README.md) (master roadmap) · [SERVICES-INDEX.md](SERVICES-INDEX.md) · [CERTIFICATION-GUIDE.md](CERTIFICATION-GUIDE.md).*

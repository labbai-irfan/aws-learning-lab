# Capstone Project — Enterprise HRMS on Advanced AWS

> Build a production-grade, multi-account HRMS platform incorporating CloudFront, ElastiCache, SQS, WAF, Terraform, and multi-region DR. This is the culmination of all Phase 13 modules.

---

## Architecture overview

```
                              INTERNET
                                 │
                    ┌────────────▼────────────┐
                    │   Route 53 (latency)     │
                    │  us-east-1 / eu-west-1   │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   AWS WAF Web ACL        │
                    │  (OWASP, rate-limit,     │
                    │   BotControl — us-east-1)│
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │      CloudFront          │
                    │  Distribution            │
                    │  ├── /static/* → S3+OAC  │
                    │  └── /api/*   → ALB      │
                    └────────────┬────────────┘
                                 │
               ┌─────────────────▼─────────────────┐
               │         Application Load Balancer   │
               │         (HTTPS only, SG: CF only)  │
               └─────────────────┬─────────────────┘
                                 │
               ┌─────────────────▼─────────────────┐
               │      ECS Fargate Cluster            │
               │  hrms-api (Node/Prisma)             │
               │  ├── target-tracking CPU 60%        │
               │  └── RDS Proxy for DB connections   │
               └─────┬──────────────────────────────┘
                     │
       ┌─────────────┼──────────────┐
       │             │              │
  ┌────▼───┐   ┌─────▼────┐  ┌────▼────────┐
  │ Aurora │   │ElastiCache│  │  SQS Queue  │
  │ MySQL  │   │  Redis    │  │ Payroll/    │
  │(Multi- │   │ Cluster   │  │ Leave/Email │
  │ AZ,    │   │ mode      │  │ + DLQ       │
  │ Global)│   │(tenant-ns)│  └────┬────────┘
  └────────┘   └──────────┘       │
                              ┌────▼────────┐
                              │ECS Fargate  │
                              │ Workers     │
                              │(SQS consumer│
                              │ auto-scale) │
                              └────────────┘

  MULTI-ACCOUNT:
  Management ─── Log Archive ─── Security Tooling
       │
  Network Hub (TGW)
       │
  ├── hrms-prod account  (above architecture)
  └── hrms-staging account (same, smaller)
```

---

## AWS Account structure

| Account | Purpose | Key Resources |
|---|---|---|
| Management | Billing, Org, Control Tower | No workloads |
| Log Archive | Immutable CloudTrail/Config logs | S3 (WORM), KMS |
| Security Tooling | GuardDuty admin, Security Hub, SIEM | GuardDuty, Security Hub |
| Network Hub | Transit Gateway, DNS, DX | TGW, Route 53 Resolver |
| hrms-prod | Production HRMS | Full stack (see above) |
| hrms-staging | Pre-production | Same IaC, smaller sizes |
| Sandbox | Developer experiments | Auto-cleanup, budget limit |

---

## Infrastructure components

### Networking
- VPC: 3 AZ, /16 CIDR, private/public/data subnets
- NAT Gateways: one per AZ (high availability)
- VPC Endpoints: S3, SQS, Secrets Manager, KMS, ECR, CloudWatch (no NAT GW needed)
- TGW attachment to Network Hub for cross-account communication

### Compute
- ECS Fargate cluster with Fargate Spot for workers
- Task definitions with Secrets Manager injection (no plaintext env vars)
- Target tracking auto-scaling: CPU 60% (web tasks), SQS queue depth (worker tasks)
- ECS Exec enabled for production debugging (with CloudTrail audit)

### Database
- Aurora MySQL 8.0 cluster, Multi-AZ, 3 AZs
- Aurora Global Database replica in eu-west-1 (< 1s lag)
- RDS Proxy: 2 endpoints (write + read-only)
- Automated backups: 35 days; manual snapshots: weekly

### Caching
- ElastiCache Redis 7 cluster mode (3 shards × 2 replicas)
- Key namespacing: `hrms:prod:{tenantId}:{entity}:{id}`
- TTL strategy: sessions 24h, employee data 15min, department data 1h

### Messaging
- SQS: `hrms-payroll`, `hrms-leave`, `hrms-notifications` (Standard)
- DLQ per queue with `maxReceiveCount=3`
- SNS topic `hrms-events` → fan-out to audit, email, analytics queues
- SQS worker ECS service: scales 0→50 tasks based on queue depth

### CDN
- CloudFront distribution: S3 (OAC, 1-year TTL for hashed assets) + ALB origin
- WAF Web ACL: AWSManagedRulesCommonRuleSet, SQLi rules, rate-limit 1000/5min/IP
- Cache policies: static (immutable), API (TTL=0, pass headers), SPA (short TTL)

### Security
- KMS CMKs: one per service (RDS, S3, SQS, SSM) rotated annually
- Secrets Manager: all credentials, rotated every 30 days
- IAM roles: task role (least-privilege per service), execution role (ECR/Secrets pull)
- WAF + Shield Standard (Shield Advanced if SLA requires)
- GuardDuty, Security Hub, Config, CloudTrail all enabled

### Observability
- CloudWatch: EMF metrics from ECS tasks (RequestCount, ErrorCount, Latency per route)
- Custom dashboard: 4-layer (user impact, app, infrastructure, database)
- Alarms: 5xx rate, p99 latency, DB connections, queue age, cache evictions
- Composite alarm → ops-page SNS → PagerDuty

---

## Terraform module structure

```
project/
├── terraform/
│   ├── main.tf                  # Root module (providers, remote state, module calls)
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Exported values
│   └── modules/
│       ├── vpc/                 # VPC, subnets, NAT GW, VPC endpoints
│       ├── ecs/                 # Cluster, task defs, services, auto-scaling
│       ├── aurora/              # Aurora cluster, RDS Proxy, subnet group
│       ├── elasticache/         # Redis cluster, parameter group, subnet group
│       ├── sqs/                 # Queues, DLQs, IAM permissions
│       ├── cloudfront/          # Distribution, cache policies, OAC
│       ├── waf/                 # Web ACL, rules, logging
│       └── security/            # KMS keys, Secrets Manager, IAM roles
└── cloudformation/
    └── hrms-stack.yaml          # Alternative: full stack in CloudFormation
```

---

## Deployment steps

### Prerequisites
```bash
# 1. Terraform state bucket + DynamoDB lock table (bootstrap once)
aws s3 mb s3://hrms-terraform-state-prod --region us-east-1
aws dynamodb create-table \
  --table-name hrms-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# 2. Set up OIDC provider for GitHub Actions (run from management account)
# See terraform/main.tf for OIDC resource
```

### First deploy
```bash
cd project/terraform
terraform init
terraform workspace new prod
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

### CI/CD pipeline (GitHub Actions)
```yaml
name: Deploy HRMS
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-terraform-role
          aws-region: us-east-1
      - run: terraform init && terraform plan && terraform apply -auto-approve
```

---

## Project modules completed

| Module | Topic | Status |
|---|---|---|
| 1 | CloudFront | ✅ |
| 2 | ElastiCache & Redis | ✅ |
| 3 | SQS & SNS | ✅ |
| 4 | Terraform | ✅ |
| 5 | CloudFormation | ✅ |
| 6 | WAF & Shield | ✅ |
| 7 | Organizations & Multi-Account | ✅ |
| 8 | Enterprise Architecture | ✅ |
| 9 | Multi-Region DR | ✅ |
| 10 | Scalability Design | ✅ |
| 11 | Security Architecture | ✅ |
| 12 | DevOps Architecture | ✅ |
| 13 | SaaS & Multi-Tenant | ✅ |
| 14 | Enterprise Case Studies | ✅ |
| 15 | Troubleshooting Handbook | ✅ |
| 16 | 200 Interview Questions | ✅ |
| 17 | 200 MCQs | ✅ |
| Project | This capstone | ✅ |

# Capstone Project — HRMS Container Deployment on ECS/Fargate

> A complete, copy-paste, end-to-end deployment of a **microservices HRMS (Human Resource Management System)**: a React/Nginx **frontend** plus three Node.js services — **auth**, **employee**, **payroll** — each containerized, pushed to **ECR**, and run as **ECS Services on Fargate** behind an **Application Load Balancer**, with **RDS (MySQL)** for data, **Secrets Manager** for credentials, and **CloudWatch** for logs.

This project ties together every module in Phase 11. By the end you'll have a live, load-balanced, autoscaling microservices app and the muscle memory to ship any container workload to AWS.

---

## 📐 Target Architecture

```
                              Internet
                                 │ https://hrms.example.com
                                 ▼
                    ┌──────── Application Load Balancer (ACM TLS, 443) ────────┐
                    │  /            → frontend-tg                                │
                    │  /api/auth/*  → auth-tg                                    │
                    │  /api/emp/*   → employee-tg                                │
                    │  /api/pay/*   → payroll-tg                                 │
                    └──┬───────────┬────────────┬───────────┬───────────────────┘
                       ▼           ▼            ▼           ▼
   ECS Cluster   ┌─frontend─┐ ┌─auth────┐ ┌─employee┐ ┌─payroll─┐
   "hrms-prod"   │ React+   │ │ Node    │ │ Node    │ │ Node    │   each = ECS Service
   (Fargate)     │ Nginx :80│ │ :5000   │ │ :5000   │ │ :5000   │   (desired count + autoscale)
                 └──────────┘ └────┬────┘ └────┬────┘ └────┬────┘
                                   └───────────┼───────────┘
                                               ▼ (private subnets)
                                    Amazon RDS (MySQL, Multi-AZ)
   Images: ECR · Logs: CloudWatch · Secrets: Secrets Manager · per-task Security Groups · NAT GW
```

---

## ✅ Prerequisites
- AWS account with the CLI configured + a Budget alert ([Phase 01 setup](../../01-aws-fundamentals/05-aws-account-setup-guide.md)).
- Docker installed locally; comfort with Modules 1–12.
- A VPC with **2 public subnets** (for the ALB + NAT) and **2 private subnets** (for tasks + RDS) across 2 AZs ([Phase 04 VPC](../../04-vpc-networking/README.md)). The default VPC works for a first pass.
- (Optional) a registered domain + ACM certificate for HTTPS ([Phase 08 Route 53](../../08-route53/README.md)).
- 💰 ALB (~$16/mo) + NAT GW (~$32/mo) + RDS + Fargate tasks. **This is the costliest capstone — tear it down when done (Step 10).**

This `project/` folder ships sample code:
```
project/
├── docker-compose.yml          # run the whole stack locally first
├── auth-service/      (Dockerfile, src/index.js, package.json)
├── employee-service/  (Dockerfile, src/index.js, package.json)
├── payroll-service/   (Dockerfile, src/index.js, package.json)
├── frontend/          (Dockerfile, nginx.conf, src/)
├── db/init.sql                 # schemas/seed for local MySQL
└── ecs/                        # task definitions, service + helper scripts
    ├── env.sh
    ├── 00-bootstrap.sh
    ├── auth.taskdef.json  employee.taskdef.json  payroll.taskdef.json  frontend.taskdef.json
    └── create-services.sh
```

---

## 🗺️ Steps Overview
1. Run the whole stack **locally** with Docker Compose (prove it works)
2. Create **ECR** repositories
3. **Build & push** all four images
4. Create the **RDS** database + **Secrets Manager** secret
5. Create the **ALB**, target groups, and listener rules
6. Create the **ECS cluster** + **task definitions**
7. Create the **ECS services** (behind the ALB)
8. Configure **autoscaling**
9. **Verify** end-to-end + map the domain (HTTPS)
10. **Clean up** (avoid charges)

> Tip: set your shell vars once — see [`ecs/env.sh`](ecs/env.sh) — and `source` it in every step.

---

## Step 1 — Run Locally First (Docker Compose)

Never debug in the cloud what you can debug on your laptop.

```bash
cd project
docker compose up --build -d
docker compose ps
# frontend on http://localhost:8080 ; services proxied under /api/*
curl http://localhost:8080/api/auth/health      # {"status":"ok","service":"auth"}
curl http://localhost:8080/api/emp/employees    # seeded employees
docker compose logs -f auth
docker compose down                              # (add -v to wipe the db volume)
```
This uses a local MySQL container + [`db/init.sql`](db/init.sql). In AWS we swap that container for **RDS**.

---

## Step 2 — Create ECR Repositories

```bash
source ecs/env.sh        # sets ACCOUNT, REGION, REGISTRY, CLUSTER, etc.

for svc in auth employee payroll frontend; do
  aws ecr create-repository \
    --repository-name hrms-$svc \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE \
    --region $REGION 2>/dev/null || echo "hrms-$svc exists"
done
aws ecr describe-repositories --query 'repositories[].repositoryName'
```

---

## Step 3 — Build & Push All Images

```bash
source ecs/env.sh
TAG=1.0.0

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $REGISTRY

for svc in auth employee payroll frontend; do
  dir=$([ "$svc" = "frontend" ] && echo frontend || echo $svc-service)
  docker build --platform linux/amd64 -t hrms-$svc:$TAG ./$dir
  docker tag  hrms-$svc:$TAG $REGISTRY/hrms-$svc:$TAG
  docker push $REGISTRY/hrms-$svc:$TAG
done
```
⚠️ `--platform linux/amd64` matters on Apple Silicon — Fargate is x86_64 by default ([M9 §5](../09-ecr.md)).

---

## Step 4 — RDS Database + Secrets Manager

```bash
source ecs/env.sh

# 1) a strong DB password in Secrets Manager (the app + tasks read this)
DB_PASS=$(openssl rand -base64 18 | tr -d '/+=')
aws secretsmanager create-secret --name hrms/db \
  --secret-string "{\"username\":\"hrmsadmin\",\"password\":\"$DB_PASS\"}"

# 2) RDS MySQL in private subnets (SG allows 3306 from the task SG — created in Step 6/0-bootstrap)
aws rds create-db-instance \
  --db-instance-identifier hrms-db \
  --engine mysql --engine-version 8.0 \
  --db-instance-class db.t3.micro \
  --allocated-storage 20 --storage-type gp3 \
  --master-username hrmsadmin --master-user-password "$DB_PASS" \
  --db-name hrms --multi-az \
  --db-subnet-group-name $DB_SUBNET_GROUP \
  --vpc-security-group-ids $RDS_SG \
  --no-publicly-accessible
# wait until available, then note the endpoint:
aws rds wait db-instance-available --db-instance-identifier hrms-db
aws rds describe-db-instances --db-instance-identifier hrms-db \
  --query 'DBInstances[0].Endpoint.Address' --output text   # ← DB_HOST for task defs
```
🔒 RDS is **not publicly accessible**; only tasks in the VPC reach it. Credentials live in Secrets Manager, injected per task ([M10 §4](../10-task-definitions.md)). Run [`db/init.sql`](db/init.sql) against it once (via a bastion or a one-off ECS migrate task).

---

## Step 5 — ALB, Target Groups, Listener Rules

```bash
source ecs/env.sh

# ALB in the public subnets
ALB_ARN=$(aws elbv2 create-load-balancer --name hrms-alb \
  --subnets $PUB_SUBNET_A $PUB_SUBNET_B --security-groups $ALB_SG \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# one target group per service (target-type=ip for Fargate, health check path)
for svc in frontend auth employee payroll; do
  port=$([ "$svc" = "frontend" ] && echo 80 || echo 5000)
  path=$([ "$svc" = "frontend" ] && echo / || echo /health)
  aws elbv2 create-target-group --name hrms-$svc-tg \
    --protocol HTTP --port $port --vpc-id $VPC_ID --target-type ip \
    --health-check-path $path --health-check-interval-seconds 30
done

# HTTP:80 listener → default to frontend; path rules → API services
# (in production add an HTTPS:443 listener with your ACM cert and redirect 80→443)
```
See [Phase 07 — ELB](../../07-elb-autoscaling/README.md) for listener-rule details. Path rules: `/api/auth/*`→auth-tg, `/api/emp/*`→employee-tg, `/api/pay/*`→payroll-tg, default→frontend-tg.

---

## Step 6 — Cluster + Task Definitions

```bash
source ecs/env.sh
bash ecs/00-bootstrap.sh    # creates cluster, IAM roles, log groups, security groups

# register each task definition (templates in ecs/*.taskdef.json — they reference
# $REGISTRY, the DB endpoint, and the Secrets Manager ARN; envsubst fills them in)
for svc in auth employee payroll frontend; do
  envsubst < ecs/$svc.taskdef.json > /tmp/$svc.json
  aws ecs register-task-definition --cli-input-json file:///tmp/$svc.json
done
aws ecs list-task-definitions
```

---

## Step 7 — Create the Services

```bash
source ecs/env.sh
bash ecs/create-services.sh    # one ECS service per task def, wired to its target group

aws ecs describe-services --cluster $CLUSTER \
  --services hrms-frontend-svc hrms-auth-svc hrms-employee-svc hrms-payroll-svc \
  --query 'services[].{name:serviceName,desired:desiredCount,running:runningCount}'
```
Watch the **service events** if anything stays at running=0 ([M13 §D](../13-troubleshooting-handbook.md)).

---

## Step 8 — Autoscaling

```bash
source ecs/env.sh
for svc in auth employee payroll frontend; do
  aws application-autoscaling register-scalable-target \
    --service-namespace ecs --resource-id service/$CLUSTER/hrms-$svc-svc \
    --scalable-dimension ecs:service:DesiredCount --min-capacity 2 --max-capacity 8
  aws application-autoscaling put-scaling-policy \
    --service-namespace ecs --resource-id service/$CLUSTER/hrms-$svc-svc \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name cpu60 --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
      "TargetValue":60.0,
      "PredefinedMetricSpecification":{"PredefinedMetricType":"ECSServiceAverageCPUUtilization"},
      "ScaleInCooldown":120,"ScaleOutCooldown":60}'
done
```

---

## Step 9 — Verify End-to-End

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --names hrms-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

curl http://$ALB_DNS/api/auth/health        # {"status":"ok","service":"auth"}
curl http://$ALB_DNS/api/emp/employees       # JSON from RDS
curl -I http://$ALB_DNS/                      # 200, frontend (React via Nginx)

# target health for each group should be "healthy"
aws elbv2 describe-target-health --target-group-arn <auth-tg-arn> \
  --query 'TargetHealthDescriptions[].TargetHealth.State'
```
**Map the domain + HTTPS:** add an ACM cert to a 443 listener, redirect 80→443, and point a Route 53 A/ALIAS record at the ALB ([Phase 08](../../08-route53/README.md) + [Phase 07](../../07-elb-autoscaling/README.md)). Then open `https://hrms.example.com`.

---

## Step 10 — Verify, Harden, Clean Up

**Harden recap:**
```
[ ] Tasks in PRIVATE subnets; only ALB is public
[ ] RDS not publicly accessible; SG allows only the task SG on 3306
[ ] DB creds in Secrets Manager (not in env/image) 🔒
[ ] Per-service Security Groups (least privilege)
[ ] HTTPS enforced (ACM) + 80→443 redirect
[ ] CloudWatch log groups + retention + Container Insights on
[ ] Autoscaling min≥2 across 2 AZs (HA)
[ ] ECR scanOnPush + lifecycle policy
[ ] Deployment circuit breaker + rollback enabled
[ ] Budget alarm set
```

**💰 Clean up (order matters — services before cluster, then shared infra):**
```bash
source ecs/env.sh
# 1) scale down + delete services
for svc in auth employee payroll frontend; do
  aws ecs update-service --cluster $CLUSTER --service hrms-$svc-svc --desired-count 0
  aws ecs delete-service  --cluster $CLUSTER --service hrms-$svc-svc --force
done
aws ecs delete-cluster --cluster $CLUSTER
# 2) ALB + target groups + listeners
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
# 3) RDS (skip final snapshot for a throwaway lab)
aws rds delete-db-instance --db-instance-identifier hrms-db \
  --skip-final-snapshot --delete-automated-backups
# 4) NAT Gateway + EIP, Secrets Manager secret, ECR repos, log groups
aws secretsmanager delete-secret --secret-id hrms/db --force-delete-without-recovery
for svc in auth employee payroll frontend; do
  aws ecr delete-repository --repository-name hrms-$svc --force
done
```
Then confirm the Billing Dashboard trends toward ~$0.

---

## 🧯 Troubleshooting Quick Links
- Task won't start / can't pull image → [Module 13 §C–D](../13-troubleshooting-handbook.md)
- 502/503 through the ALB → [Module 13 §F](../13-troubleshooting-handbook.md)
- Can't reach RDS / service-to-service → [Module 13 §G](../13-troubleshooting-handbook.md)
- Cost surprises → [Module 13 §J](../13-troubleshooting-handbook.md)

## 🚀 Stretch Goals
1. **Blue/green deploys** with CodeDeploy ([M11 §4](../11-services.md)).
2. **CI/CD**: GitHub Actions → build → push to ECR → `update-service`.
3. **Service Connect** for internal auth↔employee calls (drop the ALB hop) ([M11 §7](../11-services.md)).
4. **ElastiCache (Redis)** for sessions; **EFS** for employee document uploads.
5. **Fargate Spot** capacity provider for the non-critical services ([M8 §6](../08-fargate.md)).
6. **X-Ray** sidecar for distributed tracing across the three services.

---

🎉 You've deployed a real microservices system on ECS/Fargate — images in ECR, services behind an ALB, secrets managed, autoscaling, HA across AZs. This is the core skill behind "run our containers on AWS."

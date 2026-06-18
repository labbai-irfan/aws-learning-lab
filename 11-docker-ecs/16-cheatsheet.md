# 16 — Docker & ECS Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Docker Fundamentals](01-docker-fundamentals.md).

## Docker basics
| Thing | One-liner |
|---|---|
| **Image** | Read-only layered template |
| **Container** | Running instance of an image (ephemeral writable layer) |
| **Dockerfile** | Build instructions (each line = a cached layer) |
| **Volume** | Persistent data (named or bind mount) |
| **Registry** | Stores images (ECR, Docker Hub) |

```dockerfile
FROM node:20-alpine          # small base
WORKDIR /app
COPY package*.json ./
RUN npm ci                   # deps layer (cached unless package.json changes)
COPY . .
EXPOSE 3000                  # documents port (doesn't publish)
CMD ["node","server.js"]
```
```bash
docker build -t app .   docker run -p 8080:3000 app   docker exec -it <c> sh   docker logs <c>
```
💡 Multi-stage build + slim base + `.dockerignore` = small, secure images. Pin tags (`node:20.11`).

## ECS objects
| Thing | One-liner |
|---|---|
| **Task definition** | Blueprint (image, CPU/mem, ports, env, **roles**) |
| **Task** | Running instance of a task def (1+ containers) |
| **Service** | Keeps N tasks running + registers to a target group |
| **Cluster** | Logical capacity grouping |

## Fargate vs EC2 launch type
| | **Fargate** | **EC2** |
|---|---|---|
| Hosts | AWS-managed (serverless) | You manage |
| Billing | Per task | Per instance |
| Use | hands-off web/API/workers | host control, GPU, scale economics |
| Network mode | **awsvpc** (required) | bridge/host/awsvpc |

## Roles & networking
- **Task role** = perms for your app containers (call AWS APIs, least privilege).
- **Execution role** = ECS pulls images from ECR + writes logs + reads secrets.
- **awsvpc** = each task gets its own ENI/IP + security group.
- Private tasks reach ECR/S3/Secrets via **VPC endpoints** (no NAT).

## ECR
- Private registry: `aws ecr get-login-password | docker login ...`. Image scan (CVEs), lifecycle policies, immutable tags.
- URI: `<acct>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>`.

## Deploy & scale
- Rolling (min/max healthy %) or **blue/green via CodeDeploy** (two target groups).
- **Service Auto Scaling** (target tracking on CPU/mem/ALB requests). **Fargate Spot** for cost.
- Logs → CloudWatch (awslogs) / FireLens. Secrets → Secrets Manager/SSM (never in image).

## Exam triggers 💡
- "Run containers, no servers to manage" → **ECS + Fargate**.
- "Need full Kubernetes ecosystem" → **EKS**. "Fastest single container web app" → **App Runner**.
- "Per-task security group/IP" → **awsvpc**. "Pull image privately, no NAT" → **VPC endpoints**.
- "App needs to read S3" → **task role** (not keys). "Zero-downtime + instant rollback" → **CodeDeploy blue/green**.
- "build → ship → run on AWS" → **Dockerfile → ECR → ECS/Fargate**.

## Gotchas ⚠️
- Task stuck PENDING → capacity / image pull / ENI / subnet issue.
- `CannotPullContainerError` → execution role / ECR auth / no endpoint-NAT.
- OOM kill → raise task/container memory or fix the leak.
- Externalize state (RDS/EFS/S3/Redis) — task storage is ephemeral.

---
*Back to [Docker & ECS README](README.md).*

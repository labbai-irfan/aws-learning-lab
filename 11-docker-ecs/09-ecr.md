# Module 9 — Amazon ECR

> ECR (Elastic Container Registry) is AWS's private, managed Docker registry. This module covers creating repositories, authenticating, the build→tag→push→pull loop, scanning, lifecycle policies, and the IAM/permissions that make ECS pulls work.

---

## 1. Why a Private Registry

Docker Hub is public and rate-limited. Production images belong in a **private** registry that's: in your account, IAM-controlled, in-Region (fast pulls), encrypted, and vulnerability-scanned. That's **ECR**.

```
   (local) docker build ──► docker tag ──► docker push ──► ECR repo
                                                              │
                                            ECS task pulls ◄──┘  (via execution role)
```

- **Private repositories** — your images, IAM-gated (default).
- **Public repositories** (ECR Public / `public.ecr.aws`) — for sharing, like Docker Hub.

---

## 2. Create a Repository

```bash
aws ecr create-repository \
  --repository-name hrms-auth \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability IMMUTABLE \
  --region ap-south-1
```
- `scanOnPush=true` → automatic CVE scan on every push.
- `IMMUTABLE` tags → a tag can't be overwritten (great for reproducible deploys; you must bump versions). Use `MUTABLE` only if you intentionally reuse tags.

A repo URI looks like:
```
123456789012.dkr.ecr.ap-south-1.amazonaws.com/hrms-auth
```

---

## 3. Authenticate Docker to ECR

ECR uses short-lived tokens. Pipe `get-login-password` into `docker login`:

```bash
ACCOUNT=123456789012
REGION=ap-south-1
REGISTRY=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $REGISTRY
# Login Succeeded
```
💡 The token lasts ~12 hours. In CI, run this step before push every time. The AWS credentials behind it come from your CLI profile / CI role.

---

## 4. Build → Tag → Push

```bash
# build
docker build -t hrms-auth:1.4.2 ./auth-service

# tag for ECR (repo URI + version)
docker tag hrms-auth:1.4.2 $REGISTRY/hrms-auth:1.4.2

# push
docker push $REGISTRY/hrms-auth:1.4.2
```
⚠️ The repo (`hrms-auth`) must already exist (§2) — `docker push` won't create it. Tag with an **immutable** version or the git SHA, never just `:latest` for prod ([Module 2 §5](02-images.md)).

Pull (what ECS does for you, or to verify):
```bash
docker pull $REGISTRY/hrms-auth:1.4.2
```

---

## 5. Multi-Architecture Note

Fargate runs **x86_64** by default (or **ARM64** if you choose `runtimePlatform: cpuArchitecture=ARM64`, often cheaper). Build for the target arch — if you're on an Apple Silicon (ARM) Mac building for x86 Fargate:

```bash
docker buildx build --platform linux/amd64 -t $REGISTRY/hrms-auth:1.4.2 --push ./auth-service
```
⚠️ An arch mismatch shows up as `exec format error` when the task starts (Module 13).

---

## 6. Image Scanning

```bash
# trigger / read scan results
aws ecr start-image-scan --repository-name hrms-auth --image-id imageTag=1.4.2
aws ecr describe-image-scan-findings --repository-name hrms-auth --image-id imageTag=1.4.2
```
- **Basic scanning** — free, CVE check against the OS packages on push.
- **Enhanced scanning** (Amazon Inspector) — deeper, continuous, includes app dependencies.

🔒 Gate deploys on scan results in CI: fail the pipeline on HIGH/CRITICAL findings.

---

## 7. Lifecycle Policies (stop paying for old images)

ECR charges for **storage**. Old, untagged, superseded images pile up. A lifecycle policy auto-expires them:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 7 days",
      "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed",
                     "countUnit": "days", "countNumber": 7 },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep only the last 15 tagged images",
      "selection": { "tagStatus": "tagged", "tagPrefixList": ["1.","v"],
                     "countType": "imageCountMoreThan", "countNumber": 15 },
      "action": { "type": "expire" }
    }
  ]
}
```
```bash
aws ecr put-lifecycle-policy --repository-name hrms-auth \
  --lifecycle-policy-text file://lifecycle.json
```

---

## 8. Permissions — Who Can Pull/Push

Two layers:
1. **IAM identity policies** — what a user/role can do (your CLI to push; the **ECS task execution role** to pull).
2. **Repository policies** (resource-based) — cross-account access, if needed.

The ECS **execution role** needs (AWS-managed `AmazonECSTaskExecutionRolePolicy` covers it):
```
ecr:GetAuthorizationToken         (account-wide)
ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer
ecr:BatchGetImage                 (on the repo)
logs:CreateLogStream / PutLogEvents
```
⚠️ The single most common ECS failure: a task that **can't pull its image** because the execution role lacks ECR permissions, or the task has no network route to ECR (no NAT / no VPC endpoint — Module 8 §4). Symptom: `CannotPullContainerError` (Module 13).

---

## 9. VPC Endpoints (private pulls without NAT)

For tasks in private subnets, add **interface endpoints** for `ecr.api` and `ecr.dkr`, plus a **gateway endpoint for S3** (ECR stores layers in S3), and one for CloudWatch Logs. This lets tasks pull images and ship logs **without a NAT Gateway** — more secure and can cut NAT cost.

---

## ✅ Module 9 Checklist
```
[ ] Created an ECR repo with scanOnPush + immutable tags
[ ] Can authenticate with get-login-password | docker login
[ ] Comfortable with build→tag→push using the repo URI
[ ] Build for the right CPU arch (amd64/arm64)
[ ] Lifecycle policy in place to expire old images
[ ] Execution role can pull; tasks have a route to ECR (NAT or endpoints)
```

➡️ Next: [10-task-definitions.md](10-task-definitions.md) — the deployment blueprint.

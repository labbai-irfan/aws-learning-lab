# Module 12 — DevOps Architecture

> GitOps, CI/CD pipelines, deployment strategies (blue/green, canary, rolling), container platforms, and platform engineering at enterprise scale.

---

## 1. The DevOps pipeline blueprint

```
   Code push (GitHub/GitLab)
        │
        ▼ CI (CodeBuild / GitHub Actions)
        │  ├── Unit tests + lint
        │  ├── Security scan (Snyk/Semgrep/Checkov)
        │  ├── Docker build + ECR push
        │  └── Terraform plan / CFN change-set
        │
        ▼ CD to Staging (automated)
        │  ├── Terraform apply (infra delta)
        │  ├── ECS/EKS rolling deploy
        │  ├── Smoke tests + integration tests
        │  └── Performance gate (k6)
        │
        ▼ CD to Prod (human approval gate)
           ├── Blue/green or canary deployment
           ├── Synthetic canary validation
           ├── Auto-rollback on alarm
           └── Notify #deployments Slack
```

---

## 2. AWS native CI/CD toolchain

| Tool | Role |
|---|---|
| **CodeCommit** | Git hosting (or use GitHub/GitLab) |
| **CodeBuild** | Managed build/test/lint/scan runner |
| **CodeDeploy** | Deployment automation (EC2, ECS, Lambda) |
| **CodePipeline** | Pipeline orchestration (source→build→test→deploy) |
| **ECR** | Container registry (with image scanning) |
| **CodeArtifact** | NPM/Maven/PyPI artifact proxy + private registry |
| **CloudFormation / Terraform** | Infrastructure changes |

### CodePipeline example stages
```yaml
Stages:
  - Name: Source
    Actions: [GitHub v2 connection → trigger on main push]
  - Name: Build
    Actions: [CodeBuild: test + docker build + ECR push]
  - Name: DeployStaging
    Actions: [CodeDeploy ECS blue/green on staging]
  - Name: ApproveProduction
    Actions: [Manual approval (SNS → Slack for in-chat approval)]
  - Name: DeployProduction
    Actions: [CodeDeploy ECS blue/green on prod]
```

---

## 3. Deployment strategies

### Rolling deploy
Replace instances/tasks one by one. Zero downtime; rollback is slow (re-deploy old version).
```
   Before: [v1][v1][v1][v1]
   During: [v2][v1][v1][v1] → [v2][v2][v1][v1] → ...
   After:  [v2][v2][v2][v2]
```

### Blue/Green (preferred for ECS + Lambda)
```
   Blue (current v1): receives 100% traffic
   Green (new v2): deployed alongside, 0% traffic
   Test green → switch ALB/Route 53 weight → 100% traffic to green
   Keep blue for 15 min → rollback if alarm → delete blue
```
- **ECS CodeDeploy** does this with ALB target groups automatically.
- **Lambda aliases** + weighted routing enable blue/green for serverless.
- Rollback: re-weight to blue in seconds.

### Canary (gradually shift traffic)
```
   Step 1: 5% → green, 95% → blue  (watch CloudWatch alarms)
   Step 2: 25% → green (30 min later, if no alarm)
   Step 3: 100% → green
   On alarm: rollback to 0% green immediately
```
- **CodeDeploy Linear/Canary** deployment configs for ECS/Lambda.
- Define **auto-rollback triggers** on CloudWatch alarm states.

### Feature flags (release vs deploy separation)
Deploy code that's off by default; toggle it on per tenant/user/region:
- **AWS AppConfig**: feature flags stored in config profiles, validated and deployed to app in real-time.
- Decouple release (toggle) from deployment (code change) — safest incremental rollout.

---

## 4. Container platform architecture

### ECS Fargate (serverless containers)
```
   ECR ──► Task Definition (CPU/RAM/secrets/log config)
                │
           ECS Service (desired count, rolling update, auto-scaling)
                │
           ALB Target Group (health check /health)
```
- Pros: no EC2 management; per-task billing; integrates natively with IAM, Secrets Manager, CloudWatch.
- Cons: less visibility into host; can't run privileged containers.

### EKS (Kubernetes for AWS)
For teams with Kubernetes expertise or needing K8s ecosystem tools (Helm, ArgoCD, Karpenter):
```
   EKS Control Plane (managed) ──► Managed Node Groups (EC2 / Fargate)
   Karpenter: auto-provision right-sized EC2 nodes on demand
   AWS Load Balancer Controller: Ingress → ALB
   External Secrets Operator: sync Secrets Manager → K8s secrets
   ArgoCD (GitOps): reconcile cluster state to Git manifests
```
- Karpenter replaces Cluster Autoscaler — provisions exact node needed in ~30s.
- EKS Auto Mode: fully managed node lifecycle (2024+).

---

## 5. GitOps pattern

```
   Developer → PR to GitHub
   GitHub Actions CI → tests + security scan + build image → tag with commit SHA
   Merge to main → update image tag in Helm chart / K8s manifest in config repo
   ArgoCD detects drift → auto-applies to cluster (or requires PR approval for prod)
   CloudWatch → deployment annotation on dashboard
```
Principles:
- Git is the **single source of truth** for both app code and infrastructure.
- Deployments are **pull-based** (ArgoCD pulls from Git, not pushed by CI).
- Every change is **auditable** via Git history.

---

## 6. Observability in the pipeline

Integrate quality gates:
- **Unit tests**: must pass (>80% coverage gate).
- **Security**: Snyk/Checkov fail-fast on HIGH/CRITICAL findings.
- **Performance**: k6 load test; fail if p99 > SLO.
- **Smoke tests**: Cypress/Playwright synthetic check on staging.
- **Auto-rollback**: CodeDeploy + CloudWatch alarm → rollback if `5xx > 1%`.

---

## 7. Platform engineering (building a developer platform)

At enterprise scale, the DevOps team becomes a **Platform Engineering** team building an Internal Developer Platform (IDP):
- **Self-service infra**: Service Catalog / Backstage → developers provision environments without tickets.
- **Golden paths**: curated templates for services (ECS service, Lambda function, RDS) pre-wired with logging, monitoring, security.
- **Paved road**: opinionated choices (one CI tool, one registry, one secrets manager) → teams follow the path unless they have a strong reason not to.
- **Docs-as-code**: Backstage with TechDocs — living documentation auto-generated from repos.

---

## ✅ DevOps architecture checklist
- [ ] OIDC auth from CI to AWS (no static keys)
- [ ] ECR with image scanning on push
- [ ] Staging deploy: automated, gated on tests
- [ ] Prod deploy: human approval + canary/blue-green
- [ ] Auto-rollback on CloudWatch alarm (CodeDeploy)
- [ ] Feature flags via AppConfig for incremental rollout
- [ ] Performance gate in CI (k6 / load test)
- [ ] Deployment annotation in CloudWatch dashboards
- [ ] IaC changes in same pipeline as app code

➡️ Next: [Module 13 — SaaS & Multi-Tenant Architecture](13-saas-multi-tenant.md)

# CI/CD Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [deployment-strategies.md](deployment-strategies.md).

## CI vs CD
| Term | Meaning |
|---|---|
| **CI** (Continuous Integration) | Every push auto-builds + tests → keep `main` green |
| **Continuous Delivery** | Every passing build is release-ready (manual approval to ship) |
| **Continuous Deployment** | Every passing build auto-ships to prod (no human gate) |

```
push → Source → Build → Test → Artifact → Deploy → Monitor (rollback on alarm)
```

## The AWS tools
| Tool | Role |
|---|---|
| **GitHub Actions** | CI/CD in GitHub; YAML in `.github/workflows/`; auth AWS via **OIDC** |
| **CodePipeline** | AWS orchestrator (stages: Source→Build→Deploy), approvals, cross-account |
| **CodeBuild** | Managed build (`buildspec.yml`), pay per build-minute |
| **CodeDeploy** | Deploy to EC2/on-prem, ECS, Lambda (`appspec.yml`, lifecycle hooks) |
| **CodeArtifact / ECR** | Package / container registries |

## Deployment strategies
| Strategy | Downtime | Rollback | Cost |
|---|---|---|---|
| **Recreate** | yes | slow | 💲 |
| **Rolling** | none | medium | 💲 |
| **Blue/Green** | none | **instant** (flip back) | 💲💲 (2× temp) |
| **Canary / Linear** | none | fast (stop shift) | 💲💲 |
- Blue/Green & Canary on ECS/Lambda → **CodeDeploy** (two target groups / traffic shifting).

## Security (bake in)
- **OIDC → IAM role** (no long-lived AWS keys in CI). Least-privilege deploy roles.
- Secrets in GitHub Secrets / SSM / Secrets Manager — never in YAML.
- Branch protection + required checks; **environment approval** gate before prod.
- Pin action versions (`@v4`); enable Dependabot.

## Pipeline stages (typical)
```
Source (GitHub) → Build+Test (CodeBuild/Actions) → Push image (ECR)
   → Deploy (CodeDeploy: rolling/blue-green) → Smoke test → Promote/rollback
```

## Exam triggers 💡
- "No AWS keys in GitHub" → **OIDC + IAM role**.
- "Instant rollback for critical app" → **Blue/Green** (CodeDeploy).
- "Gradually shift % of traffic" → **Canary/Linear**.
- "Build artifacts/images in AWS" → **CodeBuild** (`buildspec.yml`).
- "Deploy to ECS/EC2/Lambda with hooks" → **CodeDeploy** (`appspec.yml`).
- "Manual approval before prod" → **CodePipeline approval / GH environment rule**.

## Gotchas ⚠️
- Continuous **Delivery** ≠ **Deployment** (the human gate is the difference).
- Blue/Green needs ~2× capacity temporarily.
- Always wire **rollback on CloudWatch alarm** for auto-deploys.
- Don't skip required checks / branch protection on `main`.

---
*Back to [CI/CD README](../README.md) · [Interview Guide](interview-guide.md).*

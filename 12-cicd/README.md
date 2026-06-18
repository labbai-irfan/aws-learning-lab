# Phase 12 — CI/CD on AWS (Complete Repository)

> A production-grade, end-to-end CI/CD reference covering **GitHub Actions**, **AWS CodePipeline**, **CodeBuild**, **CodeDeploy**, and the deployment strategies that matter in real teams — **Rolling**, **Blue/Green**, and **Canary**.
>
> Acting as a **Senior DevOps Engineer**, this repo gives you copy-paste workflow files, AWS config (buildspec/appspec/pipeline), hands-on labs, and an interview guide.

---

## 📐 What is CI/CD?

| Term | Meaning | Goal |
|------|---------|------|
| **CI — Continuous Integration** | Every push is automatically built and tested. | Catch bugs early, keep `main` always green. |
| **CD — Continuous Delivery** | Every passing build is automatically prepared for release (manual approval to ship). | Ship anytime with one click. |
| **CD — Continuous Deployment** | Every passing build is automatically pushed to production (no human gate). | Ship continuously, many times a day. |

```
 Developer ──push──► Source ──► Build ──► Test ──► Artifact ──► Deploy ──► Monitor
   (git)            (GitHub)   (compile) (unit/   (image/      (EC2/ECS/  (rollback
                                          integ)   bundle)      Lambda)    on alarm)
```

---

## 🗺️ Repository Layout

```
12-cicd/
├── README.md                          ← you are here
├── .github/workflows/                 ← GitHub Actions pipelines
│   ├── react-ci-cd.yml                ← React build + deploy to S3/CloudFront
│   ├── nodejs-ci-cd.yml               ← Node.js test + deploy via CodeDeploy
│   ├── docker-ci-cd.yml               ← Build image → push to ECR → deploy ECS
│   ├── production-pipeline.yml        ← Multi-env (dev→staging→prod) with approvals
│   └── reusable-deploy.yml            ← Reusable workflow called by the others
├── aws/
│   ├── codebuild/buildspec.yml        ← CodeBuild build instructions
│   ├── codedeploy/appspec.yml         ← CodeDeploy (EC2 in-place) lifecycle
│   ├── codedeploy/appspec-ecs.yml     ← CodeDeploy Blue/Green for ECS
│   ├── codedeploy/scripts/            ← Lifecycle hook scripts
│   ├── codepipeline/pipeline.json     ← Full CodePipeline definition
│   ├── blue-green/                     ← Blue/Green assets
│   └── canary/                         ← Canary deployment assets
├── docs/
│   ├── deployment-strategies.md       ← Rolling vs B/G vs Canary deep dive
│   ├── blue-green-deployment.md
│   ├── canary-deployment.md
│   ├── github-actions-vs-codepipeline.md
│   ├── interview-guide.md             ← 60+ Q&A + scenarios
│   ├── cheatsheet.md                  ← 1-page revision
│   └── sam-and-beanstalk.md           ← SAM + Elastic Beanstalk (managed deploys)
└── labs/
    ├── lab-01-github-actions.md
    ├── lab-02-codebuild.md
    ├── lab-03-codepipeline-codedeploy.md
    ├── lab-04-blue-green-ecs.md
    └── lab-05-canary-lambda.md
```

---

## 🔧 The Tools — At a Glance

### GitHub Actions
- **What:** CI/CD native to GitHub. Workflows are YAML in `.github/workflows/`.
- **Trigger:** `push`, `pull_request`, `schedule`, `workflow_dispatch`, etc.
- **Unit of work:** *workflow → jobs → steps*. Jobs run on **runners** (GitHub-hosted or self-hosted).
- **AWS auth:** Use **OIDC** (`aws-actions/configure-aws-credentials`) — no long-lived keys.

### AWS CodePipeline
- **What:** AWS-managed orchestrator. Models release as **stages** (Source → Build → Deploy).
- **Source:** CodeCommit, GitHub (via CodeStar connection), S3, ECR.
- **Strength:** Native AWS integration, manual approval actions, cross-account deploys.

### AWS CodeBuild
- **What:** Managed build service. Reads `buildspec.yml`. Pay per build-minute.
- **Use for:** compiling, testing, building Docker images, producing artifacts.

### AWS CodeDeploy
- **What:** Automates deployment to **EC2/On-Prem**, **ECS**, or **Lambda**.
- **Reads:** `appspec.yml` (lifecycle hooks: BeforeInstall, AfterInstall, ApplicationStart, ValidateService…).
- **Supports:** In-place (Rolling), **Blue/Green**, and **Canary/Linear** traffic shifting.

---

## 🚀 Quick Starts

### React → S3 + CloudFront
```bash
# Local sanity check
npm ci && npm run build
# CI/CD: see .github/workflows/react-ci-cd.yml
```

### Node.js → EC2 (CodeDeploy)
```bash
npm ci && npm test
# CI/CD: see .github/workflows/nodejs-ci-cd.yml + aws/codedeploy/appspec.yml
```

### Docker → ECR + ECS (Blue/Green)
```bash
docker build -t myapp .
# CI/CD: see .github/workflows/docker-ci-cd.yml + aws/codedeploy/appspec-ecs.yml
```

---

## 🎯 Deployment Strategies (quick compare)

| Strategy | How | Downtime | Rollback | Cost | Best for |
|----------|-----|----------|----------|------|----------|
| **Recreate** | Stop old, start new | ❌ Yes | Slow | 💲 | Dev / non-critical |
| **Rolling** | Replace instances batch by batch | ✅ None | Medium | 💲 | Stateless apps |
| **Blue/Green** | Stand up full new env, flip traffic | ✅ None | Instant (flip back) | 💲💲 (2× temporarily) | Critical apps needing instant rollback |
| **Canary** | Send small % traffic to new, ramp up | ✅ None | Fast (stop shift) | 💲💲 | Risk-averse, high-traffic |

➡️ Full deep dive: [docs/deployment-strategies.md](docs/deployment-strategies.md)

---

## 🔐 Security Best Practices (baked into every workflow)

1. **No static AWS keys** — use GitHub OIDC → IAM role (`id-token: write`).
2. **Least-privilege IAM** — scope deploy roles to specific resources.
3. **Secrets in GitHub Secrets / SSM Parameter Store / Secrets Manager**, never in YAML.
4. **Branch protection + required checks** before merge to `main`.
5. **Environment protection rules** — manual approval gate before `production`.
6. **Pin action versions** (e.g. `@v4`) and dependabot for updates.

---

## 📚 Learning Path

1. Read [docs/deployment-strategies.md](docs/deployment-strategies.md)
2. Do [labs/lab-01-github-actions.md](labs/lab-01-github-actions.md) → [lab-05](labs/lab-05-canary-lambda.md) in order
3. Study [docs/interview-guide.md](docs/interview-guide.md), the [docs/cheatsheet.md](docs/cheatsheet.md), and [docs/sam-and-beanstalk.md](docs/sam-and-beanstalk.md)
4. Build the [production-pipeline.yml](.github/workflows/production-pipeline.yml) for your own app

---

## ✅ Prerequisites

- AWS account + AWS CLI v2 configured
- GitHub account
- Node.js 20+, Docker, `git`
- Basic understanding of [EC2](../03-ec2/), [S3](../05-s3/), and [ELB](../07-elb-autoscaling/) (earlier phases)

# GitHub Actions vs AWS CodePipeline

> Both orchestrate CI/CD. They're often used **together** — GitHub Actions for CI and lightweight CD, CodePipeline when you want a fully AWS-native release with native CodeDeploy Blue/Green and cross-account controls.

## Side-by-side

| Dimension | GitHub Actions | AWS CodePipeline |
|-----------|----------------|------------------|
| Hosting | GitHub-hosted or self-hosted runners | Fully AWS-managed |
| Config | YAML in `.github/workflows/` | Console / CLI / CloudFormation / CDK |
| Pricing | Free minutes + per-minute after | Per active pipeline/month + action runs |
| Source | GitHub-native | CodeCommit, GitHub (connection), S3, ECR |
| Build | runners | CodeBuild |
| Deploy | scripts / actions | CodeDeploy, ECS, CloudFormation, S3, Lambda |
| AWS auth | OIDC → IAM role | Native IAM service role |
| Approvals | Environment protection rules | Manual approval action (+ SNS) |
| Marketplace | Huge action ecosystem | AWS + limited 3rd party |
| Best at | Developer-centric, multi-cloud, fast setup | Deep AWS integration, cross-account, governance |

## When to use which

**GitHub Actions when:**
- Your source is on GitHub and you want CI close to the PR.
- You deploy to multiple clouds or non-AWS targets.
- You want the broad action marketplace and fast iteration.

**CodePipeline when:**
- You want a fully AWS-managed release pipeline (auditable, IAM-governed).
- You need native **CodeDeploy Blue/Green for ECS/Lambda** orchestration.
- You deploy across multiple AWS accounts with strict separation.
- You're standardizing on CloudFormation/CDK-defined infrastructure.

## The common hybrid

```
GitHub push
   │
   ▼
GitHub Actions  ──► run tests, build image, push to ECR
   │
   ▼ (ECR push event)
CodePipeline    ──► CodeBuild (render taskdef) ──► CodeDeploy Blue/Green ──► ECS
```

This gives you GitHub's developer experience for CI and AWS's native, governed
deployment engine for CD. Both pipelines in this repo's `.github/workflows/`
and `aws/codepipeline/pipeline.json` can run this way.

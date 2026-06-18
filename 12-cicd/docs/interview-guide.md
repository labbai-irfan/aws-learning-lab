# CI/CD Interview Guide — 60+ Q&A + Scenarios

> Covers GitHub Actions, CodePipeline, CodeBuild, CodeDeploy, and deployment strategies. Grouped by topic and difficulty. Use it to drill before DevOps / Cloud / SRE interviews.

## Table of Contents
1. [CI/CD Fundamentals](#1-cicd-fundamentals)
2. [GitHub Actions](#2-github-actions)
3. [AWS CodePipeline](#3-aws-codepipeline)
4. [AWS CodeBuild](#4-aws-codebuild)
5. [AWS CodeDeploy](#5-aws-codedeploy)
6. [Deployment Strategies](#6-deployment-strategies)
7. [Blue/Green](#7-bluegreen)
8. [Canary](#8-canary)
9. [Security & Secrets](#9-security--secrets)
10. [Scenario / System Design](#10-scenario--system-design)

---

## 1. CI/CD Fundamentals

**Q1. Difference between Continuous Delivery and Continuous Deployment?**
Both automate up to a deployable artifact. **Continuous Delivery** stops before
prod and requires a **manual approval** to release. **Continuous Deployment**
has no human gate — every passing build goes straight to production.

**Q2. What is a pipeline artifact and why does it matter?**
An immutable output of one stage (compiled binary, Docker image, zip) passed to
the next. Building once and promoting the **same artifact** through environments
avoids "works in staging, breaks in prod" caused by rebuilding.

**Q3. What does "shift left" mean in CI/CD?**
Move testing/security earlier (into PRs and build) so defects are caught when
they're cheapest to fix, not in production.

**Q4. Why build once, deploy many?**
Rebuilding per environment risks dependency drift and non-reproducible bugs. One
artifact + environment-specific config = consistent, traceable releases.

**Q5. What's idempotency in deployments and why care?**
Running the same deploy twice yields the same result. Idempotent deploys are
safe to retry — critical for automation and rollback.

---

## 2. GitHub Actions

**Q6. Workflow vs job vs step vs action?**
- **Workflow**: the whole automation file (`.github/workflows/x.yml`).
- **Job**: a set of steps on one runner; jobs run in parallel by default.
- **Step**: a single task (a shell command or an action).
- **Action**: a reusable unit (e.g. `actions/checkout@v4`).

**Q7. How do you authenticate to AWS from GitHub Actions without static keys?**
**OIDC**: configure an IAM OIDC identity provider for GitHub, create a role with
a trust policy scoped to your repo/branch, then use
`aws-actions/configure-aws-credentials` with `role-to-assume` and
`permissions: id-token: write`. Short-lived credentials, no secrets to leak.

**Q8. How do jobs share data / depend on each other?**
`needs:` creates dependencies. Data passes via **artifacts**
(`upload/download-artifact`) or **job outputs** (`outputs:` + `$GITHUB_OUTPUT`).

**Q9. How do you stop concurrent deploys clobbering each other?**
`concurrency:` group with `cancel-in-progress`. For prod, set
`cancel-in-progress: false` so a deploy is never killed mid-flight.

**Q10. What is a matrix build?**
`strategy.matrix` runs the same job across combinations (e.g. Node 18/20/22),
in parallel — for cross-version/OS testing.

**Q11. GitHub-hosted vs self-hosted runners?**
Hosted: managed, ephemeral, pay-per-minute. Self-hosted: your infra — needed for
VPC access, special hardware, or large caches; you own patching & security.

**Q12. How do you implement a manual approval gate?**
Use a GitHub **Environment** with required reviewers; reference it via
`environment:` in the job. The job pauses until approved.

**Q13. What's a reusable workflow vs a composite action?**
Reusable workflow = a whole workflow called with `workflow_call` (`uses:`).
Composite action = a packaged set of steps used inside a job. Use reusable
workflows to DRY entire pipelines, composite actions to DRY step sequences.

**Q14. How do you cache dependencies?**
`actions/cache` keyed on a lockfile hash, or `setup-node`'s built-in `cache: npm`.
Speeds up installs across runs.

---

## 3. AWS CodePipeline

**Q15. What are the core constructs?**
**Pipeline → stages → actions.** Actions have categories: Source, Build, Test,
Deploy, Approval, Invoke. Artifacts flow between stages via the artifact store (S3).

**Q16. How does CodePipeline connect to GitHub now?**
Via a **CodeStar Connection** (GitHub App), not the deprecated OAuth/webhook
token approach. The connection ARN is referenced in the source action.

**Q17. How do you add a manual approval?**
An **Approval action** (often with an SNS topic to notify approvers). The
pipeline halts until someone approves/rejects in the console.

**Q18. How do you trigger a pipeline?**
On source change (CodeCommit/GitHub push, S3 object, ECR push via EventBridge),
on a schedule, or manually (`start-pipeline-execution`).

**Q19. CodePipeline vs GitHub Actions — when each?**
CodePipeline for AWS-native, governed, cross-account releases and native
CodeDeploy Blue/Green orchestration; GitHub Actions for developer-centric CI and
multi-cloud. Often combined. (See github-actions-vs-codepipeline.md.)

**Q20. How do you do cross-account deployments?**
Pipeline in a "tools" account assumes roles in target accounts; artifact bucket
+ KMS key shared via policies. CodeDeploy/CloudFormation actions specify the
target role.

---

## 4. AWS CodeBuild

**Q21. What is buildspec.yml and its phases?**
The build instruction file. Phases: `install` → `pre_build` → `build` →
`post_build`, plus `artifacts`, `cache`, `reports`, `env`.

**Q22. How does CodeBuild get secrets safely?**
`env.parameter-store` (SSM Parameter Store) and `env.secrets-manager` (Secrets
Manager) — values injected at runtime, never stored in the spec.

**Q23. How do you speed up CodeBuild?**
Dependency caching (`cache.paths` or S3/local cache), smaller base images,
Docker layer caching, right-sizing the compute type, and parallel/batch builds.

**Q24. How does CodeBuild build Docker images?**
Run in **privileged mode**, log in to ECR
(`aws ecr get-login-password | docker login`), `docker build`, `docker push`.

**Q25. What is imagedefinitions.json?**
A small artifact mapping container name → image URI. CodePipeline's ECS deploy
action reads it to know which image to roll out.

---

## 5. AWS CodeDeploy

**Q26. What is appspec.yml?**
The CodeDeploy spec at the bundle root. For EC2: `files` mappings + `hooks`
(lifecycle scripts). For ECS/Lambda: resource definition + Lambda validation hooks.

**Q27. List the EC2 in-place lifecycle events in order.**
ApplicationStop → DownloadBundle → BeforeInstall → Install → AfterInstall →
ApplicationStart → ValidateService. (DownloadBundle/Install are CodeDeploy-managed.)

**Q28. Why does ApplicationStop sometimes "not run" on first deploy?**
ApplicationStop runs from the **previous** successful revision's scripts. On the
first deploy there's none, so it's skipped. Scripts must also be idempotent/guarded.

**Q29. What compute platforms does CodeDeploy support?**
EC2/On-Premises (in-place or blue/green), ECS (blue/green, canary, linear),
and Lambda (canary, linear, all-at-once).

**Q30. How does CodeDeploy decide a deployment failed?**
A lifecycle hook returns non-zero, a CloudWatch alarm fires, or
`ValidateService` fails. With auto-rollback enabled it redeploys the last
known-good revision.

**Q31. What is the CodeDeploy agent and where does it run?**
A daemon on EC2/on-prem instances that polls for deployments and executes
appspec hooks. (Not needed for ECS/Lambda platforms.)

**Q32. Difference between OneAtATime, HalfAtATime, AllAtOnce?**
EC2 in-place batch sizes: OneAtATime (safest, slowest), HalfAtATime (50% at a
time), AllAtOnce (fastest, riskiest, full downtime risk).

---

## 6. Deployment Strategies

**Q33. Compare rolling, blue/green, and canary in one line each.**
Rolling: replace in batches (cheap, no instant rollback). Blue/Green: full second
env + flip (instant rollback, 2× cost). Canary: small % first then ramp
(smallest blast radius, needs metrics).

**Q34. Why must rolling/canary/blue-green deployments be backward compatible?**
Because two versions run simultaneously (during the roll, the canary slice, or
the blue/green overlap on a shared DB). New code must handle the old schema and
vice versa.

**Q35. What is the expand/contract (parallel change) pattern?**
Make DB changes in additive steps: **expand** (add nullable column), **migrate**
(deploy code writing both), **contract** (drop old) — so no single release
breaks compatibility and rollback stays safe.

**Q36. When would you choose recreate?**
Dev/test, or apps where a maintenance window is acceptable and you want only one
version live (e.g. risky schema changes, single-instance apps).

**Q37. What is a shadow / dark launch?**
Mirror prod traffic to the new version without returning its responses — tests
real-load behavior with zero user risk. Watch for side effects on shared state.

---

## 7. Blue/Green

**Q38. How is rollback "instant" in blue/green?**
The old (blue) environment is still running during the termination wait, so
rollback is just flipping the router back — seconds, not a redeploy.

**Q39. What AWS pieces are needed for ECS blue/green?**
Two target groups, a production listener (+ optional test listener), an ECS
service with `CODE_DEPLOY` controller, and a CodeDeploy app + deployment group.

**Q40. What is the termination wait time?**
The hold after cutover before blue is destroyed — your window to detect issues
and roll back. Typically 5–15 minutes.

**Q41. Biggest downside of blue/green?**
Temporary 2× compute cost, and the shared database still requires
backward-compatible schema changes.

**Q42. How do long-lived connections/sessions complicate blue/green?**
Existing connections may stick to blue; you need connection draining and ideally
stateless/sticky-aware design so sessions survive the flip.

---

## 8. Canary

**Q43. Why is canary unsafe without good observability?**
Promotion/abort decisions rely on live metrics. Without reliable error-rate and
latency signals (and alarms), you can't detect a bad release in the canary slice.

**Q44. What metrics gate a canary?**
5xx error rate, p99 latency, Lambda errors/throttles, and business KPIs (e.g.
checkout success), wired to CloudWatch alarms attached to the deployment group.

**Q45. Name two CodeDeploy canary configs.**
`Canary10Percent5Minutes` (10% then 100% after 5 min) and
`Linear10PercentEvery1Minute` (ramp +10%/min).

**Q46. Pitfall of canary on a low-traffic service?**
A 10% slice may receive too few requests to produce statistically meaningful
metrics. Lengthen bake time or inject synthetic traffic.

**Q47. How do you canary on Lambda specifically?**
Alias weighted routing (`AdditionalVersionWeights`) — built-in. CodeDeploy
automates the ramp with `LambdaCanary*` configs and pre/post-traffic hooks.

**Q48. How is canary different from A/B testing?**
Canary splits by **percentage to validate safety**; A/B splits by **user
attribute to validate a product hypothesis** (usually via feature flags).

---

## 9. Security & Secrets

**Q49. Where should secrets live in CI/CD?**
GitHub Secrets / Environments, AWS SSM Parameter Store (SecureString), or Secrets
Manager — never in YAML, logs, or images. Inject at runtime.

**Q50. Why prefer OIDC over stored AWS access keys?**
OIDC issues short-lived, automatically-rotated credentials scoped by trust
policy. No long-lived secret to leak, rotate, or have stolen from logs.

**Q51. How do you prevent a malicious PR from stealing secrets in Actions?**
`pull_request` from forks runs without secrets by default; use
`pull_request_target` carefully, pin action SHAs, require approvals for first-time
contributors, and gate secret-using jobs behind protected environments.

**Q52. How do you enforce least privilege for deploy roles?**
Scope the IAM role to specific resources/actions (this ECS service, this S3
bucket), restrict the OIDC trust to specific repo+branch, and separate
build vs deploy roles.

**Q53. How do you scan for vulnerabilities in the pipeline?**
SAST (CodeQL), dependency scanning (`npm audit`, Dependabot), image scanning
(Trivy, ECR scan), and secret scanning — fail the build on critical findings.

---

## 10. Scenario / System Design

**Q54. Design a zero-downtime pipeline for a high-traffic e-commerce API.**
GitHub Actions CI (test, build image, push to ECR) → CodePipeline → CodeBuild
renders taskdef → CodeDeploy **canary** (10%/5min) on ECS with two target groups
→ CloudWatch alarms (5xx, p99, checkout-success) gating + auto-rollback →
manual approval before prod. DB changes via expand/contract.

**Q55. A deploy "succeeded" but users report errors. What's wrong and how to prevent?**
Health checks too shallow (only checked process up, not functionality). Add deep
`ValidateService` / post-traffic hooks hitting real endpoints + dependencies, and
gate on business metrics, not just HTTP 200 on `/`.

**Q56. How would you roll back a bad release that's already at 100%?**
Blue/Green: flip back to blue (if within termination window) or redeploy previous
taskdef. Otherwise `aws ecs update-service --task-definition <previous>
--force-new-deployment`. Keep previous revisions immutable and tagged.

**Q57. How do you promote the same build through dev → staging → prod?**
Build the artifact/image once, tag it, and pass that **same** image through each
environment's deploy stage with env-specific config (SSM/Secrets Manager) — never
rebuild per environment.

**Q58. Pipeline is slow (20 min). How do you speed it up?**
Cache deps & Docker layers, parallelize independent jobs, run only affected tests,
use bigger/right-sized runners, build images with buildx cache, and fail fast on
lint/unit before expensive integration stages.

**Q59. How do you deploy a database migration safely in CI/CD?**
Run migrations as a separate, idempotent, backward-compatible step (expand/
contract), gate destructive changes behind a later release, take a snapshot
before, and ensure the app handles both schemas during overlap.

**Q60. A canary shows elevated latency but no errors. Promote or abort?**
Abort/hold — latency regression degrades UX and may cascade (timeouts, retries).
Investigate before promoting; metric gates should already have flagged p99.

**Q61. How do you give developers fast feedback while keeping prod safe?**
Run CI (lint/unit) on every PR with required status checks + branch protection;
auto-deploy to dev/staging; gate prod behind environment approval and canary with
auto-rollback. Fast where it's cheap, controlled where it's risky.

**Q62. How do you make deployments observable/auditable?**
Tag every deploy with the commit SHA, emit deploy events to CloudWatch/EventBridge,
keep immutable artifacts, log approvals, and dashboard the deploy markers against
error/latency graphs.

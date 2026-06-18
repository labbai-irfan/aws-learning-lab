# Blue/Green Deployment — Complete Guide

> Run two identical environments. Only one serves production at a time. Deploy to the idle one, validate, then flip. Roll back instantly by flipping back.

## Table of Contents
1. [Concept](#1-concept)
2. [Anatomy of the swap](#2-anatomy-of-the-swap)
3. [On EC2 / Auto Scaling](#3-on-ec2--auto-scaling)
4. [On ECS (CodeDeploy)](#4-on-ecs-codedeploy)
5. [On Lambda](#5-on-lambda)
6. [The database problem](#6-the-database-problem)
7. [Rollback](#7-rollback)
8. [Pros, cons & cost](#8-pros-cons--cost)
9. [Checklist](#9-checklist)

---

## 1. Concept

- **Blue** = the current production environment (live).
- **Green** = a new, identical environment running the new version.

You deploy the new version to **green** while **blue** keeps serving users. Once
green passes validation, you switch the router (ALB listener / DNS / Lambda
alias) so **green becomes live**. Blue stays idle as a hot standby for rollback.

**Analogy:** Two identical stages in a theater. The audience watches stage Blue
while the crew sets up stage Green behind the curtain. When ready, the curtain
swings to Green — instantly, no intermission.

---

## 2. Anatomy of the swap

```
Step 1  Provision green (new version), no traffic
Step 2  Health-check green internally / via test listener
Step 3  Run pre-traffic validation hooks
Step 4  Flip production router blue → green   ◄── the cutover
Step 5  Run post-traffic validation hooks
Step 6  Hold (termination wait) — rollback window
Step 7  Terminate blue
```

---

## 3. On EC2 / Auto Scaling

Two approaches:

**A. CodeDeploy Blue/Green for EC2:**
- CodeDeploy provisions a **new ASG** (copy of the original), deploys to it,
  registers its instances with the ELB, shifts traffic, then deregisters/terminates
  the old ASG.

**B. Manual ALB target-group swap:**
- Keep `tg-blue` and `tg-green`. Deploy to green ASG, then modify the ALB
  listener default action to forward to `tg-green`.

```bash
aws elbv2 modify-listener \
  --listener-arn "$PROD_LISTENER" \
  --default-actions Type=forward,TargetGroupArn="$TG_GREEN"
```

---

## 4. On ECS (CodeDeploy)

This is the most common modern setup. See
[../aws/blue-green/README.md](../aws/blue-green/README.md) for the full CLI.

Key pieces:
- ECS service with `deploymentController.type = CODE_DEPLOY`.
- Two target groups + a production listener (and optional test listener).
- `appspec-ecs.yml` describing the task set + container/port + Lambda hooks.

CodeDeploy creates a **green task set**, optionally serves it on the test
listener, runs your validation Lambdas at each lifecycle event, flips the prod
listener, then drains blue after the termination wait.

---

## 5. On Lambda

Blue/Green for Lambda uses a **function alias** pointing at two versions and
weighted routing:

```bash
# Shift 100% to v2 behind the 'live' alias
aws lambda update-alias \
  --function-name my-api \
  --name live \
  --function-version 2
```

With CodeDeploy you instead use `LambdaAllAtOnce` (pure blue/green) or a canary
config for gradual shift. Pre/post-traffic hooks validate before/after the flip.

---

## 6. The database problem

Blue/Green isolates **compute**, but blue and green usually share **one database**.
This means schema changes must be **backward & forward compatible** during the
overlap. Use the **expand/contract (parallel change)** pattern:

```
Expand:   add new column/table (nullable, additive) — old code ignores it
Migrate:  deploy new code that writes both old + new
Contract: once all traffic is on new code, drop the old column
```

⚠️ Never do a destructive migration (drop/rename column) in the same release
that flips traffic — it breaks blue if you need to roll back.

---

## 7. Rollback

The headline feature: **rollback is a flip back to blue.**

- CodeDeploy: enable automatic rollback on alarm or failed hook; or manually
  "Stop and roll back" in the console.
- Because blue is still running during the termination wait, rollback is
  **seconds**, not a full redeploy.

```bash
aws deploy stop-deployment \
  --deployment-id d-XXXX \
  --auto-rollback-enabled
```

---

## 8. Pros, cons & cost

| ✅ Pros | ⚠️ Cons |
|--------|--------|
| Zero downtime | ~2× compute cost during deploy |
| Instant rollback | Shared DB still needs compatible schema |
| Full pre-prod validation | More infra to manage (2 TGs, listeners) |
| Clean (one version live at a time) | Long-lived connections/sessions need draining |

---

## 9. Checklist

- [ ] Two target groups created, both healthy
- [ ] Production listener + (optional) test listener configured
- [ ] ECS service uses `CODE_DEPLOY` controller
- [ ] `appspec-ecs.yml` + `taskdef.json` produced by the build
- [ ] Validation Lambda hooks return Succeeded/Failed
- [ ] CloudWatch alarms wired to auto-rollback
- [ ] DB migrations follow expand/contract
- [ ] Termination wait long enough to catch issues (e.g. 5–15 min)

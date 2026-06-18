# Module 13 — Docker & ECS Troubleshooting Handbook

> Symptom → likely causes → diagnostic commands → fix. Organized by layer: Docker build, Docker run, ECR/pull, task startup, networking/ALB, deployments, performance, and cost. Keep this open while you operate.

---

## A. Docker Build Fails

| Symptom | Likely cause | Fix |
|---|---|---|
| `COPY failed: no source files` | Path wrong / file in `.dockerignore` | Check build context + `.dockerignore` |
| Build is slow every time | Bad layer order; deps copied with code | Copy `package*.json` + install **before** `COPY . .` ([M2 §3](02-images.md)) |
| Image is huge (GBs) | Single-stage, dev deps, no slim base | Multi-stage build + `-alpine`/`-slim` ([M2 §4](02-images.md)) |
| `npm ci` fails: no lockfile | No `package-lock.json` in context | Commit the lockfile or use `npm install` |
| Secrets ended up in image | `COPY . .` pulled `.env` | Add to `.dockerignore`; rotate the secret 🔒 |

```bash
docker build --progress=plain --no-cache -t app .   # see every step, ignore cache
docker history app                                  # find the fat layer
```

---

## B. Container Won't Start / Exits Immediately

```bash
docker ps -a                  # read the STATUS exit code
docker logs <container>       # the actual error
docker inspect <c> -f '{{.State.ExitCode}} {{.State.Error}}'
```

| Exit code | Meaning | Fix |
|---|---|---|
| `127` | command not found | Wrong path in `CMD`/`ENTRYPOINT`; file not copied |
| `126` | not executable | `chmod +x` the entrypoint script |
| `1`/`2` | app error | Read logs — bad config/env, can't reach DB |
| `137` | **OOM** killed | Raise `--memory` / task memory; fix leak |
| `139` | segfault | Native dep/arch mismatch |
| `exec format error` | **wrong CPU arch** | Build `--platform linux/amd64` for Fargate ([M9 §5](09-ecr.md)) |

⚠️ Container exits "successfully" right away → your `CMD` ran a one-shot command instead of a long-running process (e.g. ran a script that returns). The main process must stay in the foreground.

---

## C. Can't Pull Image (ECR) — `CannotPullContainerError`

The single most common ECS failure. Causes:

| Cause | Check | Fix |
|---|---|---|
| Execution role lacks ECR perms | Role policy | Attach `AmazonECSTaskExecutionRolePolicy` ([M9 §8](09-ecr.md)) |
| No network route to ECR | Subnet/NAT/endpoints | Add NAT Gateway **or** VPC endpoints (ecr.api, ecr.dkr, S3, logs) ([M8 §4](08-fargate.md)) |
| Wrong image tag / repo | Tag exists in ECR? | `aws ecr describe-images --repository-name X` |
| Immutable tag overwrite attempt | Push rejected | Bump the version tag |
| Cross-account repo | Repo policy | Add resource-based policy granting the role |

```bash
# does the tag actually exist?
aws ecr describe-images --repository-name hrms-auth --image-ids imageTag=1.4.2
# read the exact stopped reason:
aws ecs describe-tasks --cluster hrms --tasks <task-id> \
  --query 'tasks[0].{stopped:stoppedReason,containers:containers[].reason}'
```

---

## D. Task Stuck in PENDING / Never Reaches RUNNING

```bash
aws ecs describe-services --cluster hrms --services hrms-auth-svc \
  --query 'services[0].events[0:5]'      # ← the events array explains why
aws ecs describe-tasks --cluster hrms --tasks <task-id> \
  --query 'tasks[0].stoppedReason'
```

| Service event / reason | Meaning | Fix |
|---|---|---|
| `unable to place a task because no container instance met requirements` | EC2 launch type, no room | Scale the ASG / right-size tasks ([M12 §4](12-clusters.md)) |
| `CannotPullContainerError` | see §C | NAT/endpoints + execution role |
| `ResourceInitializationError: unable to pull secrets` | Execution role can't read Secrets Manager | Grant `secretsmanager:GetSecretValue` + `kms:Decrypt` ([M10 §4](10-task-definitions.md)) |
| Invalid `cpu`/`memory` | Bad Fargate combo | Pick a valid combo ([M8 §2](08-fargate.md)) |
| Subnet has no route | Stuck pulling | Private subnet needs NAT or endpoints |

---

## E. Tasks Start Then Get Killed (Deploy Kill-Loop)

| Symptom | Cause | Fix |
|---|---|---|
| New tasks register then drain repeatedly | ALB health check failing | Fix health path → return 200; check container port |
| Killed during boot | Grace period too short | Raise `health-check-grace-period-seconds` ([M11 §2](11-services.md)) |
| Container health check fails on slow start | `startPeriod` too low | Increase `startPeriod` in task def health check |
| Deploy rolls back automatically | Circuit breaker tripped (tasks never healthy) | Read why tasks fail (logs/events) before retrying |

```bash
# is the ALB target healthy?
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[].TargetHealth'
```
⚠️ Health check port/path mismatch is the #1 cause: target group checks `/health` on port 5000 but the app serves `/api/health` or listens on 8080 → endless unhealthy → 502.

---

## F. 502 / 503 / 504 Through the ALB

| Code | Meaning | Common cause |
|---|---|---|
| **502 Bad Gateway** | ALB reached the task but got an invalid response | App crashed, wrong container port, app not listening on 0.0.0.0 |
| **503 Service Unavailable** | No healthy targets | All tasks unhealthy / desired=0 / deploy in progress |
| **504 Gateway Timeout** | Task too slow | App slow / DB slow; raise timeout, scale out |

```bash
aws ecs describe-services --cluster hrms --services hrms-auth-svc \
  --query 'services[0].{running:runningCount,desired:desiredCount}'
```
⚠️ App listening on `127.0.0.1` instead of `0.0.0.0` → ALB can't reach it → 502. In `awsvpc` always bind `0.0.0.0:<port>`.

---

## G. Networking / Service-to-Service

| Symptom | Cause | Fix |
|---|---|---|
| Task can't reach RDS | Security group | RDS SG must allow the task SG on 3306 |
| Task can't reach internet/ECR | No NAT/endpoint | Add NAT GW or VPC endpoints ([M8 §4](08-fargate.md)) |
| auth→employee call fails | No service discovery / wrong DNS | Use Service Connect/Cloud Map name ([M11 §7](11-services.md)) |
| `localhost` between services fails | Different tasks | Only same-task containers share localhost; cross-task uses ALB/Cloud Map |
| Local Compose: "host not found: db" | Default bridge (no DNS) | Use a user-defined network / Compose ([M5 §2](05-networks.md)) |

```bash
# from a debug task on the same SG/subnet:
nc -zv hrms-db.xxxx.rds.amazonaws.com 3306
```

---

## H. Performance & Resource Issues

| Symptom | Cause | Fix |
|---|---|---|
| Exit `137` / OOM | Memory limit too low / leak | Raise task memory; check CloudWatch `MemoryUtilization`; profile |
| CPU pegged, latency high | Under-provisioned / no autoscaling | Raise task cpu; add target-tracking autoscaling ([M11 §6](11-services.md)) |
| Thundering scale-out then in | Cooldowns too short | Tune ScaleIn/ScaleOut cooldowns |
| Slow cold starts | Big image / heavy init | Slim image; raise grace period; keep min tasks warm |
| Logs missing | No `awslogs` config / log group | Add log config; create the group ([M10 §5](10-task-definitions.md)) |

```bash
docker stats                       # local: live CPU/mem
# ECS: CloudWatch → Container Insights → service CPU/Memory utilization
```

---

## I. Volumes / Data

| Symptom | Cause | Fix |
|---|---|---|
| Data gone after restart | Wrote to container layer, not a volume | Mount a named volume / EFS ([M4](04-volumes.md)) |
| EFS mount fails on Fargate | SG / mount target / IAM | EFS SG allow 2049 from task SG; access point + `iam:ENABLED` |
| `docker volume prune` wiped DB | Pruned an unattached data volume | Back up volumes; never prune blindly |
| Permission denied on mount | UID mismatch (non-root user) | Match `USER` UID to volume ownership / fix EFS access point uid |

---

## J. Cost Surprises

| Symptom | Cause | Fix |
|---|---|---|
| Fargate bill higher than expected | Over-sized tasks / never scale in | Right-size cpu/mem; aggressive scale-in; Fargate Spot ([M8](08-fargate.md)) |
| Charges after "deleting everything" | ALB + NAT GW + RDS + EFS still live | Delete LB, NAT, RDS, EFS; release EIPs |
| ECR storage creeping up | Old images never expire | Lifecycle policy ([M9 §7](09-ecr.md)) |
| NAT data-transfer cost | All task egress via NAT | Add VPC endpoints (ECR/S3/logs) to bypass NAT |

---

## 🔧 First-Response Playbook (memorize this order)

```
1. aws ecs describe-services ... --query 'services[0].events[0:5]'   ← WHY (placement/pull/health)
2. aws ecs describe-tasks ... --query 'tasks[0].stoppedReason'        ← exact stop reason
3. CloudWatch Logs /ecs/<service>                                     ← the app's own error
4. aws elbv2 describe-target-health ...                               ← is the target healthy?
5. Security groups + subnet routes (NAT/endpoints)                    ← can it reach things?
6. Task def: cpu/mem combo, ports, roles, secrets                     ← blueprint sane?
```
💡 90% of ECS problems are answered by **service events + stoppedReason + the app logs**. Look there before changing anything.

---

➡️ Next: put it all together in the [Capstone — HRMS Container Deployment](project/README.md).

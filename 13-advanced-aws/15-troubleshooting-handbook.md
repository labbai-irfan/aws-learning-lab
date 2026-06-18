# Module 15 — Advanced AWS Troubleshooting Handbook

> Production problems across CloudFront, ElastiCache, SQS/SNS, Terraform, WAF, and multi-account setups. Root cause + fix for each.

---

## CloudFront

### Cache-hit ratio very low (< 50%)
🔎 Check: are query strings/headers/cookies in the cache key unnecessarily? Dynamic session cookies polluting static asset cache?
🛠️ Remove unnecessary cache-key components from the cache policy. Separate behaviours: `/static/*` (no cookie forwarding) vs `/api/*` (pass all headers). Check `CacheHitRate` per behaviour.

### Origin getting all traffic (cache-hit = 0)
🔎 `Vary` header on origin response; origin returns `Cache-Control: no-store`; TTL set to 0.
🛠️ Fix origin cache headers; check `DefaultTTL` in cache policy; if Vary: * → CloudFront won't cache.

### 502/504 from CloudFront
🔎 Origin unreachable or slow. Check: origin health (ALB target health), SG allows CloudFront IP ranges (or use `aws:SourceAccount` / OAC for S3), origin response time > CloudFront timeout (60s read timeout for ALB origins).
🛠️ Check ALB access logs for 502 to the origin; verify SG on ALB allows `0.0.0.0/0:443` for internet-facing or whitelisted CF IP ranges; increase origin timeout in distribution settings.

### SSL certificate error (CN mismatch)
🔎 ACM cert for CloudFront must be in **us-east-1**, not the edge location's region.
🛠️ Request cert in us-east-1; select in distribution.

### Lambda@Edge function not executing
🔎 Wrong trigger (viewer vs origin), function region must be `us-east-1`, IAM trust for `edgelambda.amazonaws.com`.
🛠️ Check trigger type and event structure; ensure function is in us-east-1; check execution role trust.

### CloudFront returning stale content after deploy
🔎 Cache still serving old version; no invalidation.
🛠️ Use versioned filenames (`main.abc123.js`) to bust cache automatically; or create an invalidation on `/*` (costly). Better: adopt versioned asset pipeline.

---

## ElastiCache / Redis

### Evictions > 0 (losing cached data)
🔎 Memory full; `maxmemory-policy` is evicting keys you need.
🛠️ Scale up node class; reduce TTLs on less-important keys; review `allkeys-lru` policy; check for keys with no TTL consuming all memory.

### High connection count / ECONNRESET
🔎 App opening many connections without releasing; connection pool not reusing.
🛠️ Share a single Redis client instance (not creating per-request); use connection pool; increase `maxclients` parameter if legitimate.

### Replica lag high (ReplicationLag > 5s)
🔎 Replica undersized vs primary; large key operations (KEYS *, SORT, SMEMBERS on huge sets) blocking replication.
🛠️ Upgrade replica; avoid `KEYS *` in production (use SCAN); break large set operations.

### Cluster mode — CROSSSLOT error
🔎 Multi-key operation where keys map to different hash slots.
🛠️ Use hash tags: `{user42}.session` and `{user42}.profile` → same slot. Or switch to pipeline/Lua on same slot.

### AUTH failure after rotation
🔎 ElastiCache RBAC/AUTH token was rotated but app still uses old token.
🛠️ Update Secrets Manager / env with new token; implement rotation-aware retry in the app.

---

## SQS / SNS

### Messages piling up in queue (queue depth rising)
🔎 Consumers failing or too slow; `VisibilityTimeout` too short → re-queuing.
🛠️ Check DLQ count (find failing messages); increase `VisibilityTimeout` to > max processing time; scale consumers based on queue depth.

### Messages appearing multiple times (at-least-once)
🔎 Standard SQS is at-least-once; consumer didn't delete before visibility timeout expired.
🛠️ Make consumers **idempotent** (check if already processed); use FIFO queue with content deduplication for exactly-once.

### DLQ growing (maxReceiveCount hit)
🔎 Consumer bug crashing on specific messages; poison message.
🛠️ Check the DLQ message body for the bad pattern; fix consumer; replay DLQ after fix (`start-message-move-task` for dead-letter queue redrive).

### SNS → SQS delivery failure
🔎 SQS queue policy doesn't allow SNS to send; encryption mismatch (KMS).
🛠️ Queue policy: `aws:SourceArn` allows the SNS topic ARN; if KMS-encrypted, grant SNS key usage.

### Lambda not triggering from SQS
🔎 Event source mapping disabled; Lambda concurrency limit reached; SQS batch size too large.
🛠️ Check event source mapping state; check Lambda throttle metrics; reduce batch size; increase reserved concurrency.

---

## Terraform

### State lock not releasing (DynamoDB lock stuck)
🔎 A previous `terraform apply` crashed mid-run; lock entry remains.
🛠️ Verify no apply is actually running; `terraform force-unlock LOCK_ID` (with caution).

### Resource already exists (conflict on apply)
🔎 Resource was created manually outside Terraform.
🛠️ `terraform import resource_type.name resource_id` → bring it under state control.

### Diff shows unwanted destroy on every plan
🔎 `lifecycle { ignore_changes }` missing for AWS-managed attributes; or resource depends on computed value that changes.
🛠️ Add `ignore_changes = [attribute]`; or use `terraform state rm` + `terraform import` if the resource was recreated.

### Module version conflict
🔎 Two modules requiring different versions of the same provider.
🛠️ Align provider version constraints; use `required_providers` consistently.

### `terraform apply` succeeded but infra not working
🔎 The apply worked but a downstream issue (SG wrong, IAM missing, param wrong) prevents function.
🛠️ Read Terraform output for resource ARNs; check CloudWatch / CloudTrail for the error after the apply.

---

## CloudFormation

### Stack stuck in UPDATE_ROLLBACK_FAILED
🔎 Rollback failed on a resource it can't roll back (e.g., resource was manually deleted after the stack owned it).
🛠️ `aws cloudformation continue-update-rollback --skip-resources LogicalId`. Use sparingly; understand what you're skipping.

### Nested stack CREATE_FAILED
🔎 Parent stack's `TemplateURL` is wrong or template is invalid YAML.
🛠️ Check `aws cloudformation describe-stack-events --stack-name child-stack` for root cause.

### Export already exists (cross-stack conflict)
🔎 Two stacks trying to export the same name.
🛠️ Make export names unique with `!Sub "${Env}-${AWS::StackName}-VpcId"`.

### StackSet deployment failing in some accounts
🔎 Target account lacks the `AWSCloudFormationStackSetExecutionRole`; or SCPs blocking.
🛠️ Ensure roles exist in member accounts; check SCP denies; use `SERVICE_MANAGED` permission model with Org trusted access where possible.

---

## WAF

### Legitimate traffic blocked (false positive)
🔎 Managed rule set firing on valid request (e.g. SQL keyword in a product name).
🛠️ Set the offending rule to **Count** mode; identify false-positive URIs; add a rule exception (scope-down statement) before re-enabling Block.

### WAF not blocking attacks
🔎 Rule group still in **Count** mode (forgot to switch to Block).
🛠️ Review `BlockedRequests` metric; confirm default action is Allow + rules are Block.

### Rate limit not applying
🔎 Wrong aggregate key; rate limit too high; rule priority after an Allow rule that already passes the request.
🛠️ Rule priority matters — move rate-limit rule higher in priority list; verify aggregate key type.

---

## Multi-Account / Organizations

### SCP blocking a needed action
🔎 `aws: AccessDenied -- Service control policy blocks this action`.
🛠️ CloudTrail → find the denied event → identify the SCP → add a specific exception or adjust the SCP scope. **Never relax SCPs globally** — add targeted exceptions.

### Cross-account role assumption fails
🔎 Trust policy on target role doesn't trust the source; or SCP on target account denies `sts:AssumeRole`.
🛠️ Verify trust policy on target role (`sts:AssumeRole` from source account ARN); check for SCP deny.

### GuardDuty finding in wrong account (aggregation issue)
🔎 Delegated admin not properly set up; finding source account not linked.
🛠️ In Security Tooling account: confirm org-level GuardDuty delegated admin; verify member accounts are enrolled.

---

## Quick triage decision tree
```
Site down?       → CloudFront 5xx → check origin health → ALB → ECS/EC2
Slow?            → CloudFront cache miss? → ElastiCache hit? → DB query?
Data not fresh?  → CloudFront TTL / invalidation / cache policy
Messages stuck?  → SQS DLQ? → consumer crash? → visibility timeout?
IaC broken?      → state lock? → drift? → import orphaned resource?
Blocked by SCP?  → CloudTrail → identify SCP → targeted exception
```

➡️ Next: [Module 16 — 200 Interview Questions](16-200-interview-questions.md)

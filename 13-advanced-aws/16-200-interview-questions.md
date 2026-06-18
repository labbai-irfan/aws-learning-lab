# Module 16 — 200 Advanced AWS Interview Questions

> Architect-level answers. Group: A=CloudFront, B=ElastiCache/Redis, C=SQS/SNS, D=Terraform, E=CloudFormation, F=WAF/Shield, G=Organizations, H=Enterprise Arch, I=Multi-Region/DR, J=Scalability, K=Security, L=DevOps, M=SaaS/Multi-Tenant.

---

## A. CloudFront (1–20)
1. **What is an origin access control (OAC) and why is it preferred over OAI?** OAC uses a signed request tied to the distribution ARN and supports all S3 features (SSE-KMS, multi-region access points); OAI is legacy and doesn't support KMS-encrypted buckets.
2. **How do you reduce CloudFront origin hits for a React SPA?** Serve hashed JS/CSS from S3 with long TTL (1yr); serve `index.html` with short TTL (5min) or no-cache; CloudFront Functions for URL rewriting.
3. **What triggers a CloudFront cache miss?** New URL/query string, object expired (TTL passed), cache invalidation, first request to a POP.
4. **When would you use Lambda@Edge vs CloudFront Functions?** CF Functions: fast, cheap, viewer-request/response only (URL rewrites, header injection). Lambda@Edge: body manipulation, origin-request auth, multi-origin routing, any runtime beyond JS.
5. **How do you implement A/B testing at the edge?** Lambda@Edge origin-request trigger: read/set a cookie with a variant (A/B); route to different origin paths or set different headers.
6. **What is a field-level encryption use case?** PCI: encrypt credit card numbers at the edge with a public key; only the payment service (which holds the private key) can decrypt.
7. **How does CloudFront integrate with WAF?** Attach a WAF Web ACL (must be in us-east-1 global scope) to the distribution; rules execute per request at the POP before origin.
8. **What is the TTL hierarchy in CloudFront caching?** `MinTTL` (floor) ≤ origin `max-age` ≤ `MaxTTL` (ceiling). If origin sends `Cache-Control: no-cache`, CloudFront respects it (doesn't cache).
9. **How do you debug low cache-hit ratio?** Check cache policy — are unneeded query strings/cookies in the cache key? Check `Vary` response header; check origin `Cache-Control` headers; use CloudFront access logs + Athena.
10. **How do signed URLs work?** Generate a URL with HMAC-SHA1 signature using a CloudFront key pair; includes `Expires`, `Key-Pair-Id`, `Signature` parameters; CloudFront validates before serving.
11. **What's the difference between distributions and behaviours?** One distribution, many behaviours (path patterns). Each behaviour has its own origin, cache policy, viewer protocol policy, and Lambda@Edge associations.
12. **Can CloudFront deliver dynamic content?** Yes — set cache TTL to 0 and pass all headers/cookies to origin. CloudFront still adds DDoS protection and global network even without caching.
13. **How do you restrict CloudFront access by country?** Geo-restriction in distribution settings (allow/deny list) or Lambda@Edge for complex per-request logic.
14. **What is continuous deployment in CloudFront?** A two-stage feature: a staging distribution receives a percentage of traffic for safe testing; promote to primary when validated.
15. **How do you handle SPA 404s in CloudFront?** Custom error response: intercept 403/404 from S3, return `index.html` with 200 and short TTL. The SPA router handles the path client-side.
16. **What is Origin Shield?** An additional regional caching layer between POPs and the origin; collapses cache-miss requests from multiple POPs into one, reducing origin load.
17. **How do you integrate CloudFront with API Gateway?** API Gateway as a custom HTTPS origin; set cache TTL 0 for REST APIs, or use API Gateway's own caching for specific methods.
18. **What happens if you invalidate `/*`?** All cached objects are removed from all POPs; next requests fetch from origin. Costs ~$0.005 per path after 1,000/month free.
19. **How do you monitor CloudFront performance?** CloudWatch: `CacheHitRate`, `5xxErrorRate`, `OriginLatency`, `BytesDownloaded`; access logs → Athena; Real-time logs → Kinesis for dashboards.
20. **Can one distribution have multiple origins in different regions?** Yes — one per origin; use origin groups for failover (primary + secondary origin). Failover on 5xx or timeout.

---

## B. ElastiCache & Redis (21–40)
21. **Cluster mode vs non-cluster mode — trade-offs?** Cluster: horizontal write scaling, multiple shards, needs cluster-aware client, multi-key ops restricted. Non-cluster: simpler client, one shard (max 500 GB), reads scale with replicas.
22. **How do you implement a distributed lock with Redis?** SET with NX (not-exists) + EX (expiry); or use Redlock (multiple Redis nodes for high availability). Always set a TTL to avoid deadlock.
23. **What is the Redlock algorithm and its controversy?** Acquire lock on N/2+1 independent Redis nodes; release all on failure. Controversy: Martin Kleppmann argues it fails under partial failures/network partitions; use with caution.
24. **Cache-aside vs read-through — key difference?** Cache-aside: app manages cache explicitly (miss → DB → write cache). Read-through: cache layer auto-fetches from DB on miss (transparent to app). Cache-aside is more common and gives more control.
25. **What eviction policy for a session store?** `noeviction` — sessions must not be silently evicted; a full cache should return an error, not drop sessions.
26. **How do you handle cache stampede (thundering herd)?** On cache miss: use a distributed lock to allow only one request to populate the cache while others wait, or return stale data while revalidating asynchronously.
27. **What is probabilistic early expiration?** Recompute a cache value slightly before it expires (random jitter); avoids all clients missing simultaneously.
28. **How do you size an ElastiCache cluster?** Identify hot dataset size; target `used_memory` < 70% of `maxmemory`; pick node class where `FreeableMemory` stays > 20%.
29. **Redis pub/sub vs SQS — when each?** Pub/sub: ephemeral, fire-and-forget, no persistence, no replay, low latency. SQS: durable, at-least-once, backpressure, retry, dead letter. For reliable messaging use SQS.
30. **What metrics indicate a Redis problem?** Evictions > 0 (memory), ReplicationLag (replica behind), CacheMisses high (bad key design), CPUUtilization > 90%, SwapUsage > 50 MB.
31. **How do you do zero-downtime ElastiCache upgrade?** For cluster mode disabled: use online upgrade (minor) or blue/green approach (create new cluster, warm it, switch endpoint). For major version: snapshot → restore + re-warm.
32. **What is ElastiCache Serverless?** Fully managed, auto-scales from zero; pay per GB cached + ECU. No node provisioning. Suitable for unpredictable/spiky workloads.
33. **How do you implement rate limiting with Redis sorted sets?** ZREMRANGEBYSCORE (remove old events) → ZCARD (count in window) → if count < limit: ZADD + EXPIRE → allow; else → deny.
34. **How do you warm a cache on deployment?** Pre-populate top-N keys from DB before switching traffic; or use cache-aside with an aggressive warmup Lambda/script against the new cluster.
35. **What is the difference between TTL and maxmemory-policy?** TTL is per-key expiry (set by the app). maxmemory-policy is what Redis does when memory is full regardless of TTL.
36. **Can ElastiCache Redis persist data?** Yes — AOF (Append Only File) and/or RDB snapshots. Enabled via parameter group. But ElastiCache for Redis is primarily used as a cache; for durable storage use RDS.
37. **How do you handle a hot key?** Read hot keys to Redis read replicas; shard the key across multiple keys (`key:shard:0..N`); use local in-process cache for extreme-hot keys; enable `active-expire-enabled` = 0.
38. **Redis CLUSTER KEYSLOT — when do you use it?** To determine which slot a key maps to; useful for ensuring keys in a pipeline belong to the same slot in cluster mode.
39. **What is the lazy freeing feature?** Background deletion of large keys (lazyfree-lazy-expire = yes) avoids blocking the event loop on large UNLINK operations.
40. **How do you monitor Redis in production?** INFO all stats; `slowlog get 20`; monitor latency with `redis-cli --latency`; CloudWatch `CurrConnections`, `Evictions`, `ReplicationLag`.

---

## C. SQS & SNS (41–60)
41. **Standard vs FIFO — when does "at-least-once" matter?** Always in standard SQS. You MUST make consumers idempotent (idempotency key in DB, or deduplicate on processing). FIFO gives exactly-once within 5-min deduplication window.
42. **What happens when VisibilityTimeout expires before processing finishes?** Message becomes visible again and another consumer picks it up → duplicate processing → idempotency is critical.
43. **How do you handle a poison message?** It fails `maxReceiveCount` times → DLQ. Inspect the message; fix consumer; redrive DLQ. Use a `RedrivePolicy` with a separate DLQ for each queue.
44. **What is long polling and why use it?** `WaitTimeSeconds` up to 20s — SQS holds the request until a message arrives. Reduces empty `ReceiveMessage` API calls → cost and latency savings.
45. **Fan-out pattern — walk me through it.** Publisher sends to SNS topic; topic fans out to N SQS queues (one per subscriber service); each service processes independently and at its own rate. Add filter policies to deliver only relevant messages.
46. **How does SNS message filtering work?** Each SQS/Lambda subscriber has a filter policy (JSON); only messages whose attributes match are delivered. Reduces downstream cost and noise.
47. **How do you ensure message ordering with SQS FIFO?** Set `MessageGroupId` (ordering scope); messages with the same group ID are delivered in FIFO order; different group IDs process in parallel.
48. **What is the SQS extended client library?** Offloads payloads > 256 KB to S3; SQS message contains the S3 key. Transparent to the consumer.
49. **How do you scale SQS consumers automatically?** ASG/ECS target tracking on `ApproximateNumberOfMessagesVisible / running-task-count`; or Lambda event source mapping (auto-scales natively).
50. **Difference between SNS and EventBridge?** SNS: simple pub/sub, fan-out by topic, basic filtering. EventBridge: richer event patterns, schema registry, archive/replay, cross-account routing, scheduled rules, partner integrations.
51. **How do you cross-account publish to SQS?** Queue resource policy allows the source account/SNS topic ARN to `sqs:SendMessage`. No cross-account Lambda needed.
52. **How do you replay dead-letter messages?** `aws sqs start-message-move-task --source-arn DLQ-ARN --destination-arn MAIN-QUEUE-ARN` (SQS DLQ redrive). Or write a Lambda to read DLQ → re-publish to main queue.
53. **What causes SQS message duplication?** Network errors causing producer to retry; consumer failing to delete within visibility timeout. Both: implement idempotency key pattern.
54. **How do you monitor SQS health?** `ApproximateAgeOfOldestMessage` (lag), `ApproximateNumberOfMessagesVisible` (backlog), `NumberOfMessagesSent/Received/Deleted`, DLQ `ApproximateNumberOfMessagesVisible` (non-zero = consumer bug).
55. **What is SQS delivery delay?** `DelaySeconds` (0–900s) makes new messages invisible on arrival. Useful for processing later (e.g. send follow-up email 10 min after signup).
56. **How does SNS FIFO work?** Ordered, deduplicated fan-out; requires SQS FIFO subscribers; same message group semantics. Use for ordered events across multiple consumers.
57. **When to use SQS vs Kinesis?** SQS: task queue (each message processed once, by one consumer, no replay). Kinesis: event stream (replay, multiple consumer groups, ordered shard, analytics, real-time).
58. **How do you secure SNS?** KMS encryption at rest; HTTPS-only delivery; resource policy for cross-account publish; subscription filter to limit what each endpoint receives.
59. **What is a temporary queue in SQS?** A short-lived queue created dynamically (e.g. per-request reply queue for request-response pattern). Use SQS Temporary Queue Client for efficient management.
60. **How does Lambda handle partial SQS batch failures?** With `ReportBatchItemFailures` response; Lambda function returns `batchItemFailures` list → only failed messages go back to queue; successful messages deleted. Prevents full batch re-processing.

---

## D. Terraform (61–80)
61. **What is Terraform state and why must it be remote?** State tracks the mapping between config and real resources. Remote state (S3+DynamoDB) enables team collaboration, locking, and history. Local state is lost on machine loss.
62. **Explain `terraform plan`'s dependency graph.** Terraform builds a DAG of resources; applies creates/modifies leaves first and works toward roots. Destroys in reverse. `depends_on` adds explicit edges.
63. **How do you refactor a module without destroying resources?** Use `moved` blocks to declare renames; Terraform updates state without destroying/recreating.
64. **What's the danger of `-target`?** It bypasses the full graph; can leave state inconsistent (unapplied dependencies). Use only for emergency fixes.
65. **How do you manage secrets in Terraform?** Variables marked `sensitive = true`; populate from environment variables or Vault; never commit `terraform.tfvars` with secrets; use `data.aws_secretsmanager_secret_version` to fetch at plan/apply time.
66. **What is a Terraform workspace?** Isolated state per workspace (dev/staging/prod from same config directory). Simpler than directories for identical environments; less safe for environments that differ.
67. **How do you test Terraform?** `terraform validate` (syntax); `tflint` (linting); `tfsec`/`checkov` (security); Terratest (Go-based integration tests that apply, assert, and destroy).
68. **What is the `for_each` vs `count` distinction?** `count` is index-based (reordering causes destroy/recreate); `for_each` is map-keyed (stable references; preferred for non-trivial resource sets).
69. **Explain Terraform providers and version constraints.** Providers are plugins interfacing to APIs; `~> 5.0` means ≥ 5.0.0 and < 6.0.0. Lock with `.terraform.lock.hcl` for deterministic builds.
70. **How do you handle Terraform drift?** `terraform plan` shows drift. For intentional AWS-managed changes: `ignore_changes`. For unwanted drift: `terraform apply` to reconcile. Run `plan` in CI on a schedule.
71. **What is the `lifecycle` block used for?** `prevent_destroy` (block accidental delete), `ignore_changes` (ignore AWS-managed attributes), `create_before_destroy` (avoid downtime on recreation), `replace_triggered_by`.
72. **How do you implement a multi-region deployment in Terraform?** Multiple `provider "aws"` blocks with different `alias` and `region`; pass `provider = aws.eu` to resources in the EU region. Or module per region with provider injection.
73. **What is Terragrunt?** A thin Terraform wrapper that adds DRY config, remote-state backend config, dependency ordering across modules, and account/region iteration for multi-account deployments.
74. **How do you do blue/green in Terraform?** Maintain two sets of resources; use weighted Route 53 records or ALB listener rules to shift traffic between blue and green; variable controls which set is active.
75. **What is OIDC-based Terraform CI auth?** GitHub Actions assumes an AWS IAM role via OIDC federation — no stored AWS credentials. Role trust policy restricts to specific repo/branch.
76. **How do you import a resource that was created manually?** `terraform import aws_security_group.app sg-0abc123` → resource appears in state; write matching config; run `plan` to confirm zero diff.
77. **What does `data` source do vs a `resource`?** `data` reads existing infrastructure (not managed by this Terraform); `resource` creates and manages.
78. **How do you handle large-scale Terraform with 1,000+ resources?** Split into separate state roots by domain (network / compute / data); use module composition; Terragrunt for orchestration; Spacelift/Terraform Cloud for execution.
79. **Explain `terraform output` and cross-stack references.** `output` exposes values; read from another root with `terraform_remote_state` data source (pointing to the remote state backend). Alternative: use SSM Parameter Store to pass values between roots.
80. **What is the difference between `null_resource` and `terraform_data`?** Both are logic-only resources with no AWS counterpart; `terraform_data` (Terraform ≥ 1.4) is the official replacement for `null_resource`; use for triggers and `local-exec` provisioners.

---

## E. CloudFormation (81–95)
81. **What is a CloudFormation change set?** A preview of changes before execution; shows add/modify/delete/conditional per resource. Mandatory practice for production stacks.
82. **How does CloudFormation handle rollback?** On failure, automatically rolls back to the last stable state by deleting/restoring changed resources. `--disable-rollback` for debugging.
83. **What is `DependsOn` used for?** Explicit ordering when CloudFormation can't infer dependency from `!Ref`/`!GetAtt`. Overused — prefer implicit dependencies.
84. **How do StackSets work with AWS Organizations?** `SERVICE_MANAGED` permission model uses Org trusted access; CloudFormation automatically deploys to new accounts in a target OU; scales as Org grows.
85. **What is drift detection?** Compares actual resource config vs the CloudFormation template's expected config; highlights manual changes that break IaC purity.
86. **What is the CDK and how does it relate to CloudFormation?** CDK synthesizes CloudFormation templates from code (TypeScript/Python/etc.); enables unit testing, abstraction, and reuse of CloudFormation with a real programming language.
87. **What is a CloudFormation macro?** Transform that processes the template before CFN executes it; AWS provides `AWS::Serverless::Transform` (SAM) and `AWS::Include`; you can write custom macros via Lambda.
88. **How do you pass secrets into CloudFormation without exposing them?** `NoEcho: true` on parameters; or use `{{resolve:ssm-secure:/path}}` / `{{resolve:secretsmanager:arn}}` dynamic references — never hardcode.
89. **What happens when a nested stack's update fails?** The parent stack rolls back, which triggers rollback of all nested stacks. Nested stack failures can cascade.
90. **Cross-stack reference limitations?** Cannot delete a stack that exports a value imported elsewhere; cannot rename an export without breaking consumers; tightly couples stack lifecycle.
91. **What is `CreationPolicy` and `WaitCondition`?** Signal from EC2/ECS that it's ready before CloudFormation considers the resource create complete — prevents premature stack completion.
92. **When would you use CloudFormation vs CDK?** Pure YAML preference: CloudFormation. Code, abstraction, unit tests, L2/L3 constructs: CDK. Both generate the same underlying CFN; CDK is generally better for complex new projects.
93. **How do you update a CloudFormation stack with zero downtime?** Use change sets to preview; for ASG/ECS resources use update policies (`AutoScalingRollingUpdate`); for RDS use Multi-AZ (failover during modification).
94. **What is `UpdateReplacePolicy`?** Determines what happens to a replaced resource (e.g. when a property change requires recreation): `Delete`, `Retain`, or `Snapshot` (for RDS/EBS).
95. **How do you debug a CloudFormation stack failure?** `describe-stack-events` for the exact error; check `CREATE_FAILED` resource and reason; for nested stacks drill into child stack events.

---

## F. WAF & Shield (96–110)
96. **WAF Web ACL scope — global vs regional?** Global (us-east-1): for CloudFront. Regional: for ALB, API GW, AppSync in a specific region. One ACL can't be shared between scopes.
97. **What is a rate-based WAF rule?** Counts requests from a source (IP or custom key) over a 5-min window; blocks when it exceeds the threshold. Effective against brute force and HTTP floods.
98. **How do you test WAF rules before blocking?** Set rules to **Count** mode; observe `CountedRequests` metric; check Sampled Requests for false positives; switch to Block when confident.
99. **What is WAF Bot Control?** A managed rule group that classifies bots (verified good bots like Googlebot, unverified bots, browser impersonators); allows/challenges/blocks by category.
100. **How does Shield Advanced differ from Standard?** Advanced adds: L7 protection (via WAF), SRT access, cost protection, health-based detection, and detailed attack diagnostics. Standard is free L3/L4 only.
101. **When does Shield Advanced make financial sense?** At scale ($3k/month is break-even vs potential attack costs); regulated industries; when you need SRT and cost protection.
102. **What is a WAF scope-down statement?** Narrows a rule to apply only to specific paths/headers — e.g. rate-limit rule only on `/api/login`, not all traffic.
103. **How do you block a DDoS in progress using WAF?** Rate-based rule with short window; IP set rule for the source ranges; WAF Bot Control; temporarily tighten rules while the attack is occurring.
104. **What is the IP reputation list managed rule group?** Blocks IPs known to AWS threat intelligence to be associated with bots, TOR exit nodes, and attack infrastructure.
105. **How do you implement per-tenant rate limiting in WAF?** Use a rate-based rule aggregated by a custom header (e.g. `X-Tenant-Id`); or aggregate by JWT claim extracted by Lambda@Edge.
106. **WAF logging — what's the recommended destination?** Kinesis Data Firehose → S3 → Athena for ad-hoc analysis; optionally → OpenSearch for real-time dashboards.
107. **How does WAF handle HTTP/2?** CloudFront handles the HTTP/2 → HTTP/1.1 translation; WAF sees standard HTTP headers.
108. **What is the CAPTCHA action in WAF?** Instead of Block, serves a CAPTCHA puzzle to the client; proven humans get a CAPTCHA token (JWT) valid for a configurable period.
109. **Can WAF protect against application-level zero-days?** Partially — managed rules are updated by AWS; you can add custom rules for known patterns. But advanced application-level 0-days may bypass WAF; complement with app-level input validation.
110. **How do you reduce WAF false positives for API traffic?** Apply managed rules with scope-down to web (not JSON API) paths; use label matching to selectively exclude trusted endpoints from specific rules.

---

## G. Organizations & Multi-Account (111–125)
111. **Why separate prod and dev in different accounts?** Blast radius isolation; independent IAM; independent service quotas; natural billing boundary; separate CloudTrail/audit.
112. **What does an SCP do that IAM can't?** SCP restricts what can happen in an account regardless of IAM — it's a guardrail above IAM. IAM grants within the SCP boundary.
113. **How is effective permission calculated with SCPs?** Intersection: (SCP) AND (IAM policy) AND (resource policy) AND (permission boundary). Any Deny at any layer wins.
114. **What is AWS Control Tower?** Managed service to set up a multi-account landing zone: creates the OU structure, security accounts, SCPs, and guardrails (detective + preventive) automatically.
115. **What is Account Factory for Terraform (AFT)?** Terraform-based account vending machine built on Control Tower; new accounts are provisioned via a PR to a Git repo → pipeline → Terraform → ready account.
116. **How do you enforce CloudTrail in every account?** Org-level CloudTrail in the management account; optionally SCP denying `cloudtrail:DeleteTrail` + `cloudtrail:StopLogging`.
117. **What is AWS RAM?** Resource Access Manager — shares resources cross-account: VPC subnets, TGW, Route 53 Resolver rules, ECR, License Manager configs. No resource copying.
118. **How do you centralise logging across accounts?** Org CloudTrail → S3 in Log Archive account (bucket policy allows all accounts to write); GuardDuty aggregated to Security Tooling; Config aggregator.
119. **What is a delegated administrator in AWS Organizations?** A member account authorised to manage an AWS service (GuardDuty, Security Hub, Config, etc.) on behalf of the Org, without needing management account credentials.
120. **How do you prevent accounts from leaving the Org?** SCP: `Deny: organizations:LeaveOrganization`.
121. **What is the sandbox OU pattern?** Time-limited accounts where developers experiment freely; auto-nuke Lambda or Service Catalog enforces budget limits and deletion after N days.
122. **How do cross-account role chains work?** Account A → assume Role B in Account B → assume Role C in Account C. Each trust relationship is explicit. Max 5 hops in session policy (limit on role chaining).
123. **What is consolidated billing benefit?** All accounts roll up to management account payer; EC2/RDS usage across accounts aggregates for Reserved Instance/Savings Plan discounts.
124. **How do you detect shadow IT (unapproved services) in accounts?** AWS Config + Config rules flagging unapproved resource types; GuardDuty + Security Hub findings; CloudTrail → EventBridge → Lambda alerts.
125. **What is the difference between an OU SCP and a resource policy?** SCP = applied to all IAM principals in the OU/account (a blanket restriction). Resource policy = attached to one resource (e.g. S3 bucket policy, SQS queue policy).

---

## H. Enterprise Architecture (126–140)
126. **Why Hub-and-Spoke with TGW over full-mesh VPC peering?** N accounts with peering = N(N-1)/2 connections; TGW = N connections. Simpler, centrally managed routing, inspection possible.
127. **What is an Inspection VPC?** A VPC with AWS Network Firewall or a 3rd-party NGFW; east-west traffic between spokes routes through it for deep packet inspection.
128. **How do you integrate on-prem with AWS?** Direct Connect (dedicated bandwidth, low latency), Site-to-Site VPN (cheaper, over internet), or both (DX primary + VPN backup).
129. **What is EventBridge cross-account routing?** Event bus in source account → rule targets event bus in destination account → destination rule → target (Lambda/SQS). Enables async decoupling across accounts.
130. **What is the CQRS pattern and when is it useful on AWS?** Separate write path (RDS + SQS + event store) from read path (ElastiCache / DynamoDB / Redshift read model). Use when read and write scaling needs differ significantly.
131. **How do you design for 10 million API calls/day on AWS?** CloudFront + API Gateway (edge-optimised); Lambda or ECS (auto-scale); DynamoDB (auto-scale); ElastiCache for hot reads; SQS for async heavy work.
132. **What is a service mesh on AWS?** App Mesh + Envoy sidecar: per-service traffic metrics, mTLS between services, retries/circuit-breaking without app code changes.
133. **How do you implement API versioning on AWS?** URL path (`/v1/`, `/v2/`) via ALB routing rules or API Gateway stages; header-based version (custom header → Lambda@Edge routing); subdomain-based.
134. **What is the strangler-fig pattern?** Incrementally replace a monolith by routing new functionality to microservices while old code handles existing paths; over time the monolith "dies."
135. **How do you share a private ECR registry across accounts?** ECR resource policy grants `ecr:GetDownloadUrlForLayer` + pull actions to the target account ID or Org. Use the central Shared Services account.
136. **What is AWS Global Accelerator?** Anycast network routing traffic to the nearest AWS edge location, then over the AWS backbone to the origin — improves latency and provides static IPs. Different from CloudFront: no caching, works for TCP/UDP, not just HTTP.
137. **How do you handle database migrations in zero-downtime deployments?** Backward-compatible migrations first (add column nullable, add index); deploy new code; then remove old column separately. Never deploy code + breaking migration simultaneously.
138. **What is the database per service pattern in microservices?** Each microservice owns its DB; no cross-service DB queries; communicate via events/APIs. Eliminates shared DB bottleneck at the cost of eventual consistency.
139. **How do you implement internal DNS for microservices?** Route 53 Private Hosted Zones shared across accounts via RAM; Resolver rules forwarded from workload VPCs to Shared Services VPC Resolver; services register via CloudMap.
140. **What is AWS Cloud Map?** Service registry for microservices; services register their health and endpoint; consumers discover via DNS or API. Integrates with ECS, EKS, App Mesh.

---

## I. Multi-Region & DR (141–155)
141. **Active-active vs active-passive — fundamental difference?** Active-active: traffic runs in both regions simultaneously; RPO≈0. Active-passive: secondary is standby, receives traffic only on failover; RPO = replication lag.
142. **What is Aurora Global Database's typical replication lag?** < 1 second typical; guaranteed < 1 second globally. Automatic unplanned failover: < 1 minute.
143. **How does Route 53 failover routing work?** Health check monitors the primary endpoint; on failure, Route 53 stops resolving the primary and serves the secondary's IP. TTL controls switchover speed.
144. **What is S3 Replication Time Control (RTC)?** SLA that 99.99% of new objects are replicated within 15 minutes; a CloudWatch metric shows replication time.
145. **How do you replicate Secrets Manager cross-region?** Secrets Manager multi-region replication: one primary secret → auto-replicated to replica regions. App in the replica region uses the replica endpoint.
146. **What is a dependency on DR that people miss?** KMS keys are regional — cross-region snapshot copies must re-encrypt with a target-region CMK. Also: ACM certs are regional; must provision in each DR region.
147. **How do you test DR without impacting production?** Spin up DR region in an isolated VPC; restore from replica/snapshot; run integration tests; tear down. Use IaC (Terraform) to provision consistently.
148. **What is RDS blue/green deployment for major upgrades?** AWS creates a secondary (green) with the new engine version; apply changes; validate; switchover (< 1 min downtime); old blue kept for rollback. Available for RDS and Aurora.
149. **How do DynamoDB Global Tables handle conflicts?** Last-writer-wins (based on timestamp); no application-level conflict resolution. Design access patterns to avoid concurrent cross-region writes to the same item.
150. **What is the minimum viable multi-region for a startup?** CloudFront (global CDN, automatic edge resilience) + S3 CRR for assets + Route 53 failover DNS + weekly snapshot copy to DR region. Cost-effective; full DR on demand.
151. **What is AWS Resilience Hub?** Service that analyses your application against defined RTO/RPO targets; identifies gaps; recommends and tracks remediations; runs resiliency drills.
152. **How do you handle multi-region RDS MySQL (non-Aurora)?** Cross-region read replica; promote on disaster; re-point the app; note: async replication means possible data loss (RPO = lag at time of disaster).
153. **What is Pilot Light specifics on AWS?** Core infra running (RDS replica, minimal ECS tasks stopped or scale=0); on disaster: start ECS, promote DB, update Route 53 weights; requires testing to ensure startup works.
154. **How do you coordinate database promotion and DNS failover?** Promote DB first (it takes a few minutes); update app config / Secrets Manager; then update Route 53 health check to point to DR ALB (so traffic follows). Never flip DNS before DB is ready.
155. **What is AWS Fault Injection Simulator (FIS)?** Managed chaos engineering service; inject EC2 stops, CPU stress, AZ impairments, API errors; test resilience without writing custom chaos scripts.

---

## J. Scalability (156–165)
156. **How does CloudFront handle a 100× traffic spike?** Absorbed at edge POPs (cache hits); origin only sees cache misses (~5–10% of traffic if well-tuned). No scaling needed if cache-hit ratio is high.
157. **What is RDS Proxy's role in scaling?** Multiplexes thousands of app connections to a small pool of DB connections; critical for ECS/Lambda at scale where many containers each open connection pools.
158. **When should you move from RDS to Aurora?** Write throughput ceiling on RDS, need > 5 read replicas, faster failover requirement, serverless scaling, or > 64 TB storage.
159. **How do you scale a SaaS HRMS payroll run for 1 million employees?** SQS → ECS worker pool (auto-scale on queue depth); partition payroll into batches (e.g. 1,000 emp/batch → 1,000 messages); workers idempotent; DLQ for failures. Target: < 30 min for 1M employees.
160. **What is ECS Fargate Spot and when to use it?** Spot pricing for Fargate tasks (~70% cheaper); tasks can be interrupted. Use for batch/async workers (SQS consumers), not for web-facing OLTP.
161. **How does DynamoDB auto-scaling work?** Application Auto Scaling adjusts RCU/WCU based on consumed capacity vs target utilisation (default 70%); scales out quickly, scales in conservatively.
162. **What is Connection Pooling and why mandatory at ECS scale?** Each ECS task opens a connection pool; 100 tasks × 30 connections = 3,000 → exceeds max_connections. RDS Proxy (or PgBouncer) multiplexes into ~50. Without it, the DB refuses connections under scale.
163. **How do you design for Black Friday with known traffic patterns?** Predictive scaling (2 days ahead) + scheduled scaling (EventBridge) + CloudFront pre-warm (request AWS) + ElastiCache pre-warm + read-only mode for non-essential features.
164. **What is the difference between horizontal and vertical scaling?** Horizontal: add more instances (ASG, read replicas, ECS tasks) — preferred, no single point of failure. Vertical: bigger instance — has an upper limit and requires downtime (or failover for Multi-AZ).
165. **How do you scale ElastiCache Redis writes?** Enable cluster mode (multiple shards); each shard handles a key range. Write scaling is the primary reason for cluster mode.

---

## K. Security Architecture (166–175)
166. **What is Zero Trust and how do you implement it on AWS?** Never trust, always verify: IAM roles not network location; SGs reference SGs not CIDRs; mTLS between services (App Mesh); VPC endpoints (no internet); GuardDuty continuous detection.
167. **How do you detect a compromised EC2 instance?** GuardDuty: CryptoCurrency/EC2 finding, unusual API calls, port scanning. Automated response: isolate instance (replace SG with quarantine), take EBS snapshot, notify.
168. **What is the CSPM approach on AWS?** Security Hub + AWS Config + CIS benchmark rules + Macie → scored posture findings → auto-remediate medium, page-high, block-critical via SCP.
169. **How do you ensure no S3 bucket is ever public in an Org?** SCP denying `s3:PutBucketPublicAccessBlock` removal + S3 Account Public Access Block enabled at account level via StackSet + AWS Config rule `s3-bucket-public-read-prohibited`.
170. **What is KMS key hierarchy best practice?** Separate CMK per service per environment; key policies restrict who can use/admin; key rotation automatic; cross-region CMK for DR. Avoid `aws/s3` managed key (no key policy control).
171. **How do you rotate database credentials automatically?** Secrets Manager with a rotation Lambda (built-in for RDS); app fetches secret at startup; on rotation failure, CloudWatch alarm fires.
172. **What is a VPC endpoint and why use it?** PrivateLink endpoint for AWS services (S3, KMS, SQS, etc.) — traffic stays within the VPC, never crosses the internet. Removes need for NAT GW for those services; eliminates internet exposure.
173. **How do you prevent data exfiltration from an EC2 instance?** SCP restricting allowed egress regions; VPC endpoints only (no IGW/NAT); SG egress restricted to specific services; CloudTrail + GuardDuty for detection; AWS Macie for S3 exfiltration detection.
174. **What is IAM conditions and why are they powerful?** Conditions narrow when a statement applies: `aws:RequestedRegion`, `aws:SecureTransport`, `s3:prefix`, `aws:SourceVpc`. Enables least-privilege without multiple roles.
175. **How do you handle a leaked AWS access key?** Immediately: deactivate the key in IAM. Then: check CloudTrail for what it did in the past 90 days; check for IAM changes (new users/policies), S3/EC2 activity; if EC2 instance role: terminate the instance; notify security team.

---

## L. DevOps Architecture (176–185)
176. **What is GitOps and how does it differ from traditional CI/CD?** GitOps: Git is the source of truth for infra AND app; changes applied by a pull-based operator (ArgoCD) reconciling cluster to Git state. Traditional CD: CI pushes changes. GitOps is more auditable and drift-resistant.
177. **How do you implement zero-downtime deployments for ECS?** CodeDeploy blue/green with ALB; traffic shifted to green after health check passes; blue kept for rollback window; auto-rollback on CloudWatch alarm.
178. **What is a canary deployment and how do you implement on AWS?** Shift X% traffic to new version; monitor alarms; increment to 100% if healthy. AWS: CodeDeploy with `CodeDeployDefault.ECSCanary10Percent5Minutes`; Lambda alias weighted routing.
179. **How do you bake security into the CI/CD pipeline?** SAST (Snyk/Semgrep on code), SCA (dependency vulnerability scan), IaC scan (Checkov/tfsec on Terraform), container scan (ECR image scanning/Trivy), secret scan (truffleHog) — fail-fast on HIGH findings.
180. **What is an Internal Developer Platform?** A self-service layer over cloud primitives: golden-path templates (Service Catalog/Backstage), one-click environment provisioning, integrated observability, paved-road CI/CD. Reduces cognitive load on dev teams.
181. **How does Karpenter differ from Cluster Autoscaler?** Karpenter: provisions the right node type for the pending pod in ~30s; aware of cost optimization (Spot, Graviton). Cluster Autoscaler: adds pre-configured node groups. Karpenter is faster and more efficient.
182. **What is AWS AppConfig?** Managed feature flag and dynamic configuration service; validates config before deployment; rolls out gradually; integrates with Lambda/ECS; rollback on CloudWatch alarm.
183. **How do you handle database migrations in CI/CD?** Schema migrations run as a pre-deploy step (Flyway/Liquibase via Lambda/ECS task); always backward-compatible (additive only until old code is removed); automated in the pipeline.
184. **What is the difference between CodeDeploy and CodePipeline?** CodePipeline: orchestrates the full pipeline (source→build→test→deploy). CodeDeploy: handles the actual deployment (rolling/blue-green) at one stage. CodePipeline typically invokes CodeDeploy.
185. **How do you implement full observability in a CI/CD pipeline?** Build metrics (pass/fail rate, duration) → CloudWatch; deployment events → EventBridge → annotate dashboards; smoke tests post-deploy → synthetic canary; auto-rollback on alarm.

---

## M. SaaS & Multi-Tenant (186–200)
186. **Silo vs pool: which for a regulated fintech?** Silo — dedicated account and DB per tenant for maximum isolation, separate audit trail, independent compliance controls. Cost justified by regulatory requirement.
187. **How do you implement tenant isolation with RLS in PostgreSQL?** `CREATE POLICY` on every table with `USING (tenant_id = current_setting('app.tenant')::int)`; set the setting per transaction; verify with `EXPLAIN` that policy is applied.
188. **What is the noisy-neighbour problem in pool SaaS?** One tenant's heavy query exhausts DB CPU/connections, slowing other tenants. Fix: per-tenant rate limiting (API GW usage plan), async heavy work via SQS, Performance Insights to find tenant culprit.
189. **How do you implement per-tenant rate limiting?** API Gateway usage plans (one per tenant/API key); or Redis sorted-set rate limiter keyed on `tenantId`; or WAF rate-based rule aggregated by X-Tenant-Id header.
190. **What is a tenant control plane?** The management layer: tenant registry (DynamoDB), billing/metering, user pools, onboarding automation. Separated from the data plane (the actual HRMS features).
191. **How do you achieve GDPR compliance in a pool model?** Track all tenant data in one logical scope; data export (query by tenant_id); data deletion (purge all rows with tenant_id); Macie to detect PII; encryption key per tenant (KMS key per tenant — "cryptographic erasure" on deletion).
192. **What is cryptographic erasure in SaaS?** Each tenant's data encrypted with a unique KMS CMK; to delete a tenant's data, delete the CMK → all encrypted data becomes permanently unreadable without physical deletion.
193. **How do you handle tenant onboarding at scale (1,000 new tenants/day)?** Step Functions async workflow; EventBridge for decoupling; Terraform workspace or CDK per tenant for silo; pool tenants provisioned via Lambda (schema migration) in < 5 seconds.
194. **What is the schema-per-tenant vs row-per-tenant trade-off?** Schema: easy data export/delete, migrations per-schema (N×); Row: one migration run, harder isolation (RLS), harder to delete/export one tenant.
195. **How do you monitor per-tenant performance?** Custom CloudWatch dimensions with `TenantId`; identify top-N CPU tenants via Performance Insights filtered by user/app; per-tenant CloudWatch dashboard for enterprise SLAs.
196. **How do you implement SaaS pricing metering on AWS?** Usage events → SNS → Lambda → DynamoDB (metering store); integrate with AWS Marketplace Metering Service for marketplace-listed SaaS.
197. **What is the bridge tenancy model?** Hybrid: free/standard tenants on shared pool, enterprise tenants on dedicated silo; same codebase, different Terraform modules; upgrade path from pool to silo per contractual request.
198. **How do you migrate a tenant from pool to silo?** Export data (dump by tenant_id) → provision silo infrastructure (Terraform) → import data → run integration test → update DNS/config → cut over → notify → decommission pool data.
199. **What is the tenant tiering design pattern?** Classify tenants by SLA/compute need: Free (shared, throttled) / Pro (shared, higher limits) / Enterprise (dedicated resources, custom SLA). Each tier has different infra and pricing.
200. **How do you design for 10,000 tenant SaaS on AWS at the lowest cost?** Pool model with ElastiCache (shared, tenant-namespaced) + shared ECS cluster (per-task limits) + Aurora (schema-per-tenant, 100 schemas/cluster) + Fargate Spot for workers + CloudFront for all static content = ~$0.01–$0.05/tenant/month at scale.

---

*These 200 questions cover every senior/principal-level AWS interview topic. Master them through the case studies ([Module 14](14-enterprise-case-studies.md)) and the capstone project ([project/README.md](project/README.md)).*

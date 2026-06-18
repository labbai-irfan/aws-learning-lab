# Module 10 — Scalability Design

> Every pattern for scaling AWS systems: auto-scaling, caching, async processing, database scaling, partitioning, and the load patterns that expose each bottleneck.

---

## 1. The scalability stack

```
   LOAD MANAGEMENT    CloudFront (global) → ALB (regional load balancing)
   COMPUTE SCALING    EC2 ASG / ECS Service Auto Scaling / Lambda (instant)
   CACHING            ElastiCache Redis (DB offload) · CloudFront (edge cache)
   ASYNC PROCESSING   SQS + workers (spiky workloads, decoupling)
   DATABASE READS     Read replicas · Aurora replicas · ElastiCache
   DATABASE WRITES    Vertical scale · Aurora (3–5× write throughput) · Sharding
   DATA PARTITIONING  DynamoDB partition key design · S3 prefix distribution
```

---

## 2. Auto Scaling patterns

### EC2 Auto Scaling Group
```
   Three scaling policies:
   1. Target tracking:  keep CPUUtilization at 50%  (simplest, prefer this)
   2. Step scaling:     CPU >70% → +2, CPU >90% → +5 (more control)
   3. Scheduled:        8am → min=10, 11pm → min=2  (predictable patterns)
```
- Always configure **warm-up time** to avoid premature scale-in.
- **Predictive scaling**: ML forecasts load 48h ahead → pre-warms before the morning spike.
- Multi-AZ ASG: always; use **capacity rebalancing** for Spot.

### ECS Service Auto Scaling
Same policies but targets ECS tasks:
```
   Target tracking on:  ALBRequestCountPerTarget (requests/task)
                        CPUUtilization (cluster capacity provider)
                        SQSApproximateNumberOfMessagesVisible / running-task-count
```
- **Scale-out fast, scale-in slow** — scale-in cooldown > scale-out cooldown to avoid thrash.

### Lambda (instant scale)
No configuration needed; scales to concurrency automatically. Control with:
- `ReservedConcurrency` — cap at a max; protect downstream.
- `ProvisionedConcurrency` — pre-warm to eliminate cold starts for SLA-critical functions.

---

## 3. Caching strategy (the first resort for read scaling)

### CloudFront for static + semi-static content
- Cache-hit ratio goal: > 90% for static assets.
- Use **cache behaviours** per path: long TTL for hashed assets, short for HTML.
- Result: 90%+ of static traffic never hits the origin.

### ElastiCache Redis for DB read offload
```
   Cache-aside: app reads Redis → HIT → return
                              → MISS → DB → write Redis (TTL 5min) → return
   Cache-hit ratio: target > 80% for frequently-read objects (employee profiles, config)
```
- Key: use **consistent keys** (e.g. `employee:${id}:profile`).
- Warm the cache on deploy (pre-populate high-traffic keys).
- Eviction: `allkeys-lru`; monitor `Evictions > 0`.

### Result: 10× DB read reduction is achievable with Redis alone.

---

## 4. Async processing (decoupling spiky workloads)

```
   Without SQS: payroll request → synchronous computation (30s) → timeout risk
   With SQS:    payroll request → SQS → response: "accepted" → workers process async
                                                                → SNS notify when done
```

Workers scale from SQS queue depth:
```
   ASG/ECS target tracking: SQS ApproximateNumberOfMessagesVisible / running-tasks
   → 100 messages → 10 tasks; 1000 messages → 100 tasks
```
Result: burst of 1M events → workers auto-scale → all processed; no dropped requests, no timeouts.

---

## 5. Database scaling patterns

### Read scaling (10× the common case)
```
   Writes → RDS Primary
   Reads  → RDS Read Replicas (3–5) → behind an internal NLB/Route53 policy
   Hot reads → ElastiCache (before the DB)
```

### Write scaling
Options in increasing power/complexity:
1. **Vertical scale** (db.r6g.large → db.r7g.2xlarge) — simple, limited.
2. **Aurora** — 3–5× MySQL throughput; 6-copy distributed storage; 15 read replicas.
3. **DynamoDB** — effectively unlimited throughput; but requires schemaless access pattern design.
4. **Application-level sharding** — partition by tenant/region in code; route to separate DB clusters.
5. **CQRS** — separate write DB (RDS) from read store (DynamoDB/OpenSearch/Redshift).

### DynamoDB at scale
- Design for the **access pattern**, not the entity shape.
- **Partition key** distributes writes: high-cardinality keys (`userId`, `timestamp`) avoid hot partitions.
- **Single table design**: related entities in one table, discriminated by sort key prefix.
- **DAX (DynamoDB Accelerator)**: in-memory cache for DynamoDB, microsecond reads.

---

## 6. Horizontal partitioning (sharding)

For when a single DB cannot handle write throughput:
```
   Shard 1: tenants A–M  (RDS instance 1)
   Shard 2: tenants N–Z  (RDS instance 2)
   Shard router: hash(tenantId) → shard
```
- Most SaaS apps avoid sharding by using **per-tenant databases** (silo model) — simpler isolation at the cost of more instances. See [Module 13](13-saas-multi-tenant.md).

---

## 7. Connection pooling at scale

A scaled-out ECS fleet of 100 tasks × 30 connections = 3,000 DB connections — likely exceeding `max_connections`.

```
   100 ECS tasks ──► RDS Proxy ──► (pooled ~50) ──► RDS Primary
```
- **RDS Proxy** multiplexes thousands of app connections into a small DB pool.
- Alternative: **PgBouncer** (PostgreSQL), **ProxySQL** (MySQL) self-hosted.
- Rule: `total_app_connections` must stay well below `max_connections`. Proxy solves this.

---

## 8. Load testing — validate scalability

Never declare a system "scalable" without a load test:
- **k6 / Locust / Gatling**: simulate realistic user ramp.
- Ramp to 2× and 5× expected peak; observe where it breaks first.
- Common bottlenecks found: DB connections, missing indexes, ElastiCache evictions, Lambda throttles.
- Fix → test again → CI/CD gate with performance regression check.

---

## 9. Scalability decision guide

```
   Read-bound app?      → ElastiCache + Read Replicas + CloudFront
   Write-bound?         → Aurora / DynamoDB / vertical RDS / shard
   Spiky async work?    → SQS + auto-scaling workers
   Connection storms?   → RDS Proxy
   Stateless compute?   → ASG target-tracking (CPU or request-count target)
   Global users?        → CloudFront + Multi-Region + Route 53 latency routing
   Unpredictable burst? → Lambda (infinite scale, no pre-provisioning)
```

---

## ✅ Scalability checklist
- [ ] ASG target-tracking on CPU or request-count (not step)
- [ ] ElastiCache Redis in front of RDS for reads
- [ ] SQS for async workloads (payroll, reports, email sends)
- [ ] RDS Proxy for connection management at scale
- [ ] Aurora when MySQL write throughput ceiling is hit
- [ ] DynamoDB for truly unlimited throughput (access-pattern designed)
- [ ] Load tested to 5× expected peak
- [ ] CloudFront cache-hit ratio > 90% for static assets

➡️ Next: [Module 11 — Security Architecture](11-security-architecture.md)

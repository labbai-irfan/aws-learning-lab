# Module 2 — ElastiCache & Redis: Caching at Scale

> Managed caching with ElastiCache for Redis: cluster modes, replication, cache strategies, eviction, session management, and production patterns.

---

## 1. Why caching

Without cache:
```
   Every request ──► DB ──► response   (N users × M requests = NM DB hits)
```
With cache:
```
   Request ──► Cache HIT  ──► response   (microseconds, no DB)
            └─► Cache MISS ──► DB ──► write to cache ──► response
```
Cache reduces DB load, cuts p99 latency, and lets you scale reads without scaling the DB.

---

## 2. ElastiCache — the service

**Amazon ElastiCache** is a managed in-memory data store. Two engines:
- **Redis** (recommended) — rich data types, pub/sub, sorted sets, persistence, replication, cluster mode.
- **Memcached** — simpler, multi-threaded, no persistence, no replication. Legacy use cases.

**ElastiCache Serverless** (new) — auto-scales capacity, pay per use, zero ops. Great for spiky workloads.

---

## 3. Redis concepts

### Data structures
| Type | Use |
|---|---|
| String | Session tokens, counters, feature flags, simple cache |
| Hash | User objects, config maps |
| List | Recent activity feeds, queues (LPUSH/RPOP) |
| Set | Unique visitors, tag indexes |
| Sorted Set | Leaderboards, rate limiting, expiry queues |
| Stream | Event log, message queue (≥ Redis 5.0) |

### Expiry (TTL)
Every key can have a **TTL**. Expired keys are lazily deleted on access or actively purged. Always set TTLs on cache entries — unbounded caches fill memory.

### Eviction policies (when memory is full)
| Policy | Behaviour |
|---|---|
| `allkeys-lru` | Evict least-recently-used across all keys |
| `volatile-lru` | LRU among keys with TTL only |
| `allkeys-lfu` | Evict least-frequently-used (Redis 4+) |
| `noeviction` | Return errors when full (databases/queues) |
💡 Use `allkeys-lru` for pure caches; `noeviction` for session stores where data must not be lost silently.

---

## 4. ElastiCache for Redis topology

### Single-node (dev/test)
One node, no HA, data lost on restart. Fine for dev.

### Replication group (cluster mode disabled)
```
   Primary node ──async──► Replica 1
                         ► Replica 2   (up to 5 replicas)
   Primary:  read + write
   Replicas: read-only (scale reads)
   Failover: replica promoted automatically (~60s)
```
One shard, up to 500 GB per node (r7g.2xlarge). Good for most apps.

### Cluster mode (multiple shards)
```
   Shard 1 (slots 0–5461)    Primary + up to 5 replicas
   Shard 2 (slots 5462–10922) Primary + ...
   Shard 3 (slots 10923–16383) Primary + ...
```
- Scales **both reads AND writes** across shards.
- Requires a **cluster-aware client** (Jedis cluster, ioredis cluster mode).
- Up to 500 nodes; effectively limitless throughput.
- ⚠️ Multi-key operations (`MGET`, pipelines, Lua scripts) must target the same slot (use hash tags `{user}.session`).

---

## 5. Cache strategies

### Cache-aside (lazy loading) — most common
```
   App reads from cache
     → HIT: return value
     → MISS: read from DB → write to cache (with TTL) → return value
```
Pros: only caches what's read; simple. Cons: cold start; stale data until TTL.

### Write-through
```
   App writes to DB AND cache simultaneously
```
Pros: cache always fresh. Cons: write latency doubles; wastes memory if key never read again.

### Write-behind (write-back)
Write to cache first → async flush to DB. High throughput but complex; risk of data loss.

### Read-through
Cache layer fetches from DB automatically on miss (library handles it). Simpler app code.

### TTL strategy
- Frequently read, rarely changed: long TTL (24h).
- User session: short TTL (30 min idle).
- Rate-limit counter: TTL = window size.
- Real-time leaderboard: no TTL (sorted set managed manually).

---

## 6. Production Redis patterns

### Session store
```js
// Store session with 30-min TTL
await redis.setex(`session:${sessionId}`, 1800, JSON.stringify(user));
// Read
const data = await redis.get(`session:${sessionId}`);
// Refresh on activity
await redis.expire(`session:${sessionId}`, 1800);
```

### Rate limiting (token bucket via sorted set)
```js
async function isRateLimited(userId, limit, windowMs) {
  const now = Date.now();
  const key = `rl:${userId}`;
  await redis.zremrangebyscore(key, 0, now - windowMs);
  const count = await redis.zcard(key);
  if (count >= limit) return true;
  await redis.zadd(key, now, `${now}-${Math.random()}`);
  await redis.expire(key, Math.ceil(windowMs / 1000));
  return false;
}
```

### Pub/sub (real-time notifications)
```js
// Publisher
await redis.publish('hrms:events', JSON.stringify({ type:'payroll', empId:123 }));
// Subscriber
redis.subscribe('hrms:events', (message) => { /* process */ });
```

### Distributed lock (Redlock)
```js
// Prevent concurrent payroll run
const lock = await redlock.acquire(['lock:payroll-run'], 30000); // 30s TTL
try { await runPayroll(); } finally { await lock.release(); }
```

---

## 7. Security & networking 🔒
- Deploy in **private subnets**; no public access.
- **Encryption in transit** (TLS): `--transit-encryption-enabled`.
- **Encryption at rest** (KMS): `--at-rest-encryption-enabled`.
- **AUTH token** (Redis AUTH): password for connections.
- **RBAC** (Redis 6+ / ElastiCache): per-user ACLs.
- Security group: port 6379 only from app SG.

---

## 8. Monitoring
Key metrics: `CurrConnections`, `Evictions`, `CacheHits/Misses` (cache-hit ratio = hits/(hits+misses)), `EngineCPUUtilization`, `FreeableMemory`, `ReplicationLag`.

🚨 Alarm on: **Evictions > 0** (memory full — evicting keys you want to keep), **ReplicationLag > 5s**, **FreeableMemory < 20%**.

---

## 9. Cost 💰
- Charged per node-hour by class.
- Reserved nodes save ~40%.
- ElastiCache Serverless: per GB-hour cached + per ECU processing.
- 💡 Right-size: `EngineCPUUtilization` < 50% and no evictions = probably over-provisioned.

---

## ✅ Key decisions
- Cluster mode OFF for < 100 GB and write-scale isn't needed.
- Cluster mode ON when you need > 500 GB or write scaling.
- Always set TTLs; use `allkeys-lru` for pure caches.
- Session store: Redis in private subnet + TLS + AUTH.
- Rate limiting: sorted set pattern.

➡️ Next: [Module 3 — SQS & SNS](03-sqs-sns.md)

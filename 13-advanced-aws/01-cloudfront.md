# Module 1 — Amazon CloudFront: Global CDN & Edge

> The complete guide to CloudFront: distributions, origins, caching policies, security, Lambda@Edge, and production patterns.

---

## 1. What CloudFront is

**Amazon CloudFront** is a global **Content Delivery Network (CDN)** with **450+ edge locations** (Points of Presence). It sits in front of any origin and:
- Serves cached content **close to users** (low latency, global reach).
- **Shields** the origin from traffic (DDoS, excess load).
- Provides **HTTPS, WAF, signed URLs/cookies, geo-blocking** at the edge.
- Runs code at the edge via **Lambda@Edge** and **CloudFront Functions**.

```
   User (Mumbai) ──► Edge POP (Mumbai) ──► [cache hit] ──► User
                                        └─► [cache miss] ──► Origin (us-east-1 ALB/S3)
                                                    cached for next users
```

---

## 2. Distributions & origins

A **distribution** routes requests to one or more **origins** by **path pattern**:

```yaml
Distribution:
  Origins:
    - S3 bucket          # static assets
    - ALB                # API / dynamic
    - API Gateway
    - Custom HTTP origin (any HTTPS server)
  Behaviors (matched in order):
    /static/*  → S3 origin, cache 86400s
    /api/*     → ALB origin, cache 0s (pass-through)
    /*         → S3 (default), cache 3600s
```

### Origin types
| Origin | Typical use |
|---|---|
| **S3 (website/REST)** | Static sites, assets, media |
| **S3 + OAC** | Private S3 (block public, only CF accesses) |
| **ALB / NLB** | API, backend, dynamic |
| **API Gateway** | Serverless API |
| **Custom origin** | On-prem, EC2, external CDN |

### Origin Access Control (OAC) — replace OAI
🔒 **OAC** (the modern replacement for OAI) lets CloudFront access a **private S3 bucket** without making it public:
```json
{ "Effect":"Allow","Principal":{"Service":"cloudfront.amazonaws.com"},
  "Action":"s3:GetObject","Resource":"arn:aws:s3:::hrms-assets/*",
  "Condition":{"StringEquals":{"AWS:SourceArn":"arn:aws:cloudfront::ACCT:distribution/EDFDVBD6EXAMPLE"}} }
```

---

## 3. Caching — how it works

**Cache key** = the components used to decide if a cached response can serve a request:
- Minimum: URL path (always)
- Optional additions: query strings, headers, cookies (via **Cache Policy**)

💡 **Narrower cache key = higher cache-hit ratio = lower origin load**. Only add query strings/headers to the key when different values produce different responses.

### Cache policies (managed + custom)
- **CachingOptimized** (managed) — for static assets; no query strings; high TTL.
- **CachingDisabled** (managed) — for dynamic API responses.
- **Custom** — define `DefaultTTL`, `MaxTTL`, `MinTTL` + what to forward to origin.

### Cache headers the origin controls
- `Cache-Control: max-age=86400` — override TTL per object.
- `Cache-Control: no-cache, no-store` — never cache.
- `Vary` — CloudFront honours `Vary: Accept-Encoding` by default.
- `ETag` / `Last-Modified` — conditional GET for revalidation.

### Cache invalidation
```bash
aws cloudfront create-invalidation \
  --distribution-id EDFDVBD6EXAMPLE \
  --paths "/index.html" "/static/app.*"
```
⚠️ Invalidations are slow (~seconds-minutes) and cost money beyond 1000/month. **Prefer versioned filenames** (`app.abc123.js`) so objects naturally expire without invalidation.

---

## 4. HTTPS & certificates

- CloudFront distributions require **HTTPS**; use **ACM (us-east-1)** certificates.
- **Redirect HTTP→HTTPS** in viewer protocol policy.
- Custom domain: CNAME/A-alias in Route 53 → CloudFront domain.
- **Security policy:** prefer `TLSv1.2_2021` (drops TLS 1.0/1.1).
- **HSTS** header: add via response headers policy.

🛠️
```bash
aws acm request-certificate --domain-name hrms.example.com \
  --validation-method DNS --region us-east-1   # MUST be us-east-1 for CloudFront
```

---

## 5. Security

### WAF integration
Attach a **WAF Web ACL** (must be in `us-east-1`) to the distribution — rate limiting, SQL-injection, XSS, bot control at the edge before traffic reaches the origin. See [Module 6](06-waf-shield.md).

### Signed URLs & signed cookies
Control access to **private content** (video, documents, per-user assets):
- **Signed URL** — per-object, includes expiry + IP restrictions.
- **Signed cookies** — covers multiple objects (streaming, whole site section).
- Use **trusted key groups** (modern, key-pair based) rather than the legacy trusted signers.

### Geo-restriction
Block/allow by country (CloudFront-level, coarse) or delegate to **Lambda@Edge** for custom business logic.

### Field-level encryption
Encrypt specific POST fields at the edge with public key so only downstream services with the private key can decrypt — PCI/HIPAA use cases.

---

## 6. Lambda@Edge & CloudFront Functions

| | **CloudFront Functions** | **Lambda@Edge** |
|---|---|---|
| Runtime | JS (ES 5.1-like) | Node.js, Python |
| Trigger | Viewer request/response only | Viewer + origin request/response |
| Max duration | 1 ms | 5s (viewer) / 30s (origin) |
| Memory | 2 MB | 128 MB–10 GB |
| Use | URL rewrites, header inject, A/B | Auth, body modify, dynamic origin |
| Cost | ~6× cheaper | Per-request |

Common use cases:
- **URL rewrites / clean URLs** → CloudFront Functions.
- **JWT auth at edge** → Lambda@Edge (viewer request).
- **Multi-origin routing** (by device, geo, A/B group) → Lambda@Edge (origin request).
- **Security headers** (HSTS, CSP) → CloudFront Functions (viewer response).

🛠️ Attach a CF Function for URL normalization:
```js
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith('/')) { request.uri += 'index.html'; }
  else if (!uri.includes('.')) { request.uri += '/index.html'; }
  return request;
}
```

---

## 7. Real-time logs & monitoring
- **CloudFront access logs** (S3) — full request log per distribution; analyze with Athena.
- **Real-time logs** (Kinesis Data Streams) — 1-second latency, for dashboards/SIEM.
- **CloudWatch metrics** — `Requests`, `BytesDownloaded`, `CacheHitRate`, `5xxErrorRate`, `OriginLatency`.
- **CloudWatch Alarms** on `CacheHitRate < 70%` and `5xxErrorRate > 0.5%`.

---

## 8. Production CloudFront architecture (HRMS)
```
   Route 53 ──► CloudFront Distribution
                  ├── /assets/* ──► S3 + OAC (static JS/CSS/images)
                  ├── /api/*   ──► ALB → ECS/Node API (cache-disabled)
                  └── /*       ──► S3 index.html (SPA)
               CloudFront Functions: URL rewrite (SPA routing)
               Lambda@Edge (viewer-req): JWT validation on /api/*
               WAF Web ACL: OWASP managed rules + rate limit 2000/5min
               ACM cert: hrms.example.com (us-east-1)
               Access logs → S3 → Athena for analytics
```

---

## ✅ Key decisions
- Static: S3 + OAC + long TTL + versioned filenames.
- Dynamic API: `no-cache` policy, keep origin fast.
- Security: WAF + HTTPS + OAC (never public S3) + signed URLs for private content.
- Auth: Lambda@Edge for JWT, not exposing origin tokens.

➡️ Next: [Module 2 — ElastiCache & Redis](02-elasticache-redis.md)

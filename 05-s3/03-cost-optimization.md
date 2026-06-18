# Module 3 — S3 Cost Optimization

> Understand exactly what S3 charges for, then apply the levers that cut the bill most. Includes worked estimates.

> ⚠️ Prices below are **illustrative examples** to teach the math. Confirm live prices at https://aws.amazon.com/s3/pricing/ and https://calculator.aws/.

---

## What S3 Charges For (bill components)

```
   TOTAL S3 COST =
       Storage (GB-month × class rate)
     + Requests (PUT/GET/LIST per 1,000)
     + Data transfer OUT (per GB; in is free)
     + Retrieval fees (IA / Glacier)
     + Management features (Intelligent-Tiering monitoring, S3 Inventory, replication)
     + Early-delete fees (min storage duration for IA/Glacier)
```

| Component | Billed by | Notes |
|-----------|-----------|-------|
| **Storage** | GB-month per class | Standard $$$ → Deep Archive ¢ |
| **Requests** | per 1,000 | PUT costs more than GET; LIST adds up |
| **Data transfer OUT** | per GB (tiered) | IN is free; to internet/other Region costs |
| **Retrieval** | per GB | IA + Glacier charge to read data back |
| **Early delete** | per GB | delete before min duration (IA 30d, Glacier 90/180d) |
| **Monitoring** | per object | Intelligent-Tiering monitoring fee |

💡 The **three big drivers** are usually: total **storage**, **data-transfer-out**, and **request volume**.

---

## Storage Class Cost Ladder (illustrative $/GB-month)

| Class | ~$/GB-month | Retrieval fee | Min duration |
|-------|-------------|---------------|--------------|
| Standard | $0.023 | none | none |
| Intelligent-Tiering | $0.023 → $0.0125 (auto) | none | none (small monitor fee) |
| Standard-IA | $0.0125 | yes | 30 days |
| One Zone-IA | $0.01 | yes | 30 days |
| Glacier Instant | $0.004 | yes | 90 days |
| Glacier Flexible | $0.0036 | yes | 90 days |
| Glacier Deep Archive | $0.00099 | yes (12–48h) | 180 days |

➡️ Moving 1 TB from Standard to Deep Archive: ~$23/mo → ~$1/mo (≈95% saving) — if access is rare enough to avoid retrieval fees.

---

## The 12 Cost Levers 💰

```
1.  Lifecycle rules — auto-transition cold data to IA/Glacier; expire old data
2.  Intelligent-Tiering — for unknown/changing access (no retrieval fees)
3.  Right storage class per data type (don't keep archives in Standard)
4.  Expire noncurrent versions (versioning can silently 2–3x storage)
5.  Abort incomplete multipart uploads (orphaned parts cost money)
6.  CloudFront in front — cache hits cut S3 GETs + data-transfer-out
7.  Compress before upload (gzip/webp) — less storage + transfer
8.  Avoid tiny objects in IA (128 KB min billable; small files cost more in IA)
9.  Delete what you don't need (use S3 Storage Lens / Inventory to find waste)
10. Keep traffic in-Region; avoid cross-Region transfer unless needed (DR)
11. Use S3 Bucket Keys to cut SSE-KMS request costs at scale
12. Tag + S3 Storage Lens for visibility; set AWS Budgets alerts
```

---

## Common Hidden Costs (the gotchas) ⚠️
- **Versioning bloat:** every overwrite keeps the old version. Add `NoncurrentVersionExpiration`.
- **Incomplete multipart uploads:** failed big uploads leave billable parts. Add an abort rule (e.g., 7 days).
- **IA early-delete / small-object penalties:** frequently-changing or tiny files in IA can cost *more* than Standard.
- **Retrieval fees:** restoring lots of Glacier data is not free or instant.
- **Data-transfer-out:** serving large files directly from S3 to many users — front with **CloudFront**.
- **LIST/GET request storms:** chatty apps; cache and batch.

---

## Worked Estimate A — App uploads (mixed access)
```
Storage: 500 GB Standard            500 × $0.023      = $11.50/mo
Requests: 2M PUT (@ $0.005/1k)                         = $10.00/mo
          5M GET (@ $0.0004/1k)                         =  $2.00/mo
Transfer out: 200 GB (@ $0.09)                          = $18.00/mo
------------------------------------------------------------------
Subtotal                                                ≈ $41.50/mo

Optimized: front with CloudFront (80% cache hit) + lifecycle 50% to IA:
  storage 250 Std + 250 IA = $5.75 + $3.13               =  $8.88
  transfer out mostly via CloudFront (cheaper + cached)  ≈  ~$8.00
  requests reduced by caching                             ≈  $7.00
------------------------------------------------------------------
Optimized total                                          ≈ $24/mo  (≈ 40% less)
```

## Worked Estimate B — Backups (cold)
```
2 TB backups kept 1 year, rarely read:
  All Standard:        2048 × $0.023                = ~$47/mo
  Lifecycle → Deep Archive after 30 days:
     ~1 mo Standard + 11 mo Deep Archive
     ≈ $47 (month 1) then 2048 × $0.00099 ≈ $2/mo   = ~$2/mo ongoing
  + CRR to DR Region roughly doubles storage cost (DR copy)
------------------------------------------------------------------
Saving: ~95% on storage for cold data
```

---

## Tools for Visibility
- **S3 Storage Lens** — org-wide storage analytics, finds cost/efficiency opportunities (incomplete MPU, noncurrent versions, cold data).
- **S3 Inventory** — scheduled report of objects + metadata (CSV/Parquet) for auditing/lifecycle planning.
- **Cost Explorer + Budgets** — track and alert on S3 spend ([Phase 01 Billing Guide](../01-aws-fundamentals/06-billing-guide.md)).
- **Cost allocation tags** — attribute bucket/prefix costs to teams/projects.

---

## Cost Checklist
```
[ ] Lifecycle rules on every bucket (transition + expiration)
[ ] Expire noncurrent versions
[ ] Abort incomplete multipart uploads (7d)
[ ] Intelligent-Tiering for unpredictable access
[ ] CloudFront in front of high-traffic/static content
[ ] Right class per data type (archives NOT in Standard)
[ ] Storage Lens reviewed; orphaned data deleted
[ ] S3 Bucket Keys enabled if using SSE-KMS heavily
[ ] Budgets + tags set
```

➡️ Next: [04-security-guide.md](04-security-guide.md)

# 10 — S3 Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-s3-core-concepts.md).

## Fundamentals
| Fact | Value |
|---|---|
| Storage type | **Object** (key + value + metadata), flat namespace |
| Bucket name | **Globally unique**, lives in **one Region** |
| Max object size | **5 TB** (single PUT max **5 GB** → use multipart) |
| Durability | **11 nines** (99.999999999%) |
| Consistency | **Strong** read-after-write (all ops) |
| "Folders" | Just key prefixes (no real directories) |

## Storage classes
| Class | Use | Notes |
|---|---|---|
| **Standard** | Hot, frequent | Default, multi-AZ |
| **Intelligent-Tiering** | Unknown/changing access | Auto-moves tiers, no retrieval fee |
| **Standard-IA** | Infrequent, fast retrieval | Cheaper storage, retrieval fee |
| **One Zone-IA** | Infrequent, re-creatable | Single AZ (less resilient) |
| **Glacier Instant** | Archive, ms access | |
| **Glacier Flexible** | Archive, mins–hrs | |
| **Glacier Deep Archive** | Coldest, 12h | Cheapest |
💡 Lifecycle rules transition objects between classes + expire them automatically.

## Security layers
- **Block Public Access** = ON (account + bucket) unless truly hosting public content.
- **Bucket policy** (resource-based) · **IAM policy** (identity) · **ACLs** (legacy, avoid).
- **Encryption at rest:** SSE-S3 (default), **SSE-KMS** (key control + audit), SSE-C, client-side.
- **Pre-signed URLs** = time-limited access to private objects (uploads/downloads) without making them public.
- **VPC Gateway Endpoint** = private access to S3 (no internet).
- Enforce TLS with `aws:SecureTransport` condition; enforce encryption with a deny policy.

## Data management
| Feature | Does |
|---|---|
| **Versioning** | Keeps every version (recover deletes/overwrites) |
| **MFA Delete** | Require MFA to delete versions |
| **Replication (CRR/SRR)** | Async copy cross/same-Region (needs versioning) |
| **Object Lock** | WORM — immutable for compliance/retention |
| **Lifecycle** | Transition/expire by age |
| **Multipart upload** | Parallel parts for large files (>100MB) |
| **Transfer Acceleration** | Edge-accelerated uploads over long distances |
| **S3 Select** | Query (SQL) inside an object without downloading it |

## Static hosting + CDN
- S3 static website (HTTP) → front with **CloudFront** for **HTTPS**, caching, OAC.
- **OAC/OAI** = let only CloudFront read a private bucket (don't make it public).

## Commands
```bash
aws s3 mb s3://my-bucket-unique
aws s3 cp ./file s3://my-bucket-unique/path/      # sync: aws s3 sync ./dir s3://bucket
aws s3api put-public-access-block --bucket my-bucket-unique \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3 presign s3://my-bucket-unique/file --expires-in 3600
```

## Exam triggers 💡
- "Share a private file temporarily" → **pre-signed URL**.
- "Unknown/changing access pattern, no retrieval fees" → **Intelligent-Tiering**.
- "Cheapest archive, 12h OK" → **Glacier Deep Archive**.
- "Serve a React SPA with HTTPS" → **S3 + CloudFront (OAC)**.
- "Recover deleted objects" → **Versioning** (+ MFA Delete).
- "Private S3 access from VPC, no NAT" → **Gateway Endpoint**.

## Gotchas ⚠️
- Bucket names are global — collisions fail.
- Replication needs **versioning on both** buckets; doesn't replicate existing objects (until enabled / batch).
- One Zone-IA loses data if its AZ is destroyed.
- Public bucket + private data = classic breach — keep **Block Public Access on**.

---
*Back to [S3 README](README.md).*

# Module 1 — S3 Core Concepts

> Every S3 building block explained, with definitions, analogies, key points, CLI/SDK examples, and exam/production tips.

## Table of Contents
1. [Buckets](#1-buckets)
2. [Objects](#2-objects)
3. [Storage Classes](#3-storage-classes)
4. [Versioning](#4-versioning)
5. [Lifecycle Policies](#5-lifecycle-policies)
6. [Replication](#6-replication)
7. [Static Website Hosting](#7-static-website-hosting)
8. [Pre-Signed URLs](#8-pre-signed-urls)
9. [Access Policies](#9-access-policies)
10. [Encryption](#10-encryption)
11. [CloudFront Integration](#11-cloudfront-integration)

---

## What is Amazon S3?

**Amazon S3 (Simple Storage Service)** is **object storage** for the internet: store and retrieve any amount of data (files) as **objects** inside **buckets**, accessed over HTTP(S) APIs. It's designed for **99.999999999% (11 nines) durability** and virtually unlimited scale.

**Object storage vs file/block storage:**
| | Object (S3) | File (EFS/NFS) | Block (EBS) |
|---|------------|----------------|-------------|
| Unit | Object (key + data + metadata) | Files/folders | Raw blocks |
| Access | HTTP API (GET/PUT) | Mount as filesystem | Attach as disk |
| Structure | Flat key namespace | Hierarchical | N/A |
| Scale | Virtually unlimited | Large | Volume-limited |
| Best for | Web assets, backups, data lakes, media | Shared filesystems | OS/database disks |

💡 S3 is **not a filesystem** — "folders" are an illusion created by `/` in object keys (key prefixes).

---

## 1. Buckets

**Definition:** A **bucket** is a container for objects. It has a **globally unique name** (across all AWS accounts worldwide) and lives in **one Region**.

### Key facts
- **Globally unique name** — `my-app-uploads` must be unique on the entire planet. Use DNS-style names (lowercase, no underscores), e.g., `acme-prod-uploads-ap-south-1`.
- **Region-scoped** — the bucket's data is stored in the Region you choose (pick for latency/compliance/cost).
- **Soft limit ~100 buckets/account** (raisable to 1,000) — so buckets are organizational boundaries, not per-user containers. Use **prefixes** within a bucket for separation.
- Bucket names become part of the URL: `https://my-bucket.s3.ap-south-1.amazonaws.com/key`.

### Create a bucket (CLI)
```bash
aws s3 mb s3://acme-prod-uploads-ap-south-1 --region ap-south-1
aws s3 ls                                   # list your buckets
aws s3api create-bucket --bucket acme-prod-uploads-ap-south-1 \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

💡 **Exam tip:** Bucket names are **global**; the data + most settings are **regional**. You can't rename a bucket — recreate + copy.

---

## 2. Objects

**Definition:** An **object** is a file stored in S3: the **data (value)** plus a **key (name)** plus **metadata**.

### Anatomy of an object
| Part | Meaning | Example |
|------|---------|---------|
| **Key** | The full unique name/"path" in the bucket | `users/42/avatar.png` |
| **Value** | The actual bytes (0 B up to **5 TB**) | the image data |
| **Metadata** | System (Content-Type, size, etag) + custom (`x-amz-meta-*`) | `Content-Type: image/png` |
| **Version ID** | Identifies a version (if versioning on) | `3sL4kqtJl...` |
| **Storage class** | Cost/access tier | `STANDARD` |

### Sizes & limits
- Single object: **5 TB** max.
- Single PUT upload: **5 GB** max → for larger, use **Multipart Upload** (recommended above ~100 MB).
- "Folders" = just key prefixes; `photos/2026/cat.jpg` has no real directory.

### Common operations (CLI)
```bash
aws s3 cp ./cat.jpg s3://my-bucket/photos/2026/cat.jpg   # upload
aws s3 cp s3://my-bucket/photos/2026/cat.jpg ./           # download
aws s3 ls s3://my-bucket/photos/ --recursive              # list
aws s3 rm s3://my-bucket/photos/2026/cat.jpg              # delete
aws s3 sync ./localdir s3://my-bucket/backup/             # sync a folder
```

### Multipart upload (large files)
Splits a big file into parts, uploads in parallel, reassembles. The AWS CLI/SDK does this automatically for large files. ⚠️ Failed/incomplete multipart uploads leave **orphaned parts that cost money** — add a lifecycle rule to abort them (see §5).

### S3 consistency
S3 provides **strong read-after-write consistency** for all operations (since Dec 2020) — a GET right after a PUT returns the latest data.

💡 **Exam tip:** 5 GB single-PUT limit, 5 TB object limit, multipart for big files, strong consistency.

---

## 3. Storage Classes

**Definition:** A **storage class** sets the **cost, durability, availability, and retrieval behavior** for objects. Pick based on how often/fast you need the data. Durability is **11 nines** across all classes (except One Zone is still 11 nines but in a single AZ).

| Class | Use for | Retrieval | Min storage | Cost |
|-------|---------|-----------|-------------|------|
| **S3 Standard** | Hot, frequently accessed | Instant | — | $$$$ |
| **S3 Intelligent-Tiering** | Unknown/changing access | Instant (auto-moves tiers) | — | $$$ + monitoring fee |
| **S3 Standard-IA** | Infrequent, needs instant access | Instant | 30 days | $$ + retrieval fee |
| **S3 One Zone-IA** | Infrequent + re-creatable (single AZ) | Instant | 30 days | $ (lower; less resilient) |
| **S3 Glacier Instant Retrieval** | Archive, rare access, instant needed | Instant (ms) | 90 days | $ |
| **S3 Glacier Flexible Retrieval** | Archive, minutes–hours OK | mins–12 hrs | 90 days | ¢ |
| **S3 Glacier Deep Archive** | Long-term cold (compliance) | 12–48 hrs | 180 days | cheapest ¢ |

### How to choose
```
Accessed often?          → Standard
Access pattern unknown?   → Intelligent-Tiering (let S3 decide, no retrieval fees)
Infrequent but instant?   → Standard-IA (or One Zone-IA if re-creatable)
Archive, ms access?       → Glacier Instant Retrieval
Archive, can wait mins?   → Glacier Flexible Retrieval
Cold compliance, hrs OK?  → Glacier Deep Archive
```

⚠️ **IA/Glacier gotchas:** minimum storage durations (early-delete fees), retrieval fees, and per-object minimum billable size (128 KB for IA). Small, frequently-changing objects can cost *more* in IA.

💡 **Exam tip:** Intelligent-Tiering = "set and forget" for unpredictable access (no retrieval fees, small monitoring fee). One Zone-IA = cheaper but single-AZ (use only for reproducible data).

---

## 4. Versioning

**Definition:** **Versioning** keeps **every version** of an object in a bucket. Overwrites and deletes don't destroy data — they create new versions / delete markers.

### Why use it
- Protects against **accidental overwrite or deletion**.
- Enables **rollback** to a previous version.
- Foundation for **replication** (CRR requires versioning).

### How it behaves
```
PUT cat.jpg (v1) ──► PUT cat.jpg (v2) ──► PUT cat.jpg (v3, current)
DELETE cat.jpg ──► adds a "delete marker" (v1–v3 still exist; object appears gone)
GET cat.jpg ──► returns current version; specify versionId to get an old one
```

### States
- **Unversioned** (default), **Enabled**, **Suspended** (stops new versions; existing versions kept). You can't fully turn it back to "unversioned."

### CLI
```bash
aws s3api put-bucket-versioning --bucket my-bucket \
  --versioning-configuration Status=Enabled
aws s3api list-object-versions --bucket my-bucket --prefix cat.jpg
aws s3api get-object --bucket my-bucket --key cat.jpg --version-id <id> out.jpg
```

💰 **Cost note:** Every version consumes storage. Pair versioning with a **lifecycle rule** to expire **noncurrent versions** after N days (see §5).

🔒 **MFA Delete:** optionally require MFA to permanently delete versions / disable versioning — strong protection for critical buckets.

💡 **Exam tip:** Versioning protects against deletes/overwrites; deletes add delete markers; CRR requires versioning enabled.

---

## 5. Lifecycle Policies

**Definition:** **Lifecycle rules** automatically **transition** objects to cheaper storage classes and/or **expire (delete)** them after a set time — no manual work, big savings.

### Two action types
1. **Transition** — move objects to a cheaper class after N days (e.g., Standard → Standard-IA at 30d → Glacier at 90d).
2. **Expiration** — permanently delete objects (or noncurrent versions, or incomplete multipart uploads) after N days.

### Typical policy (logs example)
```
Day 0    : S3 Standard         (hot)
Day 30   : → Standard-IA        (cooler)
Day 90   : → Glacier Flexible   (archive)
Day 365  : Expire (delete)
+ Expire noncurrent versions after 30 days
+ Abort incomplete multipart uploads after 7 days
```

### CLI (JSON config)
```bash
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket \
  --lifecycle-configuration '{
   "Rules":[{
     "ID":"logs-tiering","Status":"Enabled","Filter":{"Prefix":"logs/"},
     "Transitions":[
       {"Days":30,"StorageClass":"STANDARD_IA"},
       {"Days":90,"StorageClass":"GLACIER"}],
     "Expiration":{"Days":365},
     "NoncurrentVersionExpiration":{"NoncurrentDays":30},
     "AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}
   }]}'
```

💰 **Cost tip:** Lifecycle + Intelligent-Tiering are the two biggest S3 cost levers. Always add an **abort-incomplete-multipart** rule.

💡 **Exam tip:** Lifecycle = automated transition + expiration. Filter by **prefix** or **tags**.

---

## 6. Replication

**Definition:** **Replication** automatically copies objects from a **source bucket** to a **destination bucket**.

### Two kinds
- **CRR (Cross-Region Replication):** copy to a bucket in a **different Region** — DR, lower latency for global users, compliance.
- **SRR (Same-Region Replication):** copy to a bucket in the **same Region** — log aggregation, prod→test data, separate accounts.

### Requirements & behavior
- **Versioning must be enabled** on both source and destination.
- Replication is **asynchronous**; only **new** objects after enabling are replicated (use S3 Batch Replication for existing objects).
- Can replicate to a **different account** and change ownership.
- Can replicate to a **different storage class** (e.g., destination in Glacier for cheap DR).
- Delete markers replication is optional/configurable.

```
   SOURCE BUCKET (ap-south-1)  ──async──►  DEST BUCKET (us-east-1)
   versioning ON                            versioning ON
   IAM role grants S3 replicate permission
```

### CLI (high level)
```bash
# requires an IAM role with s3:GetObjectVersion* / s3:ReplicateObject perms
aws s3api put-bucket-replication --bucket source-bkt \
  --replication-configuration file://replication.json
```

💡 **Exam tip:** CRR = different Region (DR/compliance/latency); SRR = same Region (aggregation/test). Both need **versioning**.

---

## 7. Static Website Hosting

**Definition:** S3 can **serve a static website** (HTML/CSS/JS/images) directly from a bucket — no servers needed.

### Setup essentials
- Enable **Static website hosting**; set **index document** (`index.html`) and **error document** (`error.html`).
- The bucket gets a **website endpoint**: `http://my-bucket.s3-website-<region>.amazonaws.com`.
- For public sites, you must **allow public read** (disable Block Public Access for that bucket + a bucket policy granting `s3:GetObject`) — do this deliberately. 🔒
- ⚠️ The S3 website endpoint is **HTTP only**. For **HTTPS + custom domain**, put **CloudFront** in front (see §11) — the recommended production pattern.

### CLI
```bash
aws s3 website s3://my-bucket --index-document index.html --error-document error.html
aws s3 cp ./build/ s3://my-bucket/ --recursive
```

### Bucket policy for public read (static site)
```json
{
  "Version":"2012-10-17",
  "Statement":[{
    "Sid":"PublicRead","Effect":"Allow","Principal":"*",
    "Action":"s3:GetObject","Resource":"arn:aws:s3:::my-bucket/*"
  }]
}
```

💡 **Exam tip:** S3 static hosting = cheap, scalable static sites; use **CloudFront + ACM** for HTTPS, custom domain, and caching. For SPAs, set the error document to `index.html` (client-side routing).

---

## 8. Pre-Signed URLs

**Definition:** A **pre-signed URL** is a **temporary, secure URL** that grants time-limited permission to **upload (PUT) or download (GET)** a specific object — **without the recipient having AWS credentials**. It's signed using the credentials of whoever generates it.

### Why they're essential
- Keep buckets **private** while letting users upload/download.
- **Direct browser ↔ S3 transfer** — your server never proxies file bytes (scales, cheap, fast).
- The URL expires (e.g., 5 minutes), and is scoped to one object + operation.

### How it works (upload flow — the capstone pattern)
```
1. Browser asks your Node API: "I want to upload report.pdf"
2. Node (with IAM creds) generates a pre-signed PUT URL (expires in 300s)
3. Browser PUTs the file DIRECTLY to that URL → goes straight to S3
4. To view later: Node generates a pre-signed GET URL (or serve via CloudFront)
```

### Generate (Node.js, AWS SDK v3)
```javascript
import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({ region: "ap-south-1" });

// upload URL (valid 5 min)
const putUrl = await getSignedUrl(s3,
  new PutObjectCommand({ Bucket: "my-bucket", Key: "uploads/report.pdf", ContentType: "application/pdf" }),
  { expiresIn: 300 });

// download URL (valid 1 min)
const getUrl = await getSignedUrl(s3,
  new GetObjectCommand({ Bucket: "my-bucket", Key: "uploads/report.pdf" }),
  { expiresIn: 60 });
```

### CLI
```bash
aws s3 presign s3://my-bucket/uploads/report.pdf --expires-in 300
```

🔒 **Security tips:** keep expiry short; validate file type/size on the server before signing; the signer's IAM permissions bound what the URL can do. For **browser POST uploads with conditions** (size/type limits), use **pre-signed POST policies**.

💡 **Exam tip:** Pre-signed URL = temporary credential-free access to a specific object; permissions come from the **signer**.

---

## 9. Access Policies

**Definition:** S3 access is controlled by **several layered mechanisms**. By default **everything is private** — only the owner has access.

### The layers (how access is decided)
| Mechanism | Scope | Use |
|-----------|-------|-----|
| **Block Public Access (BPA)** | Account + bucket | Master switch to prevent public access (ON by default) — keep it on unless hosting a public site 🔒 |
| **IAM policies** | Identity (user/role) | "What can this user/role do across AWS?" |
| **Bucket policies** | Resource (the bucket) | "Who can do what on this bucket?" (JSON, supports cross-account, conditions) |
| **ACLs (legacy)** | Object/bucket | Old per-object grants — **avoid**; AWS recommends disabling ACLs (Object Ownership = Bucket owner enforced) |
| **Access Points** | Named endpoints | Simplify access for shared datasets at scale |

### Evaluation logic (simplified)
```
Explicit DENY anywhere?  → DENIED
Block Public Access blocks it? → DENIED (for public)
Any ALLOW (IAM or bucket policy)? → ALLOWED
Otherwise → DENIED (default)
```

### Example bucket policy — allow a specific role, enforce TLS
```json
{
  "Version":"2012-10-17",
  "Statement":[
    {"Sid":"AppRoleRW","Effect":"Allow",
     "Principal":{"AWS":"arn:aws:iam::123456789012:role/app-role"},
     "Action":["s3:GetObject","s3:PutObject"],
     "Resource":"arn:aws:s3:::my-bucket/uploads/*"},
    {"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*",
     "Action":"s3:*","Resource":["arn:aws:s3:::my-bucket","arn:aws:s3:::my-bucket/*"],
     "Condition":{"Bool":{"aws:SecureTransport":"false"}}}
  ]
}
```

🔒 **Best practice:** Keep **Block Public Access ON**, disable ACLs (bucket-owner-enforced), grant least-privilege via IAM/bucket policies, and require TLS. Use **pre-signed URLs** (not public buckets) to share private files.

💡 **Exam tip:** Default = private. Explicit Deny always wins. BPA overrides policies for public access. Use bucket policies for cross-account.

---

## 10. Encryption

**Definition:** S3 protects data **at rest** (stored) and **in transit** (TLS). **Encryption at rest is on by default** (SSE-S3) for all new objects.

### At-rest options (server-side encryption, SSE)
| Type | Keys managed by | Use |
|------|-----------------|-----|
| **SSE-S3** (AES-256) | AWS (default) | Simple, automatic, no key management |
| **SSE-KMS** | AWS KMS (you control the CMK) | Audit (CloudTrail), key policies, rotation, fine-grained control |
| **SSE-C** | You provide the key per request | You manage keys entirely; AWS doesn't store them |
| **Client-side** | You encrypt before upload | Max control; AWS never sees plaintext |

### In transit
- Use **HTTPS/TLS** for all access. Enforce with a bucket policy denying `aws:SecureTransport=false` (see §9).

### CLI
```bash
# upload with SSE-KMS
aws s3 cp file.pdf s3://my-bucket/secure/file.pdf \
  --sse aws:kms --sse-kms-key-id alias/my-key
# set default bucket encryption to KMS
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration '{
  "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"alias/my-key"}}]}'
```

🔒 **Tip:** Use **SSE-KMS** for sensitive data (HR, financial, PII) — you get key access control + CloudTrail audit of every decrypt. ⚠️ KMS adds a small per-request cost and KMS API limits at very high throughput (use S3 Bucket Keys to reduce KMS calls).

💡 **Exam tip:** SSE-S3 = default/simple; SSE-KMS = audit + control; SSE-C = customer-supplied keys; client-side = encrypt before upload.

---

## 11. CloudFront Integration

**Definition:** **Amazon CloudFront** is AWS's CDN. Put it **in front of S3** to cache content at **edge locations** worldwide for low latency, lower cost, HTTPS, and security.

### Why integrate CloudFront with S3
- **Performance:** serve cached objects from the nearest edge (fast globally).
- **Cost:** cache hits reduce S3 GET requests and data-transfer-out from the origin. 💰
- **HTTPS + custom domain:** free ACM certs on CloudFront (S3 website endpoint is HTTP-only).
- **Security:** keep the bucket **private** and let only CloudFront read it via **Origin Access Control (OAC)** — users can't hit S3 directly.

### Architecture
```
   Users ──► CloudFront (edge cache, HTTPS, custom domain)
                  │  Origin Access Control (OAC)
                  ▼
            PRIVATE S3 bucket (no public access)
```

### OAC (modern) vs OAI (legacy)
- **OAC (Origin Access Control)** — current best practice; lets CloudFront sign requests to a private S3 origin (supports SSE-KMS).
- **OAI (Origin Access Identity)** — older mechanism; prefer OAC for new setups.

### Key points
- The S3 bucket policy grants read access **only to the CloudFront distribution** (via OAC).
- Set **cache behaviors/TTLs**; **invalidate** the cache when you deploy new files (`/index.html`).
- Combine with **lifecycle/storage classes** on the origin for full cost control.

💡 **Exam tip:** CloudFront + S3 (private) + **OAC** = the standard secure, fast static-content delivery pattern. S3 website endpoint = HTTP only → use CloudFront for HTTPS.

---

## ✅ Module 1 Recap
You can now explain: buckets (global names, regional data) · objects (key/value/metadata, 5 TB, multipart, strong consistency) · 7 storage classes & how to choose · versioning (delete markers, rollback) · lifecycle (transition + expiration) · replication (CRR/SRR, needs versioning) · static website hosting · pre-signed URLs (temporary credential-free access) · access policies (BPA + IAM + bucket policy, default-private) · encryption (SSE-S3/KMS/C, TLS) · CloudFront + OAC integration.

➡️ Next: [02-architectures.md](02-architectures.md)

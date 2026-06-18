# Module 2 — S3 Architectures

> Four production-grade reference architectures built on S3, each with a diagram, flow, services used, and design notes. These are the patterns interviewers and real projects ask for.

## Index
1. [File Upload Architecture](#1-file-upload-architecture)
2. [Media Storage Architecture](#2-media-storage-architecture)
3. [Backup Architecture](#3-backup-architecture)
4. [HRMS File Storage Architecture](#4-hrms-file-storage-architecture)

---

## 1. File Upload Architecture

**Goal:** Let users upload files securely and at scale **without routing file bytes through your server** (uses pre-signed URLs — the capstone pattern).

```
   ┌─────────┐   1. request upload URL (auth'd)   ┌──────────────┐
   │ React   │ ────────────────────────────────► │  Node API    │
   │ Browser │ ◄──── 2. pre-signed PUT URL ────── │ (IAM creds)  │
   └────┬────┘                                     └──────┬───────┘
        │ 3. PUT file DIRECTLY to S3                      │ (records metadata)
        ▼                                                 ▼
   ┌──────────────────────────┐                    ┌──────────────┐
   │  PRIVATE S3 BUCKET        │                    │  Database     │
   │  uploads/{userId}/{uuid}  │                    │ (file rows)   │
   └───────────┬──────────────┘                    └──────────────┘
        4. (optional) S3 Event → Lambda (virus scan, resize, thumbnail)
        5. read back via pre-signed GET URL or CloudFront
```

**Flow:**
1. Browser asks the API for an upload URL (after authentication/validation).
2. API validates file type/size, generates a **pre-signed PUT URL** (short expiry), stores a DB record.
3. Browser uploads **directly to S3** (server never sees the bytes → scales cheaply).
4. (Optional) **S3 Event Notification → Lambda** post-processes (scan, thumbnail, transcode).
5. Downloads via **pre-signed GET URL** or **CloudFront**.

**Services:** S3 (private bucket, BPA on), IAM role, Node/Express, optional Lambda + SQS/SNS, optional CloudFront.

**Design notes:**
- 🔒 Keep the bucket private; never make it public. Validate on the server before signing.
- Use a key scheme like `uploads/{userId}/{uuid}-{filename}` to avoid collisions and enable per-user access.
- 💰 Direct-to-S3 upload removes server bandwidth/CPU cost.
- For browser uploads with enforced size/type, use **pre-signed POST** policies.
- Add a **lifecycle rule** to abort incomplete multipart uploads.

---

## 2. Media Storage Architecture

**Goal:** Store and globally deliver images/video (e.g., a social/streaming app) with transcoding, thumbnails, and a CDN.

```
   Upload (pre-signed) ──► S3 "raw" bucket (originals, Standard)
                                  │  S3 Event
                                  ▼
                        ┌──────────────────────┐
                        │ Lambda / MediaConvert │  (transcode, resize, thumbnails)
                        └───────────┬──────────┘
                                    ▼
                        S3 "processed" bucket (renditions: 240p/720p/1080p, thumbs)
                                    │  Origin Access Control
                                    ▼
                        CloudFront (edge cache, HTTPS, signed URLs/cookies)
                                    │
                                  Users (global, low latency)
```

**Flow:** originals land in a raw bucket → S3 event triggers **Lambda (images)** or **AWS Elemental MediaConvert (video)** → outputs go to a processed bucket → **CloudFront** serves renditions worldwide.

**Services:** S3 (raw + processed buckets), Lambda / MediaConvert, CloudFront (+ OAC, optional signed URLs for paid content), Intelligent-Tiering/lifecycle.

**Design notes:**
- Separate **raw** vs **processed** buckets (different lifecycle/cost).
- 💰 Use **Intelligent-Tiering** for media with unpredictable popularity; move cold originals to Glacier.
- Use **CloudFront signed URLs/cookies** to protect premium content.
- Cache aggressively at the edge; invalidate on updates.
- Store metadata (duration, dimensions) in DynamoDB/RDS.

---

## 3. Backup Architecture

**Goal:** Durable, cheap, compliant backups with cross-Region disaster recovery and immutability.

```
   On-prem / EC2 / RDS / app data
            │  (AWS Backup / aws s3 sync / DataSync / Snowball for huge sets)
            ▼
   S3 "backup" bucket (Region A)  ── Versioning ON, Object Lock (WORM)
            │  Lifecycle: Standard → Standard-IA(30d) → Glacier(90d) → Deep Archive(180d)
            │
            │  Cross-Region Replication (CRR)
            ▼
   S3 "backup-dr" bucket (Region B)  ── Versioning ON (disaster recovery copy)
```

**Flow:** data is copied to a versioned backup bucket (via **AWS Backup**, `aws s3 sync`, **DataSync**, or **Snowball** for very large/offline transfers) → **lifecycle** tiers it to ever-cheaper classes → **CRR** replicates to a second Region for DR. **S3 Object Lock** makes backups immutable (ransomware/compliance).

**Services:** S3 (versioning, Object Lock, lifecycle), AWS Backup, DataSync/Snowball, CRR, KMS encryption.

**Design notes:**
- 🔒 **Object Lock (WORM)** + versioning + MFA Delete = protection against deletion/ransomware.
- 💰 Aggressive lifecycle to Glacier Deep Archive for long-term/compliance retention (cheapest).
- Test **restores** regularly — a backup you can't restore is worthless.
- Encrypt with **SSE-KMS**; replicate keys/permissions to the DR Region.
- Tag backups for retention policy and cost allocation.

---

## 4. HRMS File Storage Architecture

**Goal:** Store sensitive HR documents (contracts, payslips, IDs, performance reviews) with strict access control, encryption, audit, and retention — a real enterprise compliance use case.

```
   HR portal (React) ──auth (Cognito/IAM)──► Node API (role-based authorization)
        │  pre-signed URLs scoped per-employee                       │ audit log
        ▼                                                            ▼
   ┌──────────────────────────────────────────┐              CloudTrail + S3 access logs
   │  PRIVATE S3 bucket  (BPA ON)              │
   │  employees/{empId}/contracts/...          │  SSE-KMS (HR CMK, key policy)
   │  employees/{empId}/payslips/...           │  Versioning ON
   │  employees/{empId}/id-docs/...            │  Object Lock (retention, e.g. 7 yrs)
   └───────────────────┬──────────────────────┘
       Lifecycle: payslips → Glacier after 1 yr; purge per retention policy
       Replication (CRR) to DR Region (compliance/continuity)
```

**Flow:** authenticated HR/employee requests a document → API checks **role-based authorization** (employee sees only their own files; HR admins see their org) → returns a short-lived **pre-signed URL** scoped to that object → all access is **audited**.

**Services:** S3 (private, SSE-KMS, versioning, Object Lock, lifecycle, CRR), IAM/Cognito, KMS (dedicated HR key), CloudTrail + S3 server access logging, Node API.

**Design notes (compliance-grade):**
- 🔒 **SSE-KMS with a dedicated HR key** — key policy restricts decrypt to HR roles; every decrypt is logged in CloudTrail.
- 🔒 Strict **prefix-based access**: `employees/{empId}/...`; IAM/policy conditions limit a user to their own prefix.
- 🔒 **Block Public Access ON**, ACLs disabled, **TLS enforced**.
- 📋 **Object Lock + lifecycle** enforce legal **retention** (e.g., keep payslips 7 years, then purge).
- 📋 **Audit everything** (CloudTrail data events + S3 access logs) for compliance reviews.
- Pre-signed URLs with **very short expiry**; never expose the bucket directly.
- CRR to a DR Region in the same legal jurisdiction (data residency).

---

## Cross-Architecture Patterns (the reusable building blocks)
```
Direct upload         → pre-signed URL (browser ↔ S3)
Post-processing       → S3 Event → Lambda / MediaConvert
Global delivery       → CloudFront + OAC (private origin)
Cost control          → storage classes + lifecycle + Intelligent-Tiering
Durability/DR         → versioning + CRR (+ Object Lock for immutability)
Security/compliance   → BPA on + SSE-KMS + least-privilege policies + CloudTrail
Access scoping        → key prefixes per tenant/user + policy conditions
```

➡️ Next: [03-cost-optimization.md](03-cost-optimization.md)

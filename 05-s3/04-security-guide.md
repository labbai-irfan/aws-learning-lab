# Module 4 — S3 Security Guide

> S3 is secure by default — most breaches come from **misconfiguration**. This guide gives you the layered model, hardening checklist, and copy-paste policies.

---

## The Security Layers (defense in depth)

```
   ┌─────────────────────────────────────────────────────────┐
   │ 1. Block Public Access (account + bucket)  ← master gate  │
   │ 2. IAM policies (who/what identities can do)              │
   │ 3. Bucket policies (resource rules, cross-account, TLS)   │
   │ 4. Object Ownership / ACLs disabled (bucket-owner-enforced)│
   │ 5. Encryption at rest (SSE-S3/KMS) + in transit (TLS)     │
   │ 6. Versioning + Object Lock (tamper/ransomware protection) │
   │ 7. Logging & monitoring (CloudTrail, access logs, Config) │
   │ 8. Pre-signed URLs / Access Points for controlled sharing  │
   └─────────────────────────────────────────────────────────┘
```

---

## 1. Block Public Access (BPA) — the master switch
- **ON by default** at the account and bucket level. Keep it ON unless you intentionally host a public static site.
- BPA **overrides** bucket policies/ACLs that would grant public access.
```bash
aws s3api put-public-access-block --bucket my-bucket --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```
🔒 For private apps (uploads, HR, backups) → **never** make the bucket public; share via **pre-signed URLs** or **CloudFront + OAC**.

## 2. IAM Policies (identity-based) — least privilege
Grant only the actions/resources needed. Example: an app role that can only read/write its own prefix:
```json
{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Action":["s3:GetObject","s3:PutObject"],
    "Resource":"arn:aws:s3:::my-bucket/uploads/${aws:userid}/*"
  }]
}
```

## 3. Bucket Policies (resource-based) — TLS + scoping + cross-account
Deny non-HTTPS and grant a specific role:
```json
{
  "Version":"2012-10-17",
  "Statement":[
    {"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*",
     "Action":"s3:*","Resource":["arn:aws:s3:::my-bucket","arn:aws:s3:::my-bucket/*"],
     "Condition":{"Bool":{"aws:SecureTransport":"false"}}},
    {"Sid":"DenyUnEncryptedUploads","Effect":"Deny","Principal":"*",
     "Action":"s3:PutObject","Resource":"arn:aws:s3:::my-bucket/*",
     "Condition":{"StringNotEquals":{"s3:x-amz-server-side-encryption":"aws:kms"}}}
  ]
}
```

## 4. Disable ACLs (Object Ownership)
- Set **Object Ownership = Bucket owner enforced** to disable ACLs entirely — simpler, safer; the owner controls everything via policies.
```bash
aws s3api put-bucket-ownership-controls --bucket my-bucket \
  --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'
```

## 5. Encryption
- **At rest:** on by default (SSE-S3). For sensitive data use **SSE-KMS** (key policy + CloudTrail audit). Enforce via the bucket policy above.
- **In transit:** require TLS (deny `aws:SecureTransport=false`).
```bash
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration \
 '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"alias/my-key"},"BucketKeyEnabled":true}]}'
```

## 6. Versioning + Object Lock (integrity)
- **Versioning** protects against overwrite/delete.
- **Object Lock (WORM)** makes objects immutable for a retention period — ransomware & compliance protection. Must be enabled at bucket creation.
- **MFA Delete** requires MFA to permanently delete versions.

## 7. Logging & Monitoring
- **CloudTrail** (management + data events) — who did what.
- **S3 server access logging** — detailed request logs to another bucket.
- **AWS Config rules** — detect public buckets, unencrypted buckets, etc.
- **Amazon Macie** — ML-based discovery of PII/sensitive data in S3.
- **IAM Access Analyzer for S3** — flags buckets shared externally.

## 8. Controlled Sharing
- **Pre-signed URLs** — temporary, scoped, credential-free (keep expiry short).
- **CloudFront + OAC** — serve a private bucket globally over HTTPS without exposing S3.
- **S3 Access Points** — named endpoints with their own policies for shared datasets.

---

## 🔒 S3 Security Hardening Checklist
```
[ ] Block Public Access ON (account + every bucket) unless truly public
[ ] ACLs disabled (Object Ownership = BucketOwnerEnforced)
[ ] Least-privilege IAM (no s3:* / Resource:* for apps)
[ ] Bucket policy denies non-TLS (aws:SecureTransport=false)
[ ] Default encryption set (SSE-KMS for sensitive data) + Bucket Keys
[ ] Versioning ON for important data; Object Lock for immutability
[ ] MFA Delete on critical buckets
[ ] CloudTrail data events + server access logging enabled
[ ] AWS Config / Access Analyzer / Macie monitoring
[ ] Pre-signed URLs (short expiry) instead of public objects
[ ] CloudFront + OAC for public delivery (origin stays private)
[ ] Separate buckets/prefixes per environment & tenant; scoped policies
[ ] No credentials in client code; server signs requests
```

---

## Top S3 Security Mistakes (and fixes)
| Mistake | Risk | Fix |
|---------|------|-----|
| Public bucket by accident | Data leak (the classic breach) | BPA ON; use pre-signed/CloudFront |
| Credentials in frontend/Git | Stolen keys, huge bills | Server signs; IAM roles; rotate/Secrets Manager |
| `s3:*` + `Resource:*` policy | Over-broad access | Least privilege, scope to prefix |
| No TLS enforcement | Eavesdropping | Deny `SecureTransport=false` |
| No versioning | Irrecoverable deletes | Enable versioning (+ Object Lock) |
| Long-lived pre-signed URLs | Link sharing/leakage | Short expiry; per-object scope |
| ACLs left enabled | Confusing/loose grants | BucketOwnerEnforced |
| No logging | Can't audit/investigate | CloudTrail + access logs |

---

## Quick Reference — Secure Bucket Bootstrap
```bash
B=my-secure-bucket
aws s3api create-bucket --bucket $B --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-public-access-block --bucket $B --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-ownership-controls --bucket $B \
  --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'
aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $B --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# then attach a least-privilege bucket policy + deny-non-TLS statement
```

➡️ Next: [05-troubleshooting.md](05-troubleshooting.md)

# Module 5 — S3 Troubleshooting Guide

> Symptom → likely cause → fix. Grouped by Access/403, Upload, Pre-signed URLs, CORS, Website hosting, Encryption/KMS, Performance, and Cost.

---

## A. Access Denied (403) — the #1 S3 issue

```
Check order:
1. Does the IAM identity have an Allow for this action + resource?
2. Any explicit DENY (IAM, bucket policy, SCP)? Deny always wins.
3. Block Public Access blocking it (for public access)?
4. Object Ownership/ACL issues? (cross-account uploads)
5. KMS key policy denies decrypt? (SSE-KMS objects)
6. Resource ARN correct? bucket vs bucket/* (object-level needs /*)
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 on GetObject | IAM/bucket policy lacks `s3:GetObject` on `arn:.../*` | Add object-level permission (note the `/*`) |
| 403 despite Allow | Explicit Deny somewhere (SCP, bucket policy, TLS condition) | Find and remove/satisfy the Deny |
| 403 only for public | Block Public Access ON | Use pre-signed/CloudFront, or (deliberately) relax BPA |
| 403 reading SSE-KMS object | No `kms:Decrypt` on the key | Grant key usage in the KMS key policy/IAM |
| 403 cross-account upload | Object owned by uploader's account | Use BucketOwnerEnforced or `bucket-owner-full-control` ACL |
| 403 listing bucket | Missing `s3:ListBucket` on the **bucket** ARN (no `/*`) | Add ListBucket on `arn:aws:s3:::bucket` |

💡 `s3:ListBucket` is on the **bucket** ARN; `s3:GetObject/PutObject` are on the **object** ARN (`/*`). Mixing these up causes most 403s.

---

## B. Upload Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `EntityTooLarge` | Single PUT > 5 GB | Use multipart upload (SDK/CLI auto) |
| Upload hangs/slow for big files | No multipart/parallelism | Use multipart; increase concurrency |
| `AccessDenied` on PutObject | No write permission or encryption condition unmet | Grant PutObject; send required SSE header |
| `SignatureDoesNotMatch` | Clock skew, wrong region/endpoint, altered request | Sync clock; correct region; don't modify signed request |
| Orphaned cost after failed uploads | Incomplete multipart parts | Lifecycle: AbortIncompleteMultipartUpload (7d) |
| Wrong Content-Type (file downloads instead of displays) | Content-Type not set | Set `Content-Type` on upload/pre-sign |

---

## C. Pre-Signed URL Problems (common in the capstone)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `403` / `Request has expired` | URL past `expiresIn` | Generate a fresh URL; increase expiry sensibly |
| `SignatureDoesNotMatch` on PUT | Client sent different `Content-Type`/headers than signed | Sign with the exact `ContentType`; send the same header from the browser |
| Works in Postman, fails in browser | CORS not configured | Add bucket CORS (see §D) |
| 403 even with valid URL | Signer's IAM role lacks the action | Grant the role `s3:PutObject`/`GetObject` on the key |
| Can upload but not view | GET URL not generated / object private | Generate pre-signed GET, or serve via CloudFront |
| KMS object: upload 403 | Missing `kms:GenerateDataKey` for signer | Grant KMS permission to the signer role |

💡 **Golden rule:** the headers (especially `Content-Type`) the browser sends on PUT must match what was used to sign the URL.

---

## D. CORS Errors (browser uploads/downloads)

Symptom: browser console shows `No 'Access-Control-Allow-Origin' header` / blocked by CORS.
Fix: add a **CORS configuration** to the bucket allowing your web origin and methods:
```json
[
  {
    "AllowedOrigins": ["https://app.example.com", "http://localhost:5173"],
    "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```
```bash
aws s3api put-bucket-cors --bucket my-bucket --cors-configuration file://cors.json
```
⚠️ Use your exact front-end origin(s); avoid `"*"` in production. Include the methods you actually use (PUT for pre-signed uploads).

---

## E. Static Website Hosting Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403/404 on website endpoint | Block Public Access on / no bucket policy | Allow public read (deliberately) or use CloudFront |
| No HTTPS on S3 website URL | S3 website endpoint is HTTP-only | Put CloudFront + ACM in front |
| SPA routes 404 on refresh | No SPA fallback | Set error document to `index.html` |
| Old content after deploy (CloudFront) | Edge cache | Invalidate (`/*` or changed paths) |
| `index.html` downloads instead of renders | Wrong Content-Type | Set `text/html` on upload |

---

## F. Encryption / KMS Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 reading object | No `kms:Decrypt` on key | Add to IAM/key policy |
| Upload denied by policy | Bucket policy requires SSE-KMS but header missing | Send `x-amz-server-side-encryption: aws:kms` |
| KMS throttling at scale | Too many KMS calls | Enable **S3 Bucket Keys** |
| Can't share with another account | Key policy doesn't allow them | Update KMS key policy/grants |

---

## G. Performance

| Symptom | Cause | Fix |
|---------|-------|-----|
| Slow global downloads | Single-Region origin | Front with CloudFront (edge cache) |
| Slow large uploads | No multipart/parallel | Multipart + parallel parts; S3 Transfer Acceleration |
| High latency from far clients | Distance to Region | Transfer Acceleration / CloudFront / CRR |
| Throughput limits worry | Hot prefix myths | S3 scales to high req/s per prefix automatically; spread keys if extreme |

💡 S3 now scales automatically (no need to randomize key prefixes for typical workloads). Use **Transfer Acceleration** for fast long-distance uploads.

---

## H. Unexpected Cost 💰
| Symptom | Cause | Fix |
|---------|-------|-----|
| Storage higher than data size | Versioning keeping old versions | Expire noncurrent versions |
| Mystery storage charges | Incomplete multipart parts | Abort-incomplete lifecycle rule |
| High request bill | Chatty LIST/GET | Cache (CloudFront), batch, reduce LIST |
| High transfer-out | Serving large files directly from S3 | CloudFront caching |
| IA costs more than expected | Tiny objects / early deletes | Keep small/changing data in Standard |

Use **S3 Storage Lens** to find waste; **Cost Explorer + Budgets** to track.

---

## General Diagnostic Order
```
1. Reproduce; capture the exact error code (403/404/400/EntityTooLarge...)
2. For 403: check IAM → bucket policy → BPA → ownership/ACL → KMS, in that order
3. For browser issues: check CORS + the signed headers (Content-Type)
4. Verify with CLI as a known-good identity (isolate client vs permission issue)
5. Check CloudTrail for the denied call (it shows which policy denied)
6. Change one thing, retest
```

## Handy Diagnostic Commands
```bash
aws s3 ls s3://my-bucket --recursive            # can you list?
aws s3api get-bucket-policy --bucket my-bucket   # current policy
aws s3api get-public-access-block --bucket my-bucket
aws s3api get-bucket-encryption --bucket my-bucket
aws s3api get-bucket-cors --bucket my-bucket
aws s3api head-object --bucket my-bucket --key path/file --debug   # detailed
aws sts get-caller-identity                       # who am I?
```

➡️ Next: [06-labs.md](06-labs.md)

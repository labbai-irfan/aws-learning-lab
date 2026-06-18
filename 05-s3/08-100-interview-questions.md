# Module 8 — 100 S3 Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, technically correct.

---

## Fundamentals & Buckets/Objects (1–18)
**1. What is Amazon S3?** Object storage for the internet — store/retrieve any amount of data as objects in buckets over HTTP APIs, with 11 nines of durability and virtually unlimited scale.

**2. Object vs block vs file storage?** Object (S3) = key+data+metadata via API, flat namespace, web-scale; block (EBS) = raw disk for OS/DBs; file (EFS) = mountable shared filesystem.

**3. What is a bucket?** A container for objects with a globally unique name, located in one Region.

**4. What is an object?** A file stored in S3: a key (name), value (bytes), and metadata; optionally a version ID and storage class.

**5. Why must bucket names be globally unique?** Because they can be used in DNS-style URLs that must be unique across all of AWS.

**6. Max object size? Max single PUT?** 5 TB per object; 5 GB per single PUT — use multipart upload beyond that.

**7. What is multipart upload?** Splitting a large file into parts uploaded in parallel and reassembled — faster and resilient; recommended above ~100 MB.

**8. Are there real folders in S3?** No — it's a flat key namespace; `/` in keys just creates the appearance of folders (prefixes).

**9. What consistency does S3 offer?** Strong read-after-write consistency for all operations.

**10. How durable is S3?** Designed for 99.999999999% (11 nines) durability by storing redundantly across multiple devices/AZs.

**11. Difference between durability and availability?** Durability = not losing data; availability = being able to access it. Classes vary in availability, not durability (except One Zone's AZ risk).

**12. How do you upload/download via CLI?** `aws s3 cp`, `aws s3 sync` for folders, `aws s3 ls`, `aws s3 rm`.

**13. What metadata can objects have?** System metadata (Content-Type, size, ETag) and custom `x-amz-meta-*` key-values.

**14. Default access on a new bucket?** Private — only the owner has access.

**15. When would you choose S3 over EBS/EFS?** For web assets, backups, data lakes, media, logs, and static sites — anything accessed via API at scale rather than mounted as a disk.

**16. How do you handle very large numbers of objects?** S3 scales automatically; use prefixes for organization and S3 Inventory/Storage Lens for management.

**17. What's an ETag?** A hash/identifier of the object content used for integrity checks and conditional requests.

**18. Can you rename a bucket?** No — create a new bucket and copy objects over.

---

## Storage Classes & Lifecycle (19–34)
**19. Name the S3 storage classes.** Standard, Intelligent-Tiering, Standard-IA, One Zone-IA, Glacier Instant Retrieval, Glacier Flexible Retrieval, Glacier Deep Archive.

**20. When use Standard?** Frequently accessed, latency-sensitive hot data.

**21. When use Intelligent-Tiering?** When access patterns are unknown/changing — it auto-moves objects between tiers with no retrieval fees (small monitoring fee).

**22. Standard-IA vs One Zone-IA?** Both for infrequent access with instant retrieval; One Zone-IA stores in a single AZ (cheaper, less resilient) — use only for re-creatable data.

**23. Glacier tiers difference?** Instant Retrieval = ms access; Flexible = minutes–hours; Deep Archive = 12–48h, cheapest, for long-term compliance.

**24. What are IA/Glacier gotchas?** Minimum storage durations (early-delete fees), retrieval fees, and per-object min billable size — small/changing data can cost more.

**25. What is a lifecycle policy?** Rules that automatically transition objects to cheaper classes and/or expire (delete) them after set times.

**26. Lifecycle transition vs expiration?** Transition moves to a cheaper class; expiration permanently deletes.

**27. How do you filter lifecycle rules?** By key prefix and/or object tags.

**28. Most important lifecycle rule for cost?** Abort incomplete multipart uploads (e.g., after 7 days) and expire noncurrent versions.

**29. How do you archive logs cost-effectively?** Lifecycle: Standard → Standard-IA (30d) → Glacier (90d) → expire/Deep Archive per retention.

**30. How do you reduce versioning storage cost?** Add a NoncurrentVersionExpiration rule.

**31. How would you save ~95% on cold backups?** Lifecycle them to Glacier Deep Archive (if access is rare enough to avoid retrieval fees).

**32. Can lifecycle move data back to a hotter class?** No — transitions go to cooler/cheaper classes only; restore Glacier objects explicitly when needed.

**33. What tool shows storage waste?** S3 Storage Lens (and S3 Inventory for object-level reports).

**34. How to pick a class quickly?** Hot→Standard; unknown→Intelligent-Tiering; infrequent+instant→Standard-IA; re-creatable→One Zone-IA; archive→Glacier tiers.

---

## Versioning & Replication (35–48)
**35. What is versioning?** Keeping every version of an object so overwrites/deletes don't lose data.

**36. What happens on delete with versioning?** A delete marker is added; previous versions remain and can be restored.

**37. Can you fully disable versioning?** No — only suspend it; existing versions remain.

**38. What is MFA Delete?** Requires MFA to permanently delete versions or change versioning state — strong protection.

**39. What is replication?** Automatic copying of objects from a source bucket to a destination bucket.

**40. CRR vs SRR?** Cross-Region Replication (different Region — DR/compliance/latency) vs Same-Region Replication (same Region — aggregation/test/separate accounts).

**41. What does replication require?** Versioning enabled on both buckets and an IAM role granting S3 replication permissions.

**42. Is replication synchronous?** No — it's asynchronous; only new objects after enabling are replicated by default.

**43. How do you replicate existing objects?** Use S3 Batch Replication.

**44. Can replication cross accounts/classes?** Yes — destination can be another account and a different storage class, and ownership can change.

**45. A use case for SRR?** Aggregating logs from multiple buckets, or replicating prod data to a test account in the same Region.

**46. How do you protect backups from ransomware?** Versioning + Object Lock (WORM) + MFA Delete, plus CRR to a second Region.

**47. What is S3 Object Lock?** Write-Once-Read-Many immutability for a retention period; must be enabled at bucket creation.

**48. How does replication help DR?** Maintains a copy in another Region so you can fail over if the primary Region is impaired.

---

## Static Hosting & Pre-Signed URLs (49–62)
**49. How do you host a static site on S3?** Enable static website hosting, set index/error documents, upload files, and allow public read (or front with CloudFront).

**50. Does the S3 website endpoint support HTTPS?** No — it's HTTP-only; use CloudFront + ACM for HTTPS and a custom domain.

**51. How do you handle SPA routing on S3?** Set the error document to index.html so client-side routes resolve.

**52. What is a pre-signed URL?** A temporary, signed URL granting time-limited access to a specific object without the recipient needing AWS credentials.

**53. Where do a pre-signed URL's permissions come from?** From the credentials of whoever generated (signed) it.

**54. Why use pre-signed URLs for uploads?** To keep the bucket private and let the browser upload directly to S3 — the server never handles file bytes, so it scales and costs less.

**55. How do you generate one in Node?** With the SDK v3 `getSignedUrl` and a `PutObjectCommand`/`GetObjectCommand`, setting `expiresIn`.

**56. How do you enforce file size/type on browser uploads?** Use a pre-signed POST policy with conditions, and validate on the server before signing.

**57. Why might a pre-signed PUT fail with SignatureDoesNotMatch?** The browser sent different headers (often Content-Type) than were used to sign — they must match.

**58. What else is needed for browser uploads?** A bucket CORS configuration allowing your origin and the PUT method.

**59. How long should pre-signed URLs last?** As short as practical (e.g., 1–5 minutes) to limit exposure.

**60. How do you serve a private file for download?** Generate a pre-signed GET URL or deliver via CloudFront — never make the object public.

**61. Can a pre-signed URL be revoked?** Not directly; it expires. To invalidate sooner, rotate the signer's credentials or use short expiry.

**62. Pre-signed URL vs CloudFront signed URL?** S3 pre-signed = direct S3 access scoped to one object; CloudFront signed = controls access to cached/edge-delivered content (often for media/premium).

---

## Security & Encryption (63–82)
**63. How is S3 access controlled?** Layered: Block Public Access, IAM policies, bucket policies, (legacy) ACLs, Object Ownership, and features like Access Points.

**64. What is Block Public Access?** A master setting (on by default) that prevents public access and overrides policies/ACLs that would grant it.

**65. IAM policy vs bucket policy?** IAM = identity-based (what a user/role can do); bucket policy = resource-based (who can do what on the bucket), supports cross-account and conditions.

**66. How do policy evaluations resolve?** Explicit Deny wins; otherwise an Allow from IAM or bucket policy grants access; default is deny.

**67. Should you use ACLs?** No — disable them with Object Ownership = Bucket owner enforced and use policies instead.

**68. How do you grant cross-account access?** Via a bucket policy (or Access Point) naming the other account/role, plus their IAM permissions.

**69. Difference between ListBucket and GetObject permissions?** ListBucket is on the bucket ARN; GetObject/PutObject are on the object ARN (`bucket/*`).

**70. How do you enforce HTTPS-only?** A bucket policy denying requests where `aws:SecureTransport` is false.

**71. Is S3 encrypted at rest by default?** Yes — SSE-S3 (AES-256) is applied to new objects automatically.

**72. SSE-S3 vs SSE-KMS vs SSE-C?** SSE-S3 = AWS-managed keys (simple); SSE-KMS = KMS keys you control with audit/rotation; SSE-C = you supply the key per request.

**73. When use SSE-KMS?** For sensitive data needing key access control, rotation, and CloudTrail audit of decrypts (HR, finance, PII).

**74. What is client-side encryption?** Encrypting data before upload so AWS never sees plaintext — maximum control.

**75. How do you reduce KMS costs/throttling at scale?** Enable S3 Bucket Keys to cut KMS API calls.

**76. How do you find sensitive data in S3?** Amazon Macie (ML-based PII discovery).

**77. How do you detect externally-shared buckets?** IAM Access Analyzer for S3.

**78. What's the most common S3 breach cause?** Accidental public access via misconfiguration.

**79. How do you audit S3 access?** CloudTrail (management + data events) and S3 server access logging; AWS Config rules for compliance.

**80. How do you implement least privilege for an app?** Grant only required actions (e.g., GetObject/PutObject) on a scoped prefix, never `s3:*` on `*`.

**81. How do you protect against accidental deletion?** Versioning + MFA Delete (+ Object Lock for immutability).

**82. How do you secure secrets used to access S3?** Use IAM roles (no static keys); if keys are unavoidable, store in Secrets Manager/SSM and rotate.

---

## CloudFront & Architecture (83–100)
**83. Why put CloudFront in front of S3?** Edge caching for low latency, reduced S3 request/transfer cost, HTTPS with custom domains, and security via a private origin.

**84. How do you keep the S3 origin private with CloudFront?** Use Origin Access Control (OAC) and a bucket policy that allows only the distribution.

**85. OAC vs OAI?** OAC is the modern, recommended mechanism (supports SSE-KMS, all Regions); OAI is legacy.

**86. How do you push new content through CloudFront?** Upload to S3 and create a CloudFront invalidation for changed paths.

**87. How do you restrict premium content on CloudFront?** CloudFront signed URLs or signed cookies.

**88. Design a secure file-upload system.** React requests a pre-signed PUT URL from a Node API (which validates and signs with an IAM role); the browser uploads directly to a private S3 bucket; downloads use pre-signed GET URLs or CloudFront; optional S3 event → Lambda for post-processing.

**89. Why direct-to-S3 instead of proxying through the server?** It offloads bandwidth/CPU from the server, scales better, and costs less; the server only signs requests.

**90. How do you trigger processing after upload?** S3 Event Notifications → Lambda/SQS/SNS (e.g., thumbnails, virus scan, transcoding).

**91. Design a media storage/delivery system.** Upload originals to a raw bucket → S3 event triggers Lambda/MediaConvert → renditions to a processed bucket → CloudFront (OAC, signed URLs for premium) for global delivery; Intelligent-Tiering/lifecycle for cost.

**92. Design a backup system.** Versioned bucket with Object Lock, lifecycle to Glacier/Deep Archive, SSE-KMS, and CRR to a DR Region; regularly test restores.

**93. Design HRMS document storage.** Private bucket (BPA on), SSE-KMS with a dedicated HR key, per-employee key prefixes with policy conditions, versioning + Object Lock for retention, CloudTrail audit, and short-lived pre-signed URLs scoped per object.

**94. How do you scope each user to only their files?** Use per-user prefixes (`users/{id}/...`) and IAM/bucket policy conditions limiting access to that prefix.

**95. How do you serve a global static website with HTTPS?** S3 (private) + CloudFront + OAC + ACM certificate + Route 53 custom domain.

**96. How do you handle huge data migrations into S3?** DataSync over the network, or Snowball devices for very large/offline transfers; S3 Transfer Acceleration for fast long-distance uploads.

**97. How do you analyze and optimize S3 cost?** S3 Storage Lens + Inventory to find waste, lifecycle/Intelligent-Tiering, CloudFront for transfer, and Cost Explorer/Budgets with tags.

**98. How do you ensure data residency/compliance?** Choose Regions in the required jurisdiction, restrict replication to compliant Regions, and audit with CloudTrail.

**99. How do you make uploads resilient and fast for big files?** Multipart upload with parallel parts and (for distant clients) Transfer Acceleration.

**100. Walk through end-to-end secure delivery of a private document.** Authenticate the user → authorize against the object's owner/prefix → generate a short-lived pre-signed GET URL (or CloudFront signed URL) → client fetches directly → access is logged in CloudTrail; the bucket stays private throughout.

➡️ Next: [09-50-scenario-questions.md](09-50-scenario-questions.md)

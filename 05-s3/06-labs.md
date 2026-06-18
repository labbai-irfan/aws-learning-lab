# Module 6 — S3 Hands-On Labs

> Learn by doing. Free-tier-friendly (5 GB storage, 20k GET, 2k PUT/month for 12 months). 🛠️ = action · 💰 = cost · ⚠️ = cleanup.

> **Setup:** AWS account with MFA + a Budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Install **AWS CLI v2** and run `aws configure` (use an IAM user with least privilege, not root). Replace `YOURNAME` with something unique.

---

## Lab 0 — CLI Sanity Check (10 min)
```bash
aws --version
aws sts get-caller-identity     # confirms who you are
aws s3 ls                       # lists your buckets (may be empty)
```

---

## Lab 1 — Create a Bucket & Upload Objects (20 min) 🛠️
```bash
B=yourname-s3-lab-$RANDOM
aws s3 mb s3://$B --region ap-south-1
echo "Hello S3" > hello.txt
aws s3 cp hello.txt s3://$B/notes/hello.txt          # upload (key = notes/hello.txt)
aws s3 ls s3://$B --recursive                         # list
aws s3 cp s3://$B/notes/hello.txt downloaded.txt      # download
aws s3 sync ./somefolder s3://$B/folder/              # sync a directory
```
**Learn:** buckets, objects, keys-as-paths, sync. 
⚠️ Keep `$B` for later labs.

---

## Lab 2 — Versioning in Action (20 min) 🛠️
```bash
aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled
echo "v1" > file.txt && aws s3 cp file.txt s3://$B/file.txt
echo "v2" > file.txt && aws s3 cp file.txt s3://$B/file.txt
aws s3api list-object-versions --bucket $B --prefix file.txt   # see v1 & v2
# delete creates a delete marker (object still recoverable):
aws s3 rm s3://$B/file.txt
aws s3api list-object-versions --bucket $B --prefix file.txt   # note the DeleteMarker
```
**Learn:** versions, delete markers, recovery. 💰 versions cost storage — Lab 4 expires them.

---

## Lab 3 — Storage Classes (15 min) 🛠️
```bash
aws s3 cp big.bin s3://$B/archive/big.bin --storage-class STANDARD_IA
aws s3api head-object --bucket $B --key archive/big.bin --query StorageClass
# change a class by copying onto itself:
aws s3 cp s3://$B/archive/big.bin s3://$B/archive/big.bin \
  --storage-class GLACIER --metadata-directive COPY
```
**Learn:** classes & how to set them. ⚠️ Glacier has min-duration/early-delete fees.

---

## Lab 4 — Lifecycle Policy (20 min) 🛠️💰
```bash
cat > lifecycle.json <<'JSON'
{ "Rules": [
  { "ID":"tier-and-expire","Status":"Enabled","Filter":{"Prefix":"logs/"},
    "Transitions":[{"Days":30,"StorageClass":"STANDARD_IA"},{"Days":90,"StorageClass":"GLACIER"}],
    "Expiration":{"Days":365},
    "NoncurrentVersionExpiration":{"NoncurrentDays":30},
    "AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7} }
]}
JSON
aws s3api put-bucket-lifecycle-configuration --bucket $B --lifecycle-configuration file://lifecycle.json
aws s3api get-bucket-lifecycle-configuration --bucket $B
```
**Learn:** automated tiering + expiry + abort-incomplete-MPU (the must-have cost rule).

---

## Lab 5 — Static Website Hosting (30 min) 🛠️
```bash
WB=yourname-site-$RANDOM
aws s3 mb s3://$WB --region ap-south-1
echo "<h1>My S3 Site</h1>" > index.html
echo "<h1>Not Found</h1>" > error.html
aws s3 cp index.html s3://$WB/ && aws s3 cp error.html s3://$WB/
aws s3 website s3://$WB --index-document index.html --error-document error.html
# make it public (deliberately, for this lab):
aws s3api put-public-access-block --bucket $WB --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
cat > pol.json <<JSON
{"Version":"2012-10-17","Statement":[{"Sid":"PublicRead","Effect":"Allow","Principal":"*",
 "Action":"s3:GetObject","Resource":"arn:aws:s3:::$WB/*"}]}
JSON
aws s3api put-bucket-policy --bucket $WB --policy file://pol.json
echo "Visit: http://$WB.s3-website-ap-south-1.amazonaws.com"
```
**Learn:** static hosting, public read, website endpoint (HTTP only).
⚠️ **Cleanup:** re-enable Block Public Access after the lab.

---

## Lab 6 — Pre-Signed URLs (25 min) 🛠️🔒 (core capstone skill)
```bash
# generate a download URL valid 5 min for a PRIVATE object
aws s3 presign s3://$B/notes/hello.txt --expires-in 300
# open the printed URL in a browser → it works without credentials, then expires
```
Pre-signed **upload** (PUT) needs the SDK — see the [capstone project](project/README.md). Try the Node snippet from [Module 1 §8](01-s3-core-concepts.md#8-pre-signed-urls).
**Learn:** temporary, credential-free, scoped access — keep buckets private.

---

## Lab 7 — Encryption (20 min) 🔒
```bash
# default encryption (SSE-S3)
aws s3api put-bucket-encryption --bucket $B --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api get-bucket-encryption --bucket $B
# upload with SSE-KMS (needs a KMS key/alias)
aws s3 cp secret.txt s3://$B/secure/secret.txt --sse aws:kms --sse-kms-key-id alias/aws/s3
aws s3api head-object --bucket $B --key secure/secret.txt --query ServerSideEncryption
```
**Learn:** SSE-S3 vs SSE-KMS, default encryption.

---

## Lab 8 — CORS for Browser Uploads (15 min) 🛠️
```bash
cat > cors.json <<'JSON'
[{"AllowedOrigins":["http://localhost:5173"],"AllowedMethods":["GET","PUT","POST","HEAD"],
  "AllowedHeaders":["*"],"ExposeHeaders":["ETag"],"MaxAgeSeconds":3000}]
JSON
aws s3api put-bucket-cors --bucket $B --cors-configuration file://cors.json
aws s3api get-bucket-cors --bucket $B
```
**Learn:** the CORS config that makes browser → S3 pre-signed uploads work (needed by the capstone).

---

## Lab 9 — Replication (CRR) (30 min) 🛠️ (advanced)
1. 🛠️ Create a destination bucket in **another Region** with versioning ON.
2. 🛠️ Enable versioning on the source `$B`.
3. 🛠️ Create an IAM role allowing S3 to replicate; attach a replication config (source → dest).
4. 🛠️ Upload a new object to `$B`; confirm it appears in the destination.
**Learn:** CRR for DR (requires versioning on both). See [Module 1 §6](01-s3-core-concepts.md#6-replication).

---

## Lab 10 — CloudFront + Private S3 (OAC) (40 min) 🌐🔒
1. 🛠️ Keep `$WB`/an origin bucket **private** (BPA on).
2. 🛠️ Create a **CloudFront distribution** with the S3 bucket as origin + **Origin Access Control (OAC)**.
3. 🛠️ Apply the generated bucket policy granting read only to the distribution.
4. 🛠️ Access the CloudFront domain over **HTTPS** — content served from edge, bucket stays private.
**Learn:** the production secure-delivery pattern. See [Module 1 §11](01-s3-core-concepts.md#11-cloudfront-integration).

---

## 🧹 Cleanup (avoid charges)
```bash
# empty + delete each bucket you created
aws s3 rm s3://$B --recursive
aws s3api delete-objects --bucket $B --delete \
  "$(aws s3api list-object-versions --bucket $B \
     --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null
aws s3 rb s3://$B --force
aws s3 rb s3://$WB --force
# disable any CloudFront distribution, then delete it
# re-enable Block Public Access on any bucket you opened
```
✅ Confirm the Billing Dashboard trends to ~$0.

➡️ Next: [07-100-mcqs.md](07-100-mcqs.md)

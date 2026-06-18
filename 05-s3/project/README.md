# Capstone Project — Secure File Upload System (React + Node + S3)

> Build a production-pattern file-upload system where files go **directly from the browser to a private S3 bucket** using **pre-signed URLs** — the server never proxies file bytes, AWS credentials never reach the browser, and the bucket is never public.

This project applies every Phase 05 concept: private buckets, IAM least privilege, pre-signed PUT/GET URLs, CORS, encryption, and (optionally) CloudFront.

---

## 📐 Architecture

```
   ┌─────────┐  1. POST /api/uploads/presign {filename,type,size}   ┌──────────────┐
   │ React   │ ───────────────────────────────────────────────────►│  Node/Express │
   │ (Vite)  │  ◄── 2. { uploadUrl, key } (pre-signed PUT, 5 min) ──│  AWS SDK v3   │
   └────┬────┘                                                       │  IAM creds    │
        │ 3. PUT file bytes DIRECTLY to uploadUrl ──────────────┐   └──────┬───────┘
        │                                                       ▼          │ validates
        │                                          ┌────────────────────┐  │ type/size
        │ 5. GET /api/uploads/:key/url             │ PRIVATE S3 BUCKET   │  │
        │ ◄── pre-signed GET URL (download) ───────│ uploads/{uuid}-name │  │
        └──────────────────────────────────────── └────────────────────┘  │
                              4. (optional) S3 Event → Lambda (scan/resize)
```

**Why this design (the interview answer):** direct-to-S3 upload offloads bandwidth/CPU from the server (scales + cheap), keeps the bucket **private** (no public access), and keeps **credentials on the server** (the browser only ever sees a short-lived, single-object URL).

---

## ✅ Prerequisites
- AWS account + AWS CLI v2 configured ([Phase 01 setup](../../01-aws-fundamentals/05-aws-account-setup-guide.md)).
- Node.js 18+ locally.
- This `project/` folder contains `backend/` (Express) and `frontend/` (React/Vite) sample code.
- 💰 Free-tier friendly. ⚠️ Clean up the bucket + IAM user when done.

---

## 🗺️ Steps
1. Create a private, encrypted S3 bucket
2. Configure CORS on the bucket
3. Create a least-privilege IAM user/role for the API
4. Configure & run the Node backend
5. Configure & run the React frontend
6. Test the end-to-end secure upload/download
7. (Optional) Add CloudFront, S3 events, hardening
8. Clean up

---

## Step 1 — Create a Private, Encrypted Bucket
```bash
B=yourname-secure-uploads-$RANDOM
REGION=ap-south-1

aws s3api create-bucket --bucket $B --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# keep it PRIVATE (Block Public Access ON)
aws s3api put-public-access-block --bucket $B --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# disable ACLs
aws s3api put-bucket-ownership-controls --bucket $B \
  --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'

# default encryption (SSE-S3) + versioning
aws s3api put-bucket-encryption --bucket $B --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled

# lifecycle: abort incomplete multipart uploads (cost hygiene)
aws s3api put-bucket-lifecycle-configuration --bucket $B --lifecycle-configuration \
  '{"Rules":[{"ID":"abort-mpu","Status":"Enabled","Filter":{"Prefix":""},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}}]}'

echo "Bucket: $B  Region: $REGION"
```

---

## Step 2 — Configure CORS (so the browser can PUT directly)
```bash
cat > cors.json <<'JSON'
[
  {
    "AllowedOrigins": ["http://localhost:5173"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
JSON
aws s3api put-bucket-cors --bucket $B --cors-configuration file://cors.json
aws s3api get-bucket-cors --bucket $B
```
⚠️ In production, replace `http://localhost:5173` with your real front-end origin (e.g., `https://app.example.com`).

---

## Step 3 — Least-Privilege IAM for the API
The API only needs to **put** and **get** objects under the `uploads/` prefix.
```bash
cat > s3-upload-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::$B/uploads/*"
    }
  ]
}
JSON

# Option A (recommended in real deployments): attach this policy to an IAM ROLE on EC2/Lambda.
# Option B (local dev): create an IAM user with this policy and use its access keys locally.
aws iam create-user --user-name todo-uploader 2>/dev/null
aws iam put-user-policy --user-name todo-uploader \
  --policy-name s3-upload --policy-document file://s3-upload-policy.json
aws iam create-access-key --user-name todo-uploader   # note AccessKeyId + SecretAccessKey
```
🔒 **Never** put these keys in the React app. They live only on the server (env/role).

---

## Step 4 — Run the Node Backend
```bash
cd backend
npm install

cat > .env <<EOF
PORT=5000
AWS_REGION=$REGION
S3_BUCKET=$B
# Local dev only — on EC2/Lambda use an IAM ROLE instead of keys:
AWS_ACCESS_KEY_ID=<from step 3>
AWS_SECRET_ACCESS_KEY=<from step 3>
# constraints
MAX_UPLOAD_MB=10
ALLOWED_TYPES=image/png,image/jpeg,application/pdf
ALLOWED_ORIGIN=http://localhost:5173
EOF
chmod 600 .env

npm start          # API on http://localhost:5000
# verify:
curl http://localhost:5000/api/health
```

---

## Step 5 — Run the React Frontend
```bash
cd ../frontend
npm install

cat > .env <<'EOF'
VITE_API_URL=http://localhost:5000
EOF

npm run dev        # open the printed URL (http://localhost:5173)
```

---

## Step 6 — Test End-to-End
1. Open the React app, pick a file (PNG/JPG/PDF under 10 MB).
2. Click **Upload**. The browser:
   - asks the API for a pre-signed URL,
   - PUTs the file **directly to S3**,
   - then requests a pre-signed GET URL to preview/download.
3. Confirm in S3 (the bucket stays private):
   ```bash
   aws s3 ls s3://$B/uploads/ --recursive
   ```
4. Try to break it (learning): upload a 50 MB file or a `.exe` → the **server rejects** it before signing. Open the S3 object URL directly without a pre-signed query → **403 Access Denied** (private bucket). 🔒

---

## Step 7 — (Optional) Production Hardening & Extensions
```
[ ] Run the API on EC2/Lambda with an IAM ROLE (no static keys)
[ ] SSE-KMS instead of SSE-S3 for sensitive files (add kms:GenerateDataKey to the role)
[ ] Pre-signed POST policy to enforce size/type at S3 (defense in depth)
[ ] Authentication (JWT/Cognito) + per-user key prefix uploads/{userId}/...
[ ] S3 Event → Lambda: virus scan, image resize, thumbnail
[ ] CloudFront + OAC to serve downloads globally over HTTPS (origin stays private)
[ ] Store file metadata (key, owner, size, type) in a database
[ ] Short pre-signed expiry (60–300s); rate-limit the presign endpoint
[ ] CloudTrail data events + S3 access logging for audit
```

**CloudFront for downloads (optional):** create a distribution with the bucket as origin + **OAC**, apply the generated bucket policy (grant read only to the distribution), then serve files via the CloudFront domain over HTTPS while the bucket stays private. See [Module 1 §11](../01-s3-core-concepts.md#11-cloudfront-integration).

---

## Step 8 — Clean Up 💰
```bash
aws s3 rm s3://$B --recursive
aws s3api delete-objects --bucket $B --delete \
  "$(aws s3api list-object-versions --bucket $B \
     --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null
aws s3 rb s3://$B --force
aws iam delete-user-policy --user-name todo-uploader --policy-name s3-upload
# delete the access key (list, then delete by id), then the user:
aws iam list-access-keys --user-name todo-uploader
# aws iam delete-access-key --user-name todo-uploader --access-key-id <id>
aws iam delete-user --user-name todo-uploader
```
✅ Confirm the Billing Dashboard trends to ~$0.

---

## 🧯 Troubleshooting
- CORS error in browser → re-check Step 2 (origin + PUT method). See [Module 5 §D](../05-troubleshooting.md#d-cors-errors-browser-uploadsdownloads).
- `SignatureDoesNotMatch` on PUT → the browser's `Content-Type` must match what the server signed. See [Module 5 §C](../05-troubleshooting.md#c-pre-signed-url-problems-common-in-the-capstone).
- 403 from API signing → the IAM identity lacks `s3:PutObject` on `uploads/*`.

## 📂 Project Files
- [`backend/`](backend/) — `server.js` (presign endpoints + validation), `package.json`, `.env.example`
- [`frontend/`](frontend/) — Vite React app: `src/App.jsx` (upload UI), `package.json`, `index.html`

## 📖 Concept references
- Pre-signed URLs → [Module 1 §8](../01-s3-core-concepts.md#8-pre-signed-urls)
- File upload architecture → [Module 2 §1](../02-architectures.md#1-file-upload-architecture)
- Security → [Module 4](../04-security-guide.md)

---

🎉 You've built the exact pattern behind "let users upload files" in real products — secure, scalable, and credential-safe.

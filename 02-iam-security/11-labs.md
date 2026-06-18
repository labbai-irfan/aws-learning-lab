# Module 11 — IAM & Security Labs (Hands-On)

> Console + CLI labs that build real security muscle memory. Do them in order. **Setup:** an AWS account, AWS CLI v2 (`aws configure` as an admin user — *not* root), and a Budget alert ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)).

**Legend:** 🛠️ run this · ✅ verify · 🔒 security point · ⚠️ gotcha · 💰 cost. Replace `<placeholders>`.

---

## Lab 1 — Lock down the account (root + baseline)
**Goal:** a secure account baseline before anything else.

1. 🛠️ Sign in as **root** → enable **MFA** on the root user → remove any root **access keys**.
2. Create an **admin IAM user** (or use IAM Identity Center) for daily work; enable MFA on it.
3. Set a strong **account password policy**:
```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 --require-symbols --require-numbers \
  --require-uppercase-characters --require-lowercase-characters \
  --max-password-age 90 --password-reuse-prevention 5
```
4. 🛠️ Create a **Budget** alert so security experiments can't surprise you.

✅ **Verify:** root has MFA + no access keys; `aws iam get-account-password-policy` returns your policy.
🔒 The root user is now used only for the handful of tasks that *require* it.

---

## Lab 2 — Users, groups & least-privilege policies
**Goal:** grant only what's needed via a group.

1. 🛠️ Create a group and a **scoped** policy (read-only on one bucket):
```bash
aws iam create-group --group-name hrms-readers
cat > s3-read.json <<'EOF'
{ "Version":"2012-10-17","Statement":[{
  "Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],
  "Resource":["arn:aws:s3:::hrms-docs-<unique>","arn:aws:s3:::hrms-docs-<unique>/*"] }]}
EOF
aws iam put-group-policy --group-name hrms-readers \
  --policy-name s3-read-hrms --policy-document file://s3-read.json
aws iam create-user --user-name analyst1
aws iam add-user-to-group --user-name analyst1 --group-name hrms-readers
```
2. ✅ **Verify** with the policy simulator or by assuming the user:
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<acct>:user/analyst1 \
  --action-names s3:GetObject s3:DeleteObject \
  --resource-arns arn:aws:s3:::hrms-docs-<unique>/file.pdf
# GetObject = allowed, DeleteObject = implicitDeny
```
🔒 Attach policies to **groups**, not individual users. ⚠️ Never start from `AdministratorAccess` and trim later — start minimal and add.

---

## Lab 3 — IAM role for EC2 (no static keys)
**Goal:** give an app AWS access with **zero** hard-coded keys.

1. 🛠️ Create a role trusted by EC2 with a least-privilege policy, attach via instance profile:
```bash
cat > trust.json <<'EOF'
{ "Version":"2012-10-17","Statement":[{
  "Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},
  "Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name hrms-ec2-role --assume-role-policy-document file://trust.json
aws iam put-role-policy --role-name hrms-ec2-role --policy-name s3-read \
  --policy-document file://s3-read.json
aws iam create-instance-profile --instance-profile-name hrms-ec2-profile
aws iam add-role-to-instance-profile --instance-profile-name hrms-ec2-profile \
  --role-name hrms-ec2-role
# attach hrms-ec2-profile to your instance (run-instances --iam-instance-profile ...)
```
2. ✅ **Verify** on the instance — credentials come from the metadata service, not files:
```bash
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/hrms-ec2-role
aws s3 ls s3://hrms-docs-<unique>   # works, with no aws configure keys
```
🔒 This is the #1 fix for leaked credentials: **roles over keys**, everywhere.

---

## Lab 4 — Cross-account access with STS AssumeRole
**Goal:** let Account B access a resource in Account A without sharing keys.

1. 🛠️ In **Account A**, create a role trusting Account B:
```bash
# trust: principal = arn:aws:iam::<ACCOUNT_B>:root  (+ optional ExternalId condition)
aws iam create-role --role-name CrossReadHRMS --assume-role-policy-document file://trust-b.json
aws iam put-role-policy --role-name CrossReadHRMS --policy-name s3read --policy-document file://s3-read.json
```
2. 🛠️ From **Account B**, assume it and use the temporary creds:
```bash
aws sts assume-role --role-arn arn:aws:iam::<ACCOUNT_A>:role/CrossReadHRMS \
  --role-session-name demo --external-id <secret>
# export the returned AccessKeyId/SecretAccessKey/SessionToken, then call A's bucket
```
✅ **Verify:** `aws sts get-caller-identity` shows the assumed-role ARN. 🔒 Use an **ExternalId** for third-party/confused-deputy protection.

---

## Lab 5 — Permission boundaries & SCP guardrails
**Goal:** cap the *maximum* permissions an identity can have.

1. 🛠️ Attach a **permissions boundary** so even an over-broad policy can't exceed it:
```bash
# boundary allows only S3 + CloudWatch; user policy may grant more but boundary caps it
aws iam put-user-permissions-boundary --user-name analyst1 \
  --permissions-boundary arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```
2. 🛠️ (Organizations) Apply an **SCP** denying disallowed Regions/actions at the OU level:
```json
{ "Version":"2012-10-17","Statement":[{
  "Sid":"DenyOutsideRegions","Effect":"Deny","NotAction":["iam:*","sts:*","cloudfront:*"],
  "Resource":"*","Condition":{"StringNotEquals":{"aws:RequestedRegion":["us-east-1","ap-south-1"]}}}]}
```
✅ **Verify:** analyst1 can't exceed the boundary; actions in other Regions are denied org-wide.
🔒 Effective access = **identity policy ∩ SCP ∩ boundary**, minus any explicit Deny.

---

## Lab 6 — KMS encryption (envelope encryption in practice)
**Goal:** create a customer-managed key and encrypt data with it.

1. 🛠️ Create a CMK with rotation, encrypt/decrypt a value:
```bash
KEY=$(aws kms create-key --description "hrms-cmk" --query KeyMetadata.KeyId --out text)
aws kms enable-key-rotation --key-id $KEY
aws kms encrypt --key-id $KEY --plaintext fileb://<(echo -n "salary-data") \
  --query CiphertextBlob --out text | base64 -d > cipher.bin
aws kms decrypt --ciphertext-blob fileb://cipher.bin --query Plaintext --out text | base64 -d
```
2. 🛠️ Use it for **S3 SSE-KMS** and **EBS** default encryption.
✅ **Verify:** decrypt returns the original; CloudTrail logs the `Decrypt` call (who/when).
🔒 CMKs give you **key policy, rotation, and an audit trail** that SSE-S3/AWS-managed keys don't.

---

## Lab 7 — Secrets Manager (store + rotate DB credentials)
**Goal:** stop hard-coding DB passwords.

1. 🛠️ Store and retrieve a secret:
```bash
aws secretsmanager create-secret --name hrms/db \
  --secret-string '{"username":"hrms","password":"<gen-strong>"}'
aws secretsmanager get-secret-value --secret-id hrms/db --query SecretString --out text
```
2. 🛠️ Enable **automatic rotation** (attach a rotation Lambda / RDS-managed rotation).
3. ✅ App reads the secret at runtime via a least-privilege role (`secretsmanager:GetSecretValue` on that ARN only).
🔒 Secrets never live in code, env files, or images. ⚠️ Scope the read permission to the **specific secret ARN**, not `*`.

---

## Lab 8 — Turn on the detectors (CloudTrail, Config, GuardDuty)
**Goal:** know who did what, and get alerted on threats.

1. 🛠️ Ensure an **org/account CloudTrail** writes to a locked S3 bucket (ideally a separate log-archive account).
2. 🛠️ Enable **AWS Config** + a few managed rules (e.g., `s3-bucket-public-read-prohibited`, `iam-user-mfa-enabled`).
3. 🛠️ Enable **GuardDuty**:
```bash
aws guardduty create-detector --enable
```
4. ✅ **Verify:** CloudTrail `lookup-events` returns recent activity; Config shows compliance; GuardDuty has a detector.
🔒 Preventive controls (IAM/SCP/SG) stop bad actions; **detective** controls (these) catch what slips through.

---

## Lab 9 — S3 data protection
**Goal:** make a bucket private, encrypted, and policy-guarded.

1. 🛠️ Enforce Block Public Access + default SSE-KMS + a least-privilege bucket policy:
```bash
aws s3api put-public-access-block --bucket hrms-docs-<unique> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket hrms-docs-<unique> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
```
2. ✅ **Verify:** uploading without encryption still lands encrypted; public access is blocked at account + bucket level.
🔒 Public buckets holding private data are the classic breach headline — this lab prevents it.

---

## Lab 10 — Find exposure & run a leaked-key drill
**Goal:** detect external access and practice incident response.

1. 🛠️ Enable **IAM Access Analyzer** and review findings for anything shared outside the account:
```bash
aws accessanalyzer create-analyzer --analyzer-name acct --type ACCOUNT
aws accessanalyzer list-findings --analyzer-arn <arn>
```
2. 🛠️ **Drill:** simulate a leaked access key →
   - `aws iam update-access-key --access-key-id <id> --status Inactive` (contain)
   - rotate/delete the key, review CloudTrail for what it did, restore least privilege.
✅ **Verify:** the key is inactive; CloudTrail shows the timeline. 🔒 Practice this *before* you need it.

---

## Cleanup 💰
Delete lab users/roles/policies, the KMS key (schedule deletion), the secret, the analyzer, and any test buckets so nothing lingers or bills.
```bash
aws iam remove-user-from-group --user-name analyst1 --group-name hrms-readers
aws iam delete-user --user-name analyst1
aws kms schedule-key-deletion --key-id $KEY --pending-window-in-days 7
aws secretsmanager delete-secret --secret-id hrms/db --force-delete-without-recovery
```

---
*Back to [IAM & Security README](README.md). Test yourself: [10 — MCQs](10-100-mcqs.md) · [09 — Interview Questions](09-100-interview-questions.md).*

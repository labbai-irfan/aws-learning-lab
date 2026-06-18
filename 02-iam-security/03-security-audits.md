# Module 3 — Security Audits

> How to audit an AWS account's security posture — the tools, the checks, and a repeatable audit workflow with commands. Use this monthly (or after any change).

---

## The Audit Toolbox

| Tool | What it audits |
|------|----------------|
| **IAM Credential Report** | All users: passwords, keys, MFA, last-used dates (CSV) |
| **IAM Access Analyzer** | Resources shared externally + **unused access** (roles/keys/permissions) |
| **IAM Last Accessed (Access Advisor)** | Which services a principal actually used → right-size permissions |
| **AWS Config** | Resource configs vs rules over time (drift, compliance) |
| **AWS Security Hub** | Aggregated findings + best-practice standards (CIS, AWS FSBP) |
| **Amazon GuardDuty** | Active threat detection (anomalous behavior) |
| **AWS Trusted Advisor** | Security checks (open SGs, MFA on root, exposed keys) |
| **Amazon Macie** | Sensitive data (PII) discovery in S3 |
| **CloudTrail** | Who did what, when (the forensic log) |
| **Amazon Inspector** | Vulnerability scanning (EC2/ECR/Lambda) |
| **AWS Audit Manager** | Map evidence to compliance frameworks |

---

## The Audit Workflow (run top to bottom)

### Step 1 — Identity hygiene (IAM Credential Report)
```bash
aws iam generate-credential-report
aws iam get-credential-report --query Content --output text | base64 -d > report.csv
```
Review for 🔎:
- ❌ **Root** with access keys, or root used recently, or no MFA on root.
- ❌ Users **without MFA** (especially privileged).
- ❌ **Access keys** older than 90 days, or unused for 90+ days.
- ❌ **Inactive users** (no console/key use in 90 days) → disable/remove.
- ❌ Two active keys per user when only one is needed.

### Step 2 — Find unused & external access (Access Analyzer)
```bash
aws accessanalyzer create-analyzer --analyzer-name org-audit --type ACCOUNT
aws accessanalyzer list-findings --analyzer-name org-audit
# unused-access analyzer surfaces unused roles, keys, and excess permissions
```
🔎 Remove resources shared with unknown external principals; revoke unused roles/permissions.

### Step 3 — Right-size permissions (Access Advisor / last accessed)
```bash
JOB=$(aws iam generate-service-last-accessed-details \
  --arn arn:aws:iam::123:role/app-role --query JobId --output text)
aws iam get-service-last-accessed-details --job-id $JOB
```
🔎 If a role has `s3:*`, `ec2:*` but only ever used a few S3 actions → tighten to those.

### Step 4 — Policy quality review
🔎 Hunt for:
- `"Action":"*"` / `"Resource":"*"` (admin-equivalent) on non-admin identities.
- Unrestricted `iam:PassRole`, `iam:CreatePolicyVersion`, `iam:AttachUserPolicy` (priv-esc risks).
- Missing **Conditions** (no MFA/IP/Region constraints on sensitive actions).
- Use the IAM policy simulator / Access Analyzer **policy validation** for findings.

### Step 5 — Network & public exposure
```bash
# Security Groups open to the world
aws ec2 describe-security-groups \
  --query "SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp,'0.0.0.0/0')]].GroupId"
```
🔎 Flag `0.0.0.0/0` on 22/3389/3306/etc. Check **S3 Block Public Access** on every bucket; RDS not publicly accessible; ELB/ALB exposure intended.

### Step 6 — Data protection
🔎 Verify:
- EBS/RDS/S3 **encryption enabled**; **KMS** key policies least-privilege; key rotation on.
- **Secrets in Secrets Manager** (none hardcoded); rotation configured.
- Backups exist, encrypted, versioned, and **restorable** (test).

### Step 7 — Logging & detection coverage
🔎 Confirm:
- **CloudTrail** in all Regions, **log file validation** on, logs in a locked S3 (separate account).
- **GuardDuty** enabled in all Regions; **Config** recording; **Security Hub** standards on.
- CloudWatch **alarms** for root login, IAM changes, `StopLogging`, failed logins.

### Step 8 — Org guardrails
🔎 Confirm SCPs deny: disabling logging, leaving the org, unapproved Regions, root usage; permission boundaries on delegated principals; account separation (prod/dev/security).

---

## Quick Audit Scorecard
```
IDENTITY
[ ] Root: MFA on, no keys, unused
[ ] All privileged users have MFA
[ ] No access keys >90 days / unused
[ ] No inactive users/roles
[ ] No wildcard admin on non-admins
[ ] iam:PassRole scoped; no priv-esc actions loose

DATA
[ ] Encryption at rest (S3/EBS/RDS) + TLS in transit
[ ] KMS least-privilege + rotation
[ ] Secrets in Secrets Manager, rotating
[ ] Backups encrypted, versioned, tested

NETWORK
[ ] No 0.0.0.0/0 on admin/db ports
[ ] S3 Block Public Access ON everywhere
[ ] RDS not public

DETECTION
[ ] CloudTrail all-Region + validation + locked bucket
[ ] GuardDuty + Config + Security Hub ON
[ ] Alarms: root login, IAM changes, StopLogging

GOVERNANCE
[ ] SCPs (protect logs, Regions, root)
[ ] Permission boundaries on delegated IAM
[ ] Multi-account separation + tagging
```

---

## Audit Cadence
| Frequency | Activity |
|-----------|----------|
| **Continuous** | GuardDuty, Config, Security Hub, alarms (automated) |
| **Weekly** | Triage new findings; review CloudTrail anomalies |
| **Monthly** | Credential report, Access Analyzer unused access, SG review |
| **Quarterly** | Full access review / least-privilege right-sizing; IR drill |
| **On change** | Policy/role changes peer-reviewed; re-run relevant checks |

💡 **Tip:** Automate the recurring checks (Config rules + Security Hub standards + scheduled Lambda for credential reports) so the human review focuses on judgment, not data collection.

➡️ Next: [04-least-privilege-examples.md](04-least-privilege-examples.md)

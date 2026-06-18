# Module 1 — AWS Security Core Concepts

> Every AWS security building block explained, with definitions, key points, JSON policy examples, CLI commands, and best-practice tips.

## Table of Contents
1. [IAM](#1-iam)
2. [Users](#2-users)
3. [Groups](#3-groups)
4. [Roles](#4-roles)
5. [Policies](#5-policies)
6. [MFA](#6-mfa)
7. [Permission Boundaries](#7-permission-boundaries)
8. [SCP (Service Control Policies)](#8-scp-service-control-policies)
9. [Secrets Manager](#9-secrets-manager)
10. [KMS (Key Management Service)](#10-kms-key-management-service)
11. [Security Best Practices](#11-security-best-practices)

---

## 1. IAM

**Definition:** **IAM (Identity and Access Management)** is the AWS service that controls **authentication** (who you are) and **authorization** (what you're allowed to do). It's **free**, **global** (not Region-bound), and the foundation of all AWS security.

### The core question IAM answers
> **Is this _principal_ allowed to perform this _action_ on this _resource_ under these _conditions_?**

### Key building blocks
| Element | Meaning |
|---------|---------|
| **Principal** | The identity making a request (user, role, service, federated identity) |
| **Action** | The API operation (e.g., `s3:GetObject`, `ec2:StartInstances`) |
| **Resource** | What the action targets (an ARN) |
| **Policy** | JSON that allows/denies actions on resources |
| **Condition** | Optional constraints (IP, MFA, time, tags) |

### How a request is evaluated (simplified)
```
1. Is there an explicit DENY (any policy, SCP, boundary)?  → DENY (deny always wins)
2. Does an SCP / permission boundary forbid it?            → DENY
3. Is there an explicit ALLOW (identity or resource policy)?→ ALLOW
4. Otherwise (implicit deny)                                → DENY
```

💡 **Exam tip:** IAM is **global** and **free**. **Explicit Deny always overrides Allow.** Default is **implicit deny** (nothing is allowed until granted).

---

## 2. Users

**Definition:** An **IAM user** is a long-lived identity representing a **person** or (legacy) application, with its own credentials: a console **password** and/or programmatic **access keys**.

### Key facts
- Each user has a unique name + ARN and can have up to **2 access keys** (for rotation).
- Users get permissions via **attached policies** or (preferably) **group membership**.
- ⚠️ **Avoid IAM users for applications** — use **roles** (temporary creds) instead. Prefer **IAM Identity Center (SSO)** for human access in organizations.

### The root user (special, dangerous)
- The account's **email login** — has **unrestricted** power (billing, close account, everything).
- 🔒 **Enable MFA on root, then lock it away.** Never use it for daily work. Never create root access keys.

### CLI
```bash
aws iam create-user --user-name alice
aws iam create-access-key --user-name alice           # returns keys ONCE — store securely
aws iam list-access-keys --user-name alice
aws iam delete-access-key --user-name alice --access-key-id AKIA...
```

🔒 **Best practice:** Humans → IAM Identity Center / federation. Apps → IAM **roles**. If you must use access keys, **rotate** them regularly and never commit them to code.

---

## 3. Groups

**Definition:** An **IAM group** is a collection of users that **share the same permissions**. Attach policies to the group; every member inherits them.

### Key facts
- Manage permissions by **role/function** (e.g., `Developers`, `Admins`, `Finance`, `ReadOnly`).
- A user can belong to **multiple groups**.
- ⚠️ Groups **cannot** be nested (no group inside a group), and a group is **not** a principal (you can't grant a role's trust to a group).

```
   [Admins]    → AdministratorAccess
   [Developers]→ PowerUserAccess (scoped)     ← attach policies to GROUPS, not users
   [Finance]   → Billing + read-only
        │  members inherit
   alice ∈ Admins ; bob,ravi ∈ Developers ; priya ∈ Finance
```

### CLI
```bash
aws iam create-group --group-name Developers
aws iam attach-group-policy --group-name Developers \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam add-user-to-group --group-name Developers --user-name bob
```

💡 **Best practice:** Always assign permissions to **groups**, not individual users — easier to manage and audit.

---

## 4. Roles

**Definition:** An **IAM role** is an identity with permissions that can be **assumed temporarily** by trusted entities. It has **no long-term credentials** — when assumed, it issues short-lived credentials via STS. **Roles are the secure default for applications, AWS services, and cross-account access.**

### Why roles beat access keys 🔒
- **No static keys** to leak; credentials are **temporary** and auto-rotated.
- Scoped by a **trust policy** (who can assume it) + a **permissions policy** (what it can do).

### Common role use cases
| Use case | Example |
|----------|---------|
| **EC2 → AWS** | Instance profile lets EC2 read S3 without stored keys |
| **Lambda → AWS** | Lambda execution role grants DynamoDB access |
| **Cross-account** | Account B assumes a role in Account A |
| **Federation/SSO** | Corporate users get a role on login |
| **Service-linked** | AWS services act on your behalf |

### Two policies on every role
1. **Trust policy** (who can assume it):
```json
{ "Version":"2012-10-17",
  "Statement":[{"Effect":"Allow",
    "Principal":{"Service":"ec2.amazonaws.com"},
    "Action":"sts:AssumeRole"}]}
```
2. **Permissions policy** (what it can do): e.g., `AmazonS3ReadOnlyAccess`.

### Assume a role (CLI)
```bash
aws sts assume-role --role-arn arn:aws:iam::111122223333:role/app-role \
  --role-session-name demo
# returns temporary AccessKeyId/SecretAccessKey/SessionToken (expire in ~1h)
```

💡 **Exam tip:** Roles = **temporary credentials**, ideal for EC2/Lambda/cross-account. **Trust policy** = who can assume; **permissions policy** = what they can do. Use **roles, not keys**, for anything programmatic.

---

## 5. Policies

**Definition:** A **policy** is a JSON document that defines permissions. AWS evaluates policies to allow or deny requests.

### Policy types
| Type | Attached to | Purpose |
|------|-------------|---------|
| **Identity-based** | User/group/role | What this identity can do |
| **Resource-based** | A resource (S3 bucket, KMS key, SQS) | Who can access this resource (supports cross-account) |
| **Permission boundary** | User/role | The *max* permissions a principal can have (§7) |
| **SCP** | OU/account (Organizations) | Org-wide *max* permissions (§8) |
| **Session policy** | Passed at assume-role | Further limits a session |
| **ACL (legacy)** | S3/some resources | Old-style grants — avoid |

### Managed vs inline
- **AWS managed** — maintained by AWS (e.g., `AmazonS3ReadOnlyAccess`); convenient, broad.
- **Customer managed** — your reusable policies (recommended for custom needs).
- **Inline** — embedded in one identity; use sparingly (hard to audit/reuse).

### Anatomy of a policy statement
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "ReadAppBucket",
    "Effect": "Allow",                       // Allow or Deny
    "Action": ["s3:GetObject"],              // the API actions
    "Resource": "arn:aws:s3:::my-app/*",     // the target ARNs
    "Condition": {                           // optional constraints
      "Bool": {"aws:MultiFactorAuthPresent":"true"},
      "IpAddress": {"aws:SourceIp":"203.0.113.0/24"}
    }
  }]
}
```

### Useful condition keys
`aws:MultiFactorAuthPresent` (require MFA), `aws:SourceIp` (IP allowlist), `aws:RequestedRegion` (restrict Regions), `aws:PrincipalTag`/`aws:ResourceTag` (ABAC), `aws:SecureTransport` (require TLS).

💡 **Exam tip:** **Explicit Deny > Allow > implicit Deny.** Identity policies say what an identity can do; resource policies say who can touch a resource (and enable cross-account). Use **Conditions** for MFA/IP/Region/tag restrictions.

---

## 6. MFA

**Definition:** **Multi-Factor Authentication (MFA)** requires a **second factor** (a time-based code or hardware key) in addition to a password — so a stolen password alone can't grant access.

### MFA options
| Type | Examples |
|------|----------|
| **Virtual MFA** | Google Authenticator, Authy, Microsoft Authenticator |
| **Hardware TOTP** | Key-fob token |
| **FIDO security key** | YubiKey (phishing-resistant) |
| **Passkeys** | Supported for IAM/root sign-in |

### Where MFA is mandatory 🔒
- **Root user** — always.
- **Privileged IAM users** (admins, anyone who can change IAM/billing).
- Enforce via policy with `aws:MultiFactorAuthPresent` so sensitive actions require MFA:
```json
{ "Effect":"Deny","Action":"*","Resource":"*",
  "Condition":{"BoolIfExists":{"aws:MultiFactorAuthPresent":"false"}}}
```

### CLI
```bash
aws iam enable-mfa-device --user-name alice \
  --serial-number arn:aws:iam::123:mfa/alice \
  --authentication-code1 123456 --authentication-code2 654321
```

💡 **Exam tip:** MFA stops credential-theft attacks. Enforce it on root and privileged users; require it for sensitive operations via a policy condition.

---

## 7. Permission Boundaries

**Definition:** A **permission boundary** is a managed policy that sets the **maximum permissions an IAM user or role can have**. Effective permissions = the **intersection** of the identity's policies **AND** the boundary. A boundary **never grants** — it only **caps**.

### Why it matters
- Lets you **delegate** IAM (e.g., let developers create roles) **without** them escalating privileges beyond a cap.
- Effective access = `identity policies ∩ boundary` (and still subject to SCPs/explicit deny).

```
   What a role could do (its policies)  ──────► broad
   Permission boundary                   ──────► cap
   EFFECTIVE = intersection of the two   ──────► only what's in BOTH
```

### Example: a boundary limiting a delegated role to S3 + CloudWatch only
```json
{ "Version":"2012-10-17",
  "Statement":[{"Effect":"Allow",
    "Action":["s3:*","cloudwatch:*","logs:*"],
    "Resource":"*"}]}
```
Even if someone attaches `AdministratorAccess` to a role with this boundary, the role can still **only** do S3/CloudWatch/Logs.

### CLI
```bash
aws iam put-user-permissions-boundary --user-name dev \
  --permissions-boundary arn:aws:iam::123:policy/DevBoundary
```

💡 **Exam tip:** **Boundary = max permissions for a principal** (intersection). SCP = max for an **account/OU**. Both **limit**, never grant. Use boundaries to safely **delegate IAM**.

---

## 8. SCP (Service Control Policies)

**Definition:** **Service Control Policies** are **organization-wide guardrails** (via AWS Organizations) that define the **maximum** permissions for accounts/OUs. Like boundaries, SCPs **limit, never grant**, and apply even to the **root user** of member accounts.

### Key facts
- Attached to the **org root, OUs, or individual accounts**.
- The **management account is not restricted** by SCPs.
- Effective permissions = `SCP ∩ identity policies ∩ (boundary if any)`.
- Two strategies: **deny lists** (allow all, then deny specific) or **allow lists** (deny all, allow specific).

### Common SCP guardrails
```json
// Deny disabling CloudTrail (protect the audit log)
{ "Version":"2012-10-17","Statement":[{
   "Effect":"Deny","Action":["cloudtrail:StopLogging","cloudtrail:DeleteTrail"],
   "Resource":"*"}]}
```
```json
// Restrict to approved Regions
{ "Version":"2012-10-17","Statement":[{
   "Effect":"Deny","NotAction":["iam:*","sts:*","cloudfront:*","route53:*"],
   "Resource":"*",
   "Condition":{"StringNotEquals":{"aws:RequestedRegion":["ap-south-1","us-east-1"]}}}]}
```
Other classics: deny leaving the org, deny disabling GuardDuty/Config, deny root usage, enforce encryption.

### SCP vs Permission Boundary vs IAM policy
| | Scope | Grants? | Applies to root? |
|---|------|---------|------------------|
| **IAM policy** | One identity | ✅ grants | n/a |
| **Permission boundary** | One IAM principal | ❌ caps only | no |
| **SCP** | Account/OU (whole org) | ❌ caps only | ✅ yes (member accts) |

💡 **Exam tip:** SCP = **org-wide max**, applies to member-account root, doesn't restrict the management account. Combine with boundaries + IAM for layered control.

---

## 9. Secrets Manager

**Definition:** **AWS Secrets Manager** securely **stores, retrieves, and automatically rotates** secrets — database passwords, API keys, tokens — so you **never hardcode credentials**.

### Why use it 🔒
- Secrets are **encrypted with KMS** at rest and fetched at runtime via API/IAM.
- **Automatic rotation** (built-in for RDS/Redshift/DocumentDB; custom via Lambda).
- **Audited** via CloudTrail; access controlled by IAM + resource policy.
- Cross-account/cross-Region sharing and replication.

### Secrets Manager vs SSM Parameter Store
| | Secrets Manager | SSM Parameter Store (SecureString) |
|---|-----------------|-----------------------------------|
| Rotation | ✅ built-in automatic | ❌ manual |
| Cost | per secret + API calls | free tier (standard) |
| Best for | DB creds, rotated secrets | config + simple secrets on a budget |

### Use it (CLI + app)
```bash
aws secretsmanager create-secret --name prod/db \
  --secret-string '{"username":"app","password":"S3cret!"}'
aws secretsmanager get-secret-value --secret-id prod/db --query SecretString --output text
```
```javascript
// Node — fetch at runtime, never store in code/repo
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
const sm = new SecretsManagerClient({ region: "ap-south-1" });
const { SecretString } = await sm.send(new GetSecretValueCommand({ SecretId: "prod/db" }));
const { username, password } = JSON.parse(SecretString);
```

💡 **Exam tip:** Secrets Manager = **store + auto-rotate** secrets (KMS-encrypted). Parameter Store = cheaper config/secrets without auto-rotation. Grant apps access via an **IAM role**, never embed secrets.

---

## 10. KMS (Key Management Service)

**Definition:** **AWS KMS** creates and manages **encryption keys** and performs cryptographic operations, providing **encryption at rest** for most AWS services with centralized control and full **audit (CloudTrail)**.

### Key types
| Type | Who manages | Notes |
|------|-------------|-------|
| **AWS managed keys** | AWS (e.g., `aws/s3`) | Auto-created per service; no key policy control |
| **Customer managed keys (CMK)** | You | Full control: key policy, rotation, grants, audit |
| **AWS owned keys** | AWS (invisible) | Used internally by some services |

### How access works
- A KMS key has a **key policy** (the root of trust) plus optional **IAM** and **grants**.
- To use a key you need permission for actions like `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey`.
- **Envelope encryption:** KMS encrypts a **data key**, which encrypts your data — efficient for large data (used by S3/EBS).
- **Automatic key rotation** (yearly) for CMKs; CloudTrail logs every use.

### Where KMS shows up
S3 (SSE-KMS), EBS volume encryption, RDS encryption, Secrets Manager, DynamoDB, Lambda env vars, and more.

### CLI
```bash
aws kms create-key --description "app data key"
aws kms create-alias --alias-name alias/app-key --target-key-id <key-id>
aws kms encrypt --key-id alias/app-key --plaintext fileb://secret.bin --query CiphertextBlob --output text
aws kms enable-key-rotation --key-id <key-id>
```

🔒 **Best practice:** Use **customer managed keys** for sensitive data so you control the key policy + audit decrypts. Enable rotation. Restrict `kms:Decrypt` to the roles that truly need it.

💡 **Exam tip:** KMS = managed encryption keys + audit. **Key policy** is the primary access control. Envelope encryption uses data keys. CMK = your control; AWS managed = convenience.

---

## 11. Security Best Practices

The consolidated rulebook — these recur in every audit and interview.

### Identity & access 🔒
```
[ ] Enable MFA on root; lock root away; no root access keys; no daily root use
[ ] Humans via IAM Identity Center (SSO)/federation; apps via IAM ROLES (no static keys)
[ ] Least privilege — grant only needed actions on specific resources
[ ] Permissions via GROUPS; reusable customer-managed policies
[ ] MFA enforced for privileged users + sensitive actions (condition keys)
[ ] Rotate any unavoidable access keys; delete unused users/keys/roles
[ ] Permission boundaries when delegating IAM; SCP guardrails org-wide
```
### Data protection 🔒
```
[ ] Encrypt at rest (KMS) and in transit (TLS); enforce via policy conditions
[ ] Secrets in Secrets Manager/Parameter Store — never in code/env files in git
[ ] S3 Block Public Access ON; disable ACLs; scope bucket policies
[ ] Backups + versioning; KMS-encrypted snapshots
```
### Detection & response 🔒
```
[ ] CloudTrail ON (all Regions, log file validation, immutable S3)
[ ] GuardDuty (threat detection), AWS Config (compliance), Security Hub (aggregate)
[ ] IAM Access Analyzer (external access), Credential Report reviews
[ ] CloudWatch alarms on root usage, IAM changes, failed logins; SNS notifications
[ ] Incident response playbooks + runbooks; tested
```
### Governance 🔒
```
[ ] Multi-account (Organizations): separate prod/dev/security/audit accounts
[ ] Tagging standard (Owner/Env/DataClass); cost + access visibility
[ ] Infrastructure as Code (least-priv baked in); peer-reviewed changes
[ ] Regular access reviews / least-privilege right-sizing (Access Analyzer)
```

### The 10 commandments (quick recall)
```
1. Never use root daily; MFA it and lock it away
2. Roles over access keys, always
3. Least privilege, every time
4. Encrypt everything (KMS) + TLS in transit
5. Never hardcode secrets (Secrets Manager)
6. Turn on CloudTrail + GuardDuty everywhere
7. Block public access by default (S3, SGs)
8. Use SCPs + permission boundaries as guardrails
9. Monitor + alert on sensitive events
10. Have (and test) an incident response plan
```

💡 **Exam tip:** If unsure on any security question, the answer usually involves **least privilege**, **roles instead of keys**, **MFA**, **encryption (KMS)**, and **logging (CloudTrail)**.

---

## ✅ Module 1 Recap
You can now explain: IAM evaluation (explicit deny wins) · users vs roles (and why roles win) · groups for shared permissions · the role trust + permissions model · policy types (identity/resource/boundary/SCP) and managed vs inline · MFA enforcement · permission boundaries (max for a principal) · SCPs (org-wide max, hit member root) · Secrets Manager (store + rotate) · KMS (keys, key policy, envelope encryption) · the consolidated best practices.

➡️ Next: [02-real-attack-scenarios.md](02-real-attack-scenarios.md)

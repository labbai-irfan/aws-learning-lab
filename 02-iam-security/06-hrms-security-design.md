# Module 6 — HRMS Security Design (End-to-End)

> A complete, compliance-grade security design for an **HRMS (Human Resource Management System)** — the toughest common use case because it holds highly sensitive PII (salaries, IDs, contracts, performance, medical). This ties together IAM, KMS, Secrets Manager, encryption, network, logging, and IR.

> Builds on the [HRMS file-storage architecture in Phase 05 §4](../05-s3/02-architectures.md#4-hrms-file-storage-architecture).

---

## 1. Why HRMS Needs Extra Care
HRMS data is **PII + financial + sometimes health** → subject to **GDPR, local labor law, ISO 27001, SOC 2**, and strict **retention** rules. A leak means regulatory fines, lawsuits, and severe reputational damage. Design principles: **least privilege, strong encryption, full audit, data minimization, retention enforcement.**

### Data classification (drives every control)
| Class | Examples | Controls |
|-------|----------|----------|
| **Restricted** | National ID, bank details, salary, medical | KMS (dedicated key), strict access, full audit, masked in UI |
| **Confidential** | Contracts, reviews, addresses | KMS, role-based access, audit |
| **Internal** | Org chart, job titles | Standard encryption, broad-internal read |
| **Public** | Company name, public job posts | Standard |

---

## 2. Reference Architecture

```
                         Employees / HR / Managers / Admins
                                       │  (browser, MFA)
                                       ▼
                         IAM Identity Center / Cognito (SSO + MFA)
                                       │  short-lived tokens
                         ┌─────────────▼─────────────┐
                         │  WAF → ALB (HTTPS/ACM)     │   public subnet
                         └─────────────┬─────────────┘
                                       ▼
                         ┌───────────────────────────┐
                         │ App tier (EC2/ECS/Lambda)  │   private subnet
                         │  IAM ROLE (least privilege)│
                         │  RBAC + row-level auth      │
                         └───┬───────────┬───────────┘
            Secrets Manager  │           │  KMS (HR CMK: Encrypt/Decrypt audited)
            (DB creds, keys) │           │
                  ┌──────────▼──┐    ┌───▼───────────────┐   isolated subnet
                  │ RDS (HR DB) │    │ S3 (HR documents) │
                  │ KMS-encrypted│    │ private, SSE-KMS  │
                  │ Multi-AZ     │    │ versioning+Object │
                  │ no public    │    │ Lock + lifecycle  │
                  └─────────────┘    └───────────────────┘
                                       │
        CloudTrail (data events) + S3 access logs + GuardDuty + Config
                  └──────────► dedicated SECURITY/AUDIT account (immutable logs)
```

---

## 3. Identity & Access (RBAC)

### Roles (least privilege per persona)
| Persona | Can access | Cannot |
|---------|-----------|--------|
| **Employee** | Only their **own** records/documents | Anyone else's data |
| **Manager** | Their **direct reports** (limited fields) | Salaries outside team, other teams |
| **HR Staff** | HR data for their org/region | Cross-region data, key management |
| **HR Admin** | Configure HRMS, broad HR data | Disable logging, manage KMS keys |
| **Security/Audit** | Read-only logs & config | Read employee PII content |
| **Break-glass admin** | Everything (emergency only) | — (alarmed + MFA + reviewed) |

### Enforce "own data only" (prefix/row scoping)
- **S3 documents:** key scheme `employees/{empId}/...`; access only the caller's `empId` (app-enforced + policy condition).
- **Database:** row-level authorization in the app keyed to the authenticated user/role; never trust client-supplied IDs.
- **MFA required** for all HR/admin roles via `aws:MultiFactorAuthPresent` condition.

### Example: S3 policy scoping HR staff to their region's prefix
```json
{ "Version":"2012-10-17","Statement":[{
  "Effect":"Allow",
  "Action":["s3:GetObject","s3:PutObject"],
  "Resource":"arn:aws:s3:::acme-hrms/region/IN/employees/*",
  "Condition":{"Bool":{"aws:MultiFactorAuthPresent":"true"},
               "Bool":{"aws:SecureTransport":"true"}}
}]}
```

---

## 4. Data Protection

### Encryption (dedicated HR KMS key)
- **S3 documents:** SSE-KMS with a **dedicated `hrms-key` CMK**.
- **RDS:** encryption enabled with the same/related CMK; **TLS** for DB connections.
- **Key policy** restricts `kms:Decrypt` to **only** HR app roles + break-glass; every decrypt is logged in CloudTrail → you can prove who read what.
- **Key rotation** enabled; separate keys per environment (prod/dev) and per data class if needed.

```json
// hrms-key key policy (excerpt): only HR app role can decrypt
{ "Sid":"AllowHRAppDecrypt","Effect":"Allow",
  "Principal":{"AWS":"arn:aws:iam::123:role/hrms-app-role"},
  "Action":["kms:Decrypt","kms:GenerateDataKey"],
  "Resource":"*",
  "Condition":{"StringEquals":{"kms:ViaService":"s3.ap-south-1.amazonaws.com"}} }
```

### Secrets
- **DB credentials, JWT signing keys, integration API keys** → **Secrets Manager** with **auto-rotation**; fetched at runtime via the app role. **Nothing hardcoded.**

### Document storage controls (S3)
- Block Public Access ON; ACLs disabled; **versioning + Object Lock** for retention/immutability.
- **Lifecycle**: e.g., move terminated-employee payslips to Glacier after 1 year; **purge per legal retention** (e.g., 7 years) automatically.
- **Pre-signed URLs** (short expiry, per-object) for downloads — bucket never public.

---

## 5. Network
- App tier in **private subnets**; **RDS in isolated subnets**, **not publicly accessible**.
- **WAF** on the public ALB (OWASP rules, rate limiting); **Shield** for DDoS.
- Security groups: ALB→app, app→RDS (SG-to-SG on 3306/5432 only).
- **VPC endpoints** for S3/Secrets Manager/KMS so traffic stays off the public internet.
- **IMDSv2 required** on any EC2.

---

## 6. Audit & Compliance (prove it)
- **CloudTrail data events** on the HR S3 bucket + KMS → record every object read and key decrypt (who/when/what).
- **S3 server access logging**; **VPC Flow Logs**.
- Logs shipped to the **separate security/audit account** (immutable, Object Lock) so even an HR admin can't tamper.
- **AWS Config** conformance pack mapped to your framework; **Security Hub** standards; **Macie** to confirm no PII leaks to wrong buckets.
- **Access reviews** quarterly (Access Analyzer unused access); **data subject access/erasure** workflow for GDPR.

### Retention & data minimization
```
[ ] Collect only necessary fields (data minimization)
[ ] Mask sensitive fields in UI/logs (no PII in application logs)
[ ] Retention rules enforced via S3 Object Lock + lifecycle + DB purge jobs
[ ] Right-to-erasure process (locate + delete across S3/DB/backups within policy)
```

---

## 7. Threats → Controls (HRMS-specific)
| Threat | Control |
|--------|---------|
| Insider HR admin snoops salaries | RBAC least privilege + KMS decrypt audit + alerts on bulk reads |
| Employee accesses others' records | Prefix/row scoping + server-side authZ (never trust client IDs) |
| Leaked DB creds | Secrets Manager + rotation + role-based fetch |
| Public S3 exposure of documents | BPA on + Access Analyzer + Config + pre-signed URLs |
| Ransomware/deletion | Versioning + Object Lock + immutable cross-account backups |
| Admin disables logs to hide activity | Logs in separate account + SCP deny StopLogging + alarms |
| PII in app logs | Field masking + log scrubbing + Macie checks |
| Compliance/audit failure | Audit Manager evidence + CloudTrail + retention enforcement |

---

## 8. HRMS Security Checklist
```
IDENTITY
[ ] SSO + MFA for all HR/admin users; app uses least-priv role
[ ] RBAC: employee=own, manager=reports, HR=scoped, audit=read-only logs
[ ] Server-side authorization (no client-trusted IDs); break-glass alarmed

DATA
[ ] Dedicated HR KMS CMK; kms:Decrypt restricted + audited; rotation on
[ ] S3 docs: private, SSE-KMS, versioning, Object Lock, lifecycle/retention
[ ] RDS encrypted, Multi-AZ, private, TLS; secrets in Secrets Manager (rotating)
[ ] No PII in logs; field masking; data minimization

NETWORK
[ ] App private subnet; RDS isolated, not public; SG-to-SG; WAF+Shield; IMDSv2; VPC endpoints

AUDIT/COMPLIANCE
[ ] CloudTrail data events (S3+KMS) → separate audit account (immutable)
[ ] Config + Security Hub + Macie; quarterly access reviews
[ ] Retention + right-to-erasure workflows; framework mapping (GDPR/ISO/SOC2)

RESPONSE
[ ] IR playbook for PII breach (notify obligations, containment, forensics)
[ ] Backups encrypted, immutable, cross-account, restore-tested
```

💡 **The HRMS test:** for any sensitive record you should be able to answer, with evidence, **"who can access this, who actually accessed it, was it encrypted, and how long do we keep it?"** If you can answer all four, the design is sound.

➡️ Next: [07-troubleshooting.md](07-troubleshooting.md)

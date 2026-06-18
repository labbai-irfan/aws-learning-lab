# Module 11 — Security Architecture

> Zero Trust, defense in depth, CSPM, IAM design, encryption everywhere, and the layered security model for enterprise AWS.

---

## 1. Defense in depth — the layers

```
   ┌─── EDGE           ───── CloudFront + WAF + Shield + Route 53 health
   ├─── NETWORK        ───── VPC + private subnets + NACLs + SGs + TGW
   ├─── IDENTITY       ───── IAM (least privilege) + SCPs + Cognito + SSO
   ├─── DATA           ───── KMS encryption at rest + TLS in transit + Macie
   ├─── WORKLOAD       ───── Hardened AMIs + Inspector + ECR image scanning
   ├─── DETECTION      ───── GuardDuty + Security Hub + Config + CloudTrail
   └─── RESPONSE       ───── Incident Manager + Lambda remediation + runbooks
```

If an attacker breaches one layer, they hit another. No single point of failure.

---

## 2. Zero Trust principles on AWS

Traditional: trust anything inside the VPC. Zero Trust: **never trust, always verify**.

| Principle | AWS implementation |
|---|---|
| Verify identity | IAM roles with conditions + Cognito/Identity Center |
| Least privilege | Specific IAM actions; no `*`; no `AdministratorAccess` |
| Assume breach | GuardDuty + Security Hub + incident response automation |
| Verify explicitly | Resource policies check caller identity + conditions |
| Micro-segmentation | SGs reference other SGs; NACLs per tier; App Mesh mTLS |
| Encrypt everything | KMS at rest; TLS in transit; private endpoints |

---

## 3. IAM design at scale

### Role hierarchy
```
   Human identity: AWS IAM Identity Center (SSO) → permission sets → account roles
   Service identity: EC2/ECS/Lambda instance roles → specific policy per workload
   CI/CD: OIDC federation (GitHub Actions / GitLab) → assume role, no static keys
   Cross-account: trust policies with external ID condition
```

### Least-privilege policy design
```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::hrms-assets-prod/*",
  "Condition": {
    "StringEquals": { "aws:RequestedRegion": "us-east-1" },
    "Bool": { "aws:SecureTransport": "true" }
  }
}
```
Never: `"Action": "*"`, `"Resource": "*"`, attaching `AdministratorAccess` to workload roles.

### IAM Access Analyzer
- Scans for **unintended resource exposure** (S3 buckets, KMS keys, SQS queues accessible outside the account/Org).
- Run findings through Security Hub.

### Permission boundaries
Limit the maximum permissions a role can grant others — essential for self-service accounts where teams can create their own roles:
```json
// Boundary: team can grant any S3 action but never IAM admin
{ "Effect": "Allow", "Action": "s3:*", "Resource": "*" }
{ "Effect": "Deny", "Action": "iam:*", "Resource": "*" }
```

---

## 4. Encryption architecture

### Encryption at rest
- **KMS Customer Managed Keys (CMK)**: per-service, per-account key policy control.
- **Key hierarchy**: separate CMKs for S3, RDS, EBS, Secrets Manager, CloudWatch Logs.
- **Key rotation**: automatic annual rotation on CMKs.
- **Cross-account**: share CMK via key policy to decrypt in another account (e.g. Log Archive).

### Encryption in transit
- **TLS everywhere**: ACM certs on ALB/CloudFront; RDS `require_secure_transport`; internal mTLS via App Mesh.
- **VPC endpoints (PrivateLink)**: S3, DynamoDB, SQS, SNS, KMS, ECR — traffic stays in VPC, no internet.
- **S3 bucket policies**: deny non-TLS requests `"Condition": {"Bool": {"aws:SecureTransport":"false"}}`.

### Secrets management
```
   Secrets Manager → auto-rotation (Lambda) → app fetches at runtime
   SSM Parameter Store (SecureString) → for config with KMS encryption
   NEVER: environment variables with plaintext secrets
   NEVER: hardcoded credentials in code/IaC
```

---

## 5. Detection services

| Service | What it detects |
|---|---|
| **GuardDuty** | Threat intelligence: crypto mining, unusual API calls, compromised credentials, port scanning, malware in S3 |
| **Security Hub** | Aggregates findings from GuardDuty, Inspector, Config, Macie, IAM AA |
| **AWS Config** | Config drift; non-compliant resources (S3 public, unencrypted EBS, open SG port 22 to 0.0.0.0) |
| **CloudTrail** | All API calls (who did what, when, from where) |
| **Macie** | PII/PHI in S3 (credit cards, SSNs, keys) |
| **Inspector** | CVEs in EC2/Lambda/container images |
| **VPC Flow Logs** | Network-level: unexpected traffic, DDoS patterns |
| **IAM Access Analyzer** | Unintended cross-account access |

---

## 6. Automated response (Security as Code)

```
   GuardDuty: CryptoCurrency:EC2/BitcoinTool finding
        │
        ▼ EventBridge rule
        │
        ├── Lambda: isolate instance (remove from SG, attach quarantine SG)
        ├── Lambda: take forensic snapshot of EBS
        ├── SNS: page security team
        └── Incident Manager: create incident record
```

Config rule auto-remediation:
```
   AWS Config rule: S3_BUCKET_PUBLIC_READ_PROHIBITED
   → Auto-remediation: SSM Automation → put-public-access-block
   → SNS notification: "Auto-remediated: blocked public access on bucket hrms-logs"
```

---

## 7. CSPM (Cloud Security Posture Management)

Use **Security Hub** with **AWS Foundational Security Standard** or **CIS AWS Benchmark** to get a scored posture dashboard. Integrate with:
- **AWS Config** (Config rules → Security Hub findings).
- **3rd party CSPM** (Wiz, Orca, Prisma Cloud) for richer context.
- **Resource tagging** enforcement (Config rule: required tags missing → finding).

---

## 8. Compliance frameworks on AWS

| Framework | AWS tools |
|---|---|
| **SOC 2** | CloudTrail + Config + Security Hub controls |
| **PCI-DSS** | WAF + Shield Adv + GuardDuty + Macie + KMS + VPC isolation |
| **HIPAA** | BAA required + KMS + Macie + Config + CloudTrail |
| **ISO 27001** | Config + Security Hub + IAM + CloudTrail |
| **GDPR** | Macie (PII discovery) + data residency (region restriction SCP) + KMS |

---

## ✅ Security architecture checklist
- [ ] SCPs: deny disable-security-services, deny leave-org, deny unapproved regions
- [ ] GuardDuty enabled, aggregated to Security Hub
- [ ] CloudTrail: Org trail → Log Archive account (immutable S3 + CloudWatch Logs)
- [ ] Config: all regions + Org aggregator + CIS benchmark rules
- [ ] KMS CMKs per service; no `aws/s3` default key for production
- [ ] All secrets in Secrets Manager (rotating) — no env var secrets
- [ ] VPC endpoints for S3, KMS, SSM, ECR, SQS, SNS
- [ ] IAM Identity Center for human access (no IAM users in workload accounts)
- [ ] Automated response: quarantine, snapshot, notify on GuardDuty high findings
- [ ] Annual penetration test + quarterly vulnerability scan

➡️ Next: [Module 12 — DevOps Architecture](12-devops-architecture.md)

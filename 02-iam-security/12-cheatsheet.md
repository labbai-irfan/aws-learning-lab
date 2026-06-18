# 12 — IAM & Security Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-security-core-concepts.md).

## IAM identities
| Thing | One-liner |
|---|---|
| **Root user** | Account owner — MFA it, lock it away, no daily use |
| **IAM user** | Person/app with long-term credentials |
| **Group** | Attach policies to a set of users |
| **Role** | **Temporary** creds assumed by trusted principals (EC2, Lambda, cross-account) |
| **Instance profile** | Wraps a role for EC2 (no static keys) |

## Policy evaluation (memorize)
```
Explicit DENY  >  Explicit ALLOW  >  Implicit deny (default)
Effective = identity policy ∩ SCP ∩ permissions boundary  − explicit denies
```
- Policies = JSON: `Effect` + `Action` + `Resource` (+ `Condition`).
- Identity-based (on user/role) vs Resource-based (on bucket/key/queue).
- **Least privilege** — start minimal, add as needed.

## Advanced IAM
| Thing | Does |
|---|---|
| **STS / AssumeRole** | Issues temporary creds (cross-account, federation) |
| **Permissions boundary** | Caps the **max** perms an identity can have |
| **SCP (Organizations)** | Org/OU guardrail — limits, doesn't grant |
| **ABAC** | Authorize via tags on principals/resources |
| **Access Analyzer** | Finds externally-shared / unused access |
| **Identity Center (SSO)** | Central workforce access across accounts |

## Encryption & secrets
- **At rest** = KMS (CMK = your control: policy, rotation, audit). **In transit** = TLS.
- **Envelope encryption**: data key encrypts data; KMS key encrypts the data key.
- **Secrets Manager** = creds/API keys + **auto-rotation**. **SSM Parameter Store** SecureString = config + KMS.
- ⚠️ Never hard-code secrets; never put PII in logs.

## Network & edge
| | Security Group | NACL |
|---|---|---|
| Level | instance | subnet |
| State | stateful | stateless |
| Rules | allow only | allow + deny (ordered) |
- **WAF** = L7 (SQLi/XSS/bots, rate-limit) on CloudFront/ALB/API GW. **Shield** = DDoS (Std free, Adv paid).
- Private subnets for DBs; **VPC endpoints** keep AWS traffic off the internet; **SSM Session Manager** instead of open SSH.

## Detection & governance
| Service | Tells you |
|---|---|
| **CloudTrail** | Who did what (API audit) |
| **Config** | Resource config + compliance over time |
| **GuardDuty** | Threat detection (malicious/anomalous activity) |
| **Security Hub** | Aggregated findings + best-practice checks |
| **Inspector** | Vulnerabilities (EC2/ECR/Lambda) |
| **Macie** | Sensitive data (PII) in S3 |

## Exam triggers 💡
- "App on EC2 needs AWS access, no keys" → **IAM role / instance profile**.
- "Limit what a whole account/OU can do" → **SCP**. "Cap a delegated admin" → **permissions boundary**.
- "Cross-account access" → **role + AssumeRole** (+ ExternalId for 3rd parties).
- "Rotate DB password automatically" → **Secrets Manager**.
- "Who deleted the resource?" → **CloudTrail**. "Detect crypto-mining/recon" → **GuardDuty**.
- "Block a CIDR at subnet edge" → **NACL deny**. "Protect login from bots" → **WAF**.

## Gotchas ⚠️
- Explicit Deny always wins; SCPs don't grant, they cap.
- `"Action":"*","Resource":"*"` = admin — avoid.
- Enable encryption at creation (can't toggle on existing RDS/EBS easily — copy snapshot).
- Block Public Access ON; public buckets with private data = breach.

---
*Back to [IAM & Security README](README.md).*

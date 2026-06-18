# Module 2 — Real Attack Scenarios

> How real AWS breaches happen — so you can **prevent and detect** them. Each scenario: the attack, how it unfolds, the impact, **how to prevent it**, and **how to detect it**.

> ⚠️ **Defensive use only.** These describe attacker techniques at a conceptual level to harden accounts you own/are authorized to secure. No step-by-step exploitation is provided.

---

## 1. Leaked Access Keys in Source Code (the classic) 💥
**Attack:** A developer commits AWS access keys to a public GitHub repo. Bots scan GitHub continuously and find keys within **minutes**, then spin up expensive resources (crypto-mining EC2/GPU fleets) and exfiltrate data.

**Impact:** Huge bills (often $10k–$100k+), data theft, account takeover.

**Prevent 🔒**
- Use **IAM roles**, not long-lived access keys, for apps/EC2/Lambda.
- Never commit secrets; use **git-secrets**/pre-commit scanners and `.gitignore`.
- Store secrets in **Secrets Manager / Parameter Store**.
- Apply **SCPs** restricting Regions and expensive instance types.

**Detect 🔎**
- **GuardDuty** flags anomalous API usage / crypto-mining patterns.
- **CloudTrail** + CloudWatch alarms on sudden `RunInstances` spikes / new Regions.
- **AWS Health / Trusted Advisor** exposed-key notifications (AWS sometimes auto-quarantines).
- **Cost anomaly detection** + Budgets alerts.

**If it happens 🚨** → deactivate/delete the key immediately, rotate, review CloudTrail, terminate rogue resources, open AWS support. (Full steps in [Module 8 §1](08-incident-response-examples.md).)

---

## 2. Public S3 Bucket Data Leak 💥
**Attack:** A bucket (or object ACL) is misconfigured public; sensitive data (PII, backups, credentials) is indexed/scraped.

**Impact:** Data breach, regulatory fines (GDPR/HIPAA), reputational damage.

**Prevent 🔒**
- **Block Public Access** ON (account + bucket); **disable ACLs** (BucketOwnerEnforced).
- Least-privilege bucket policies; **deny non-TLS**; encrypt with KMS.
- Share via **pre-signed URLs / CloudFront OAC**, never public buckets. ([Phase 05 §4](../05-s3/04-security-guide.md))

**Detect 🔎**
- **IAM Access Analyzer for S3** flags public/shared buckets.
- **AWS Config** rule `s3-bucket-public-read-prohibited`.
- **Macie** discovers exposed PII; **Security Hub** aggregates findings.

---

## 3. Privilege Escalation via Over-Permissive IAM 💥
**Attack:** A low-privilege user/role has dangerous permissions (e.g., `iam:CreatePolicyVersion`, `iam:PassRole`, `iam:AttachUserPolicy`, `lambda:*`+`iam:PassRole`) and uses them to grant themselves admin.

**Impact:** Full account compromise from a "limited" foothold.

**Prevent 🔒**
- **Least privilege**; avoid wildcard `iam:*`, `*:*`.
- **Permission boundaries** to cap delegated principals.
- Restrict `iam:PassRole` to specific roles; review `NotAction`/wildcards.
- **SCPs** to deny risky IAM actions org-wide where not needed.

**Detect 🔎**
- **IAM Access Analyzer** (unused access + policy validation findings).
- **CloudTrail** alerts on IAM policy/role changes.
- Regular **Credential Report** + access reviews.

---

## 4. Stolen Credentials Without MFA 💥
**Attack:** Phishing or password reuse exposes a console password; without MFA the attacker logs in directly.

**Impact:** Account access, data theft, resource abuse.

**Prevent 🔒**
- **MFA everywhere** — root + all privileged users; FIDO keys resist phishing.
- Enforce MFA via policy condition (`aws:MultiFactorAuthPresent`).
- Move humans to **IAM Identity Center / federation** with MFA.

**Detect 🔎**
- CloudTrail `ConsoleLogin` events (especially from new IPs/Regions/`MFAUsed=No`).
- **GuardDuty** `UnauthorizedAccess`/anomalous-login findings.
- Alarms on root logins.

---

## 5. SSRF → EC2 Metadata Credential Theft (Capital One-style) 💥
**Attack:** A vulnerable web app is tricked (Server-Side Request Forgery) into reading the **EC2 instance metadata service (IMDS)** and stealing the instance role's temporary credentials, then accessing S3/other services.

**Impact:** Data exfiltration using the legitimate instance role.

**Prevent 🔒**
- **Enforce IMDSv2** (session-token required) — blocks most SSRF credential theft:
  ```bash
  aws ec2 modify-instance-metadata-options --instance-id i-123 \
    --http-tokens required --http-endpoint enabled
  ```
- Least-privilege **instance roles** (limit blast radius).
- Patch app SSRF flaws; egress filtering; WAF.

**Detect 🔎**
- **GuardDuty** `InstanceCredentialExfiltration` finding (role creds used from outside the instance/AWS).
- CloudTrail anomalies for the instance role.

---

## 6. Disabled Logging to Hide Tracks 💥
**Attack:** After gaining access, an attacker disables **CloudTrail/GuardDuty/Config** to operate undetected, or deletes log buckets.

**Impact:** No forensic trail; prolonged undetected compromise.

**Prevent 🔒**
- **SCPs** denying `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, `guardduty:Delete*`, `config:Delete*`.
- **Log file validation** + logs in a **separate, locked "security/audit" account** (Object Lock).
- Multi-account isolation so a compromised workload account can't touch central logs.

**Detect 🔎**
- CloudWatch alarm on `StopLogging`/`DeleteTrail` events.
- Security Hub control failures; Config drift detection.

---

## 7. Crypto-Mining via Compromised Compute 💥
**Attack:** Using stolen keys or an exposed service, attacker launches large/GPU EC2 across Regions to mine cryptocurrency.

**Impact:** Massive, fast-accumulating bills.

**Prevent 🔒**
- **SCPs** restricting Regions + instance families; service quotas kept low.
- Roles over keys; MFA; least privilege.
- **Budgets + anomaly detection** with auto-actions.

**Detect 🔎**
- **GuardDuty** crypto-mining/`CryptoCurrency` findings.
- Cost anomaly alerts; CloudTrail `RunInstances` spikes in unusual Regions.

---

## 8. Ransomware on S3 / Data Destruction 💥
**Attack:** With write/delete access, attacker encrypts or deletes data and demands ransom (or just destroys it).

**Impact:** Data loss, downtime, extortion.

**Prevent 🔒**
- **Versioning + S3 Object Lock (WORM) + MFA Delete**.
- **Cross-Region/Cross-account backups** (immutable, separate account).
- Least-privilege write/delete; deny `s3:DeleteObject*` broadly.

**Detect 🔎**
- GuardDuty anomalous deletion/exfiltration; CloudTrail mass-delete events; Config.

---

## 9. Cross-Account Confused Deputy 💥
**Attack:** A third party assumes a role you set up for them and accesses more than intended, or a misconfigured trust lets an attacker assume your role.

**Impact:** Unauthorized cross-account access.

**Prevent 🔒**
- Use **`sts:ExternalId`** and tight `Principal`/`Condition` in trust policies.
- Scope cross-account roles to least privilege; review trust policies.

**Detect 🔎**
- CloudTrail `AssumeRole` from unexpected accounts; Access Analyzer external-access findings.

---

## 10. Hardcoded Secrets in Containers / Lambda Env 💥
**Attack:** Secrets baked into container images, Lambda env vars (plaintext), or AMIs are extracted by anyone with read access.

**Impact:** Credential leakage and lateral movement.

**Prevent 🔒**
- **Secrets Manager/Parameter Store** fetched at runtime via role.
- Encrypt Lambda env vars with **KMS**; scan images for secrets.

**Detect 🔎**
- Secret scanners in CI/CD; CloudTrail on secret access; Macie/Inspector.

---

## Attack → Defense Summary
```
Leaked keys        → roles not keys + secret scanning + GuardDuty
Public S3          → Block Public Access + Access Analyzer + Config
Priv-esc IAM       → least privilege + boundaries + PassRole limits
No-MFA login       → MFA everywhere + IdC + login alarms
SSRF metadata      → IMDSv2 required + least-priv instance role + GuardDuty
Logging disabled   → SCP protect logs + separate audit account + alarms
Crypto-mining      → SCP Region/type limits + budgets + GuardDuty
Ransomware         → versioning + Object Lock + immutable backups
Confused deputy    → ExternalId + tight trust policy + Access Analyzer
Hardcoded secrets  → Secrets Manager + KMS + CI secret scanning
```

💡 **Pattern:** Almost every breach traces back to a missing fundamental — **least privilege, roles-not-keys, MFA, encryption, or logging.** Get those right and most attacks fail or get caught.

➡️ Next: [03-security-audits.md](03-security-audits.md)

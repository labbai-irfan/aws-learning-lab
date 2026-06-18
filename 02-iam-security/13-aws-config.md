# 13 — AWS Config (Configuration Compliance & Governance) — Breadth Top-Up

> CloudTrail tells you *who did what*; **AWS Config** tells you *what the configuration is now, what it was, and whether it's compliant* — and can **auto-remediate** drift. A key **DevOps Pro / SysOps / Security** governance service.

**By the end you can:** explain Config's recorder, rules, conformance packs, remediation, and aggregators — and how they differ from CloudTrail.

---

## 1. What AWS Config does
```
Config Recorder → captures resource configuration + every change over time
      │
      ├── Configuration history & timeline ("what did this SG look like last Tuesday?")
      ├── Config Rules → evaluate resources for COMPLIANT / NON_COMPLIANT
      ├── Conformance Packs → a bundle of rules + remediation as one deployable unit
      └── Remediation → auto-fix non-compliant resources (via SSM Automation)
```

## 2. Core concepts
| Concept | What it is |
|---|---|
| **Configuration item** | A point-in-time snapshot of a resource's config |
| **Configuration recorder** | Records items + changes for selected resource types |
| **Config rule** | Desired-state check — **managed** (AWS-provided) or **custom** (Lambda/Guard) |
| **Conformance pack** | A packaged set of rules + remediations (e.g., a CIS/PCI baseline) |
| **Remediation action** | An SSM Automation runbook that fixes a violation (manual or **automatic**) |
| **Aggregator** | Combines Config data across **multiple accounts/Regions** |

## 3. Example rules (managed)
- `s3-bucket-public-read-prohibited` — flag public buckets.
- `iam-user-mfa-enabled` — users must have MFA.
- `encrypted-volumes` — EBS volumes must be encrypted.
- `rds-instance-public-access-check` — RDS must not be public.
- `restricted-ssh` — no `0.0.0.0/0` on port 22.

## 4. Auto-remediation
```
Non-compliant resource  →  Config rule fires  →  Remediation (SSM Automation)
   e.g., public S3 bucket → automatically re-enable Block Public Access
   e.g., unencrypted volume → tag + notify, or trigger an encryption workflow
```
You can also route findings via **EventBridge → Lambda/SNS** for custom response. This is the "self-healing compliance" pattern the DevOps Pro exam loves.

## 5. Config vs CloudTrail vs CloudWatch (don't confuse them)
| Service | Answers |
|---|---|
| **CloudTrail** | *Who made the API call?* (audit trail) |
| **AWS Config** | *What is the resource's configuration & is it compliant?* (state + history) |
| **CloudWatch** | *Is it healthy / performing?* (metrics, logs, alarms) |

## 6. Multi-account governance
- **Aggregators** + **Organizations** give an org-wide compliance dashboard.
- Deploy **conformance packs** across all accounts via Config + Organizations / StackSets.
- Pairs with **Security Hub** (which consumes Config findings) for a unified posture view.

## 7. Exam triggers 💡
- "Continuously check resources against compliance rules" → **AWS Config rules**.
- "Automatically fix a misconfiguration (e.g., public bucket)" → **Config remediation (SSM Automation)**.
- "Track how a security group changed over time" → **Config configuration history**.
- "Apply a compliance baseline across all accounts" → **conformance packs + aggregator**.
- "Who deleted the bucket?" → **CloudTrail** (not Config).

## 8. Gotchas ⚠️
- Config records only the resource **types you enable** (and costs per item recorded).
- Config evaluates **state**; it doesn't tell you *who* changed it (that's CloudTrail) — use both.
- Remediation needs an SSM Automation document + an IAM role with permission to fix the resource.

---
*Back to [IAM & Security README](README.md). Related: [03 Security Audits](03-security-audits.md) · [Phase 09 — Systems Manager](../09-cloudwatch/17-systems-manager.md) (remediation engine).*

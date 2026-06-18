# Project — Secure Account Baseline (Hardening Capstone)

> Capstone: take a fresh/messy AWS account and bring it to a **production security baseline** — locked-down root, least-privilege access, encryption, secrets management, detection, and verified compliance. This is the deliverable an auditor would sign off on.

**Prerequisites:** an AWS account, AWS CLI v2 (as an admin IAM user, not root). This project executes and verifies the [11 Labs](../11-labs.md) as one coherent baseline; read [01 Core Concepts](../01-security-core-concepts.md) + [05 Production Security Checklist](../05-production-security-checklist.md) first.

---

## Target architecture (controls)
```
PREVENTIVE                 DETECTIVE                 DATA PROTECTION
─ Root MFA + no keys       ─ CloudTrail (locked)     ─ KMS CMKs (rotated)
─ Least-privilege IAM      ─ AWS Config + rules      ─ Secrets Manager (rotation)
─ SG/NACL, private subnets ─ GuardDuty               ─ S3 Block Public Access + SSE-KMS
─ SCP guardrails           ─ Security Hub            ─ TLS everywhere
─ Permissions boundaries   ─ Access Analyzer         ─ RDS encryption
```

## Build steps
1. **Lock the root** — MFA on, remove root access keys, strong account password policy ([Lab 1](../11-labs.md#lab-1--lock-down-the-account-root--baseline)).
2. **Least-privilege identities** — groups + scoped policies; an EC2 **role** (no static keys); cross-account via **AssumeRole**; **permissions boundaries** + an **SCP** ([Labs 2–5](../11-labs.md)).
3. **Encryption & secrets** — a KMS CMK with rotation; HRMS DB creds in **Secrets Manager** with rotation ([Labs 6–7](../11-labs.md)).
4. **Detection** — CloudTrail to a locked bucket, **AWS Config** + rules ([13](../13-aws-config.md)), **GuardDuty**, Security Hub ([Lab 8](../11-labs.md)).
5. **Data protection** — S3 Block Public Access + default SSE-KMS + least-privilege bucket policy ([Lab 9](../11-labs.md)).
6. **Verify & drill** — IAM **Access Analyzer** for external exposure; run the **leaked-key incident drill** ([Lab 10](../11-labs.md)).

## Acceptance checklist ✅ (the "auditor sign-off")
- [ ] Root has MFA and **no access keys**; password policy enforced.
- [ ] No human/app uses long-lived keys where a **role** would do.
- [ ] Every policy is least-privilege (no `Action:* / Resource:*`); boundaries/SCP in place.
- [ ] All data encrypted at rest (KMS) and in transit (TLS); secrets in Secrets Manager.
- [ ] S3 Block Public Access ON account-wide; no public buckets with private data.
- [ ] CloudTrail, Config (with rules), GuardDuty, Security Hub all **enabled**.
- [ ] Access Analyzer shows **no unintended external access**.
- [ ] You can contain a leaked key (deactivate → rotate → investigate via CloudTrail) in minutes.

## HRMS application of this baseline
Apply it to the HRMS account: scoped roles for the app/CI, KMS for employee-PII at rest, Secrets Manager for the RDS password, WAF on the login page ([Phase 13](../../13-advanced-aws/06-waf-shield.md)), and Config rules to keep it compliant. See [06 HRMS Security Design](../06-hrms-security-design.md).

## Cleanup 💰
Remove lab users/roles/policies, schedule KMS key deletion, delete test secrets/buckets/analyzer. Leave detective services on if this is a real account you'll keep.

---
*Back to [IAM & Security README](../README.md).*

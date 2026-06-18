# Phase 02 — IAM & Security Complete Learning Repository

> A hands-on, defense-focused course on **AWS Security** — IAM, identities, policies, MFA, permission boundaries, SCPs, Secrets Manager, KMS, and the practices that keep real workloads safe. Includes real attack scenarios, audits, least-privilege patterns, a production checklist, an HRMS security design, troubleshooting, and incident-response playbooks.

Authored as a structured program by an **AWS Security Architect**. Builds on [Phase 01 — AWS Fundamentals](../01-aws-fundamentals/README.md), [Phase 03 — EC2](../03-ec2/README.md), and [Phase 05 — S3](../05-s3/README.md). Every module has explanations, diagrams, real policies/commands, and practice questions.

---

## 🎯 Who This Is For
- Anyone who finished earlier phases and wants to secure their AWS workloads.
- Developers/DevOps responsible for IAM, secrets, and encryption.
- Candidates preparing for **AWS Security Specialty / Solutions Architect** and security-engineer interviews.

**Prerequisites:** An AWS account with MFA + a billing budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Comfort with the AWS console/CLI.

> ⚠️ **Ethics & scope:** This repo is for **defensive security** — protecting accounts you own/are authorized to test. The "attack scenarios" explain how breaches happen so you can prevent and detect them; they are not instructions to attack systems you don't own.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | Security Core Concepts (all topics) | [01-security-core-concepts.md](01-security-core-concepts.md) | 4 hrs |
| 2 | Real Attack Scenarios | [02-real-attack-scenarios.md](02-real-attack-scenarios.md) | 1.5 hrs |
| 3 | Security Audits | [03-security-audits.md](03-security-audits.md) | 1.5 hrs |
| 4 | Least Privilege Examples | [04-least-privilege-examples.md](04-least-privilege-examples.md) | 1.5 hrs |
| 5 | Production Security Checklist | [05-production-security-checklist.md](05-production-security-checklist.md) | 1 hr |
| 6 | HRMS Security Design | [06-hrms-security-design.md](06-hrms-security-design.md) | 1.5 hrs |
| 7 | Troubleshooting | [07-troubleshooting.md](07-troubleshooting.md) | 1 hr |
| 8 | Incident Response Examples | [08-incident-response-examples.md](08-incident-response-examples.md) | 1.5 hrs |
| 9 | 100 Interview Questions | [09-100-interview-questions.md](09-100-interview-questions.md) | 2 hrs |
| 10 | 100 MCQs | [10-100-mcqs.md](10-100-mcqs.md) | 2 hrs |
| 11 | Hands-On Labs (IAM, KMS, Secrets, detectors) | [11-labs.md](11-labs.md) | 4 hrs |

**Total:** ~22 hours.

---

## 📚 Topics Covered

**Core building blocks** (Module 1)
- IAM · Users · Groups · Roles · Policies · MFA · Permission Boundaries · SCP · Secrets Manager · KMS · Security Best Practices

**Applied security**
- Real Attack Scenarios (Module 2) · Security Audits (Module 3) · Least Privilege Examples (Module 4) · Production Security Checklist (Module 5) · HRMS Security Design (Module 6) · Troubleshooting (Module 7) · Incident Response (Module 8)

**Practice**
- 100 interview questions (Module 9)

---

## ⚡ AWS Security Mental Model (60-second overview)

```
                       WHO can do WHAT, on WHICH resource, under WHAT conditions?
                                            │
        ┌───────────────────────────────────┼───────────────────────────────────┐
     IDENTITY (who)                   PERMISSIONS (what)                  GUARDRAILS (limits)
        │                                   │                                   │
   Root user (lock away)            Identity policies (on users/roles)     SCPs (org-wide max)
   IAM Users (humans)               Resource policies (on S3/KMS/...)      Permission Boundaries
   IAM Groups (collections)         Managed vs inline policies             (max for a principal)
   IAM Roles (temp creds, services) Allow/Deny + Conditions                 IAM Access Analyzer
   Federation / Identity Center
        │
        ▼
   PROTECT DATA            DETECT & RESPOND
   KMS (encryption keys)   CloudTrail (audit log)
   Secrets Manager (creds) GuardDuty / Config / Security Hub
   MFA (extra factor)      Incident response playbooks
```

**In words:** AWS security is about controlling **who** (identities) can do **what** (permissions) on **which** resources, bounded by **guardrails** (SCPs, permission boundaries), protecting **data** (KMS, Secrets Manager, MFA), and **detecting/responding** to threats (CloudTrail, GuardDuty, IR playbooks). The golden rule everywhere: **least privilege**.

---

## 🔑 One Line per Topic

| Topic | One-liner |
|-------|-----------|
| **IAM** | The service that controls authentication & authorization in AWS |
| **Users** | Long-lived identities for humans/legacy apps (avoid for apps) |
| **Groups** | Collections of users that share permissions |
| **Roles** | Temporary, assumable identities — the secure default for apps/services/cross-account |
| **Policies** | JSON documents that allow/deny actions (identity- or resource-based) |
| **MFA** | A second authentication factor; mandatory on root and privileged users |
| **Permission Boundaries** | The *maximum* permissions an IAM principal can have |
| **SCP** | Org-wide guardrails capping what accounts/OUs can do |
| **Secrets Manager** | Stores/rotates secrets (DB passwords, API keys) — never hardcode |
| **KMS** | Manages encryption keys for data at rest, with audit + access control |
| **Best Practices** | Least privilege, MFA, no root daily, encrypt everything, log everything |

---

## 🛡️ The 8 Security Pillars (memorize)
```
1. Identity     → least-privilege IAM, roles over keys, MFA everywhere
2. Detection    → CloudTrail, GuardDuty, Config, Security Hub, alarms
3. Infra prot.  → Security Groups, network segmentation, patching
4. Data prot.   → KMS encryption, Secrets Manager, TLS, backups
5. Guardrails   → SCPs, permission boundaries, Block Public Access
6. Audit        → IAM Access Analyzer, Credential Report, log review
7. Response     → IR playbooks, contain → eradicate → recover
8. Governance   → tagging, account separation, automation (IaC)
```

---

## 📌 Conventions
- 🛠️ = run this · 🔒 = security control · ⚠️ = risk/gotcha · 💡 = tip · 🚨 = incident step

---

## 📖 Official References
- IAM docs: https://docs.aws.amazon.com/iam/
- Security best practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- KMS: https://docs.aws.amazon.com/kms/ · Secrets Manager: https://docs.aws.amazon.com/secretsmanager/
- AWS Security Incident Response Guide: https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/

---

*Start with [01-security-core-concepts.md](01-security-core-concepts.md).* 🚀

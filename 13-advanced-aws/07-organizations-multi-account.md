# Module 7 — Organizations & Multi-Account Strategy

> Why multiple accounts, how to structure them, SCPs, Control Tower, account vending, and the landing zone blueprint.

---

## 1. Why multiple accounts (not just VPCs)

| Risk | Single account | Multiple accounts |
|---|---|---|
| Blast radius | One misconfiguration affects everything | Isolated — prod can't be affected by dev mistake |
| IAM complexity | Hundreds of roles, hard to scope | Smaller trust domains per account |
| Billing visibility | Tag-based (unreliable) | **Native per-account cost allocation** |
| Compliance | All environments share audit trail | Separate accounts = separate compliance boundaries |
| Service limits | Shared across all workloads | Independent quotas per account |

**The rule:** environments and security domains that must not affect each other get separate accounts. Environments that can are in the same account.

---

## 2. AWS Organizations

**AWS Organizations** is the management layer over multiple accounts:
- **Management account** (root / payer) — owns billing, creates accounts, applies policies.
- **Member accounts** — workload accounts.
- **Organizational Units (OUs)** — group accounts to apply policies hierarchically.

```
   Root
     ├── OU: Security
     │     ├── Account: Log Archive
     │     └── Account: Security Tooling
     ├── OU: Infrastructure
     │     ├── Account: Network Hub
     │     └── Account: Shared Services (DNS, ECR, artifacts)
     ├── OU: Workloads
     │     ├── OU: HRMS
     │     │     ├── Account: HRMS-Prod
     │     │     ├── Account: HRMS-Staging
     │     │     └── Account: HRMS-Dev
     │     └── OU: Finance-App
     └── OU: Sandbox
           └── Account: Developer sandboxes
```

---

## 3. Service Control Policies (SCPs)

**SCPs** are guardrails — they **restrict** what IAM principals in member accounts can do, even if their IAM role says Allow. They do **not grant** permissions.

```json
// Deny leaving the organization and deny disabling GuardDuty
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Deny", "Action": ["organizations:LeaveOrganization"], "Resource": "*" },
    { "Effect": "Deny", "Action": [
        "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount",
        "cloudtrail:DeleteTrail", "cloudtrail:StopLogging"
      ], "Resource": "*" },
    { "Effect": "Deny", "Action": "*", "Resource": "*",
      "Condition": { "StringNotEquals": { "aws:RequestedRegion": ["us-east-1","eu-west-1"] } } }
  ]
}
```

**Effective permission** = (Org SCP) AND (IAM policy). If either denies, the action is denied.

Common SCPs:
- **Deny region usage** outside approved regions.
- **Deny disabling security services** (GuardDuty, CloudTrail, Config, SecurityHub).
- **Deny root account usage** (except in management account).
- **Require encryption** on S3 and EBS.
- **Restrict large instance types** in dev/sandbox.
- **Deny leaving the organization**.

---

## 4. Control Tower — managed landing zone

**AWS Control Tower** automates the landing zone setup:
- Creates the multi-account structure, security accounts, log archive, and SCP baselines.
- **Guardrails** = pre-built SCPs + Config rules (preventive + detective).
- **Account Factory** — vending new accounts via Service Catalog (approved templates).
- **Account Factory for Terraform (AFT)** — account vending via Terraform pipelines.

Use Control Tower when: you're starting a new multi-account setup, or you want AWS-managed guardrail management. Customise with **Control Tower Customizations (CfCT)**.

---

## 5. The landing zone accounts (minimum)

| Account | Purpose |
|---|---|
| **Management** | Org management, billing, SCPs only (no workloads) |
| **Log Archive** | Read-only store for CloudTrail, Config snapshots, VPC flow logs from all accounts |
| **Security Tooling** | GuardDuty aggregator, Security Hub, IAM Access Analyzer, audit tooling |
| **Network Hub** | Transit Gateway, Direct Connect, Route 53 Resolver, shared VPC |
| **Shared Services** | ECR registry, internal DNS, Secrets Manager for shared secrets, Nexus/Artifactory |
| **Workload-Prod** | Each application's production account |
| **Workload-NonProd** | Staging + dev (or separated) |
| **Sandbox** | Developer experimentation — time-limited, automatically cleaned |

---

## 6. Account vending

**Never create accounts manually.** Automate it:
1. Developer/team fills a **Service Catalog** form (account name, OU, budget, owners).
2. Pipeline creates the account via `Organizations::CreateAccount`.
3. Applies **baseline CloudFormation StackSet** (VPC, logging, security baselines, IAM roles for CI/CD).
4. Configures GuardDuty delegation, Security Hub enrollment.
5. Notifies the owner.

This ensures every account is born with guardrails — no manual, partial setups.

---

## 7. Cross-account access patterns

### Assume role (the standard pattern)
```
   App in HRMS-Prod ──assumes──► arn:aws:iam::LOG-ACCT:role/ReadOnlyLogs
   Central pipeline  ──assumes──► arn:aws:iam::HRMS-PROD:role/DeployRole
```
- Trust policy on the target role allows the source account/role to assume it.
- No long-lived credentials cross account boundaries.

### AWS RAM (Resource Access Manager)
Share resources across accounts without copying: VPC subnets, Transit Gateway, ECR, Route 53 Resolver rules, License Manager configurations.

### Consolidated billing
All member accounts roll up to the management account payer. Use **Cost Explorer** with account grouping; set **Budget alerts** per account and per OU.

---

## 8. Governance & compliance
- **AWS Config** — aggregator in Security Tooling account sees Config events from all accounts.
- **GuardDuty** — management account is delegated admin; findings aggregated.
- **Security Hub** — cross-account findings from GuardDuty, Inspector, Config, Macie.
- **CloudTrail** — Org trail writes all API calls from all accounts to the Log Archive bucket.
- **IAM Access Analyzer** — org-level findings for cross-account resource exposure.

---

## ✅ Multi-account checklist
- [ ] Management account has **zero workloads** (only Org management)
- [ ] Log Archive account with immutable CloudTrail
- [ ] Security Tooling with GuardDuty + Security Hub aggregators
- [ ] SCPs: deny leaving Org, deny disabling security services, deny unapproved regions
- [ ] Account vending automated (Control Tower / AFT)
- [ ] Cross-account access via role assumption only (no static keys)
- [ ] Org CloudTrail → Log Archive S3
- [ ] Budget alerts per account

➡️ Next: [Module 8 — Enterprise Architecture](08-enterprise-architecture.md)

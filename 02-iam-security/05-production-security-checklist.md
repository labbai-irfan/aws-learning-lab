# Module 5 — Production Security Checklist

> A comprehensive, copy-into-your-runbook checklist for securing a production AWS environment. Organized by domain. Treat each `[ ]` as a control to verify and evidence.

---

## 0. Account Foundation
```
[ ] Root user: MFA enabled (hardware/FIDO preferred), no access keys, not used daily
[ ] Root contact + alternate contacts (security/billing/operations) set
[ ] Separate AWS accounts via Organizations: prod / dev / staging / security(audit) / logging
[ ] Consolidated billing + budgets + cost anomaly detection
[ ] Region strategy defined; unused Regions restricted via SCP
```

## 1. Identity & Access Management 🔒
```
[ ] Humans use IAM Identity Center (SSO)/federation — not individual IAM users
[ ] All applications/services use IAM ROLES (no long-lived access keys)
[ ] MFA enforced for all privileged identities (+ condition keys for sensitive actions)
[ ] Permissions granted via GROUPS / reusable customer-managed policies
[ ] Least privilege everywhere; no "*:*" except true break-glass admin
[ ] iam:PassRole scoped to specific roles + services
[ ] Permission boundaries on any delegated IAM-creating principals
[ ] Access keys (if unavoidable) rotated <90 days; unused keys/users/roles removed
[ ] Break-glass admin role: tightly controlled, MFA, alarmed on use
```

## 2. Organization Guardrails (SCPs)
```
[ ] Deny disabling CloudTrail / GuardDuty / Config
[ ] Deny leaving the organization
[ ] Restrict to approved Regions
[ ] Deny root user actions in member accounts (where feasible)
[ ] Enforce encryption / deny public S3 at org level where possible
[ ] Protect security/logging account resources
```

## 3. Data Protection 🔒
```
[ ] Encryption at rest: S3 (SSE-KMS for sensitive), EBS, RDS, DynamoDB, snapshots
[ ] Customer-managed KMS keys for sensitive data; key policies least-privilege
[ ] KMS key rotation enabled; kms:Decrypt limited to required roles
[ ] TLS enforced in transit (deny aws:SecureTransport=false on buckets/APIs)
[ ] Secrets in Secrets Manager / Parameter Store (SecureString); auto-rotation on
[ ] NO secrets in code, env files, AMIs, container images, or Lambda plaintext env
[ ] S3 Block Public Access ON (account + buckets); ACLs disabled
[ ] Data classification + tagging (PII/Confidential/Public)
```

## 4. Network Security 🔒
```
[ ] No 0.0.0.0/0 on SSH(22)/RDP(3389)/DB(3306/5432) — restrict to IP/VPN/SSM
[ ] Use SSM Session Manager instead of open SSH where possible
[ ] Tiered subnets: public (LB) / private (app) / isolated (db); DBs in private subnets
[ ] Security groups least-privilege; reference SG-to-SG, not wide CIDRs
[ ] NACLs as coarse subnet guardrails; VPC Flow Logs enabled
[ ] WAF on public ALB/CloudFront/API Gateway; Shield (Advanced if needed) for DDoS
[ ] IMDSv2 REQUIRED on all EC2 (http-tokens=required)
[ ] VPC endpoints for AWS service traffic (avoid public egress where possible)
```

## 5. Compute & Application
```
[ ] OS/runtime patching (SSM Patch Manager / immutable golden AMIs)
[ ] Amazon Inspector scanning (EC2/ECR/Lambda) for vulnerabilities
[ ] Containers: scan images, no secrets in images, minimal base, non-root user
[ ] App runs as non-root (deploy user); least-privilege instance/exec roles
[ ] Dependency scanning (SCA) + SAST in CI/CD
[ ] Input validation, output encoding; protect against SSRF/injection
```

## 6. Logging, Monitoring & Detection 🔒
```
[ ] CloudTrail: all Regions, management + (key) data events, log file validation
[ ] CloudTrail logs in a dedicated, locked logging account (S3 Object Lock)
[ ] GuardDuty enabled in all Regions (+ Malware Protection, S3, EKS, RDS protections)
[ ] AWS Config recording + conformance packs (CIS / FSBP)
[ ] Security Hub aggregating findings across accounts/Regions
[ ] CloudWatch alarms: root login, IAM changes, StopLogging, failed logins, SG changes
[ ] Alerts routed to SNS / ticketing / on-call
[ ] VPC Flow Logs, S3 access logs, ALB/CloudFront logs centralized
[ ] Log retention meets compliance; logs immutable
```

## 7. Backup & Resilience
```
[ ] Automated backups (AWS Backup) for RDS/EBS/DynamoDB/EFS/S3
[ ] Backups encrypted, versioned, cross-Region/cross-account (immutable)
[ ] S3 versioning + Object Lock for critical data (ransomware protection)
[ ] Restore tested regularly (a backup you can't restore = no backup)
[ ] Multi-AZ for prod databases; DR plan + RTO/RPO defined
```

## 8. Governance & Compliance
```
[ ] Infrastructure as Code (CloudFormation/Terraform); peer-reviewed; least-priv baked in
[ ] Change management: PR review, no manual prod changes
[ ] Tagging standard enforced (Owner/Env/DataClass/CostCenter)
[ ] Quarterly access reviews (Access Analyzer unused access)
[ ] Compliance mapping (Audit Manager) if regulated (PCI/HIPAA/GDPR/ISO)
[ ] Vendor/third-party access via scoped cross-account roles + ExternalId
```

## 9. Incident Response Readiness 🚨
```
[ ] IR plan documented; roles/contacts defined; runbooks per scenario
[ ] Break-glass procedure + credentials secured (and alarmed)
[ ] Forensics readiness: snapshot/isolation playbooks, log access in audit account
[ ] IR drills/tabletop exercises performed
[ ] AWS Support plan adequate (Business/Enterprise for fast response)
```

---

## Priority Tiers (if you can't do everything at once)

**🔴 Do first (highest impact, lowest effort)**
```
1. MFA on root + lock it away; no root keys
2. Turn on CloudTrail (all Regions) + GuardDuty
3. S3 Block Public Access ON everywhere
4. Remove/rotate exposed access keys; roles for apps
5. Close 0.0.0.0/0 on admin/db ports
6. Budgets + billing alarm
```
**🟡 Next**
```
7. Least-privilege pass on IAM (Access Advisor/Analyzer)
8. KMS encryption + Secrets Manager for secrets
9. SCP guardrails (protect logs, Regions)
10. IMDSv2 required on EC2
11. Config + Security Hub standards
```
**🟢 Mature**
```
12. Multi-account separation + permission boundaries
13. WAF/Shield, VPC endpoints, Flow Logs
14. Automated backups + restore tests + DR
15. IR playbooks + drills; IaC with security gates
```

---

## Verification Snippets
```bash
# root MFA + key status
aws iam get-account-summary --query 'SummaryMap.AccountMFAEnabled'
# CloudTrail multi-region?
aws cloudtrail describe-trails --query 'trailList[].{Name:Name,Multi:IsMultiRegionTrail}'
# GuardDuty detectors
aws guardduty list-detectors
# public-facing SGs
aws ec2 describe-security-groups --query "SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp,'0.0.0.0/0')]].GroupId"
# IMDSv2 enforcement
aws ec2 describe-instances --query "Reservations[].Instances[].{Id:InstanceId,Tokens:MetadataOptions.HttpTokens}"
```

💡 **Use this as a living document:** track each control's status (Done / Gap / N-A) with an owner and date. Re-verify on every major change.

➡️ Next: [06-hrms-security-design.md](06-hrms-security-design.md)

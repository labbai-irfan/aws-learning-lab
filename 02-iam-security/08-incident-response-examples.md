# Module 8 — Incident Response (IR) Examples

> Concrete playbooks for the incidents you're most likely to face. Each follows the standard lifecycle and gives **exact actions**. Practice these before you need them.

> ⚠️ **For accounts you own/are authorized to defend.** Containment steps can disrupt production — follow your change/communication process and preserve evidence before destroying it.

---

## The IR Lifecycle (NIST-aligned)
```
PREPARE → DETECT & ANALYZE → CONTAIN → ERADICATE → RECOVER → POST-INCIDENT (lessons)
```
**Prepare (always-on):** IR plan + contacts, break-glass access, CloudTrail/GuardDuty on, logs in a locked audit account, snapshots/isolation runbooks, adequate AWS Support plan.

**Golden rules during an incident 🚨**
- **Preserve evidence before you delete** (snapshots, logs, memory) — but contain fast.
- **Communicate** (incident channel, stakeholders, legal/compliance if PII).
- **Rotate** anything possibly exposed.
- **Don't tip off** the attacker prematurely if doing forensics — but stop active damage first.

---

## Playbook 1 — Leaked / Compromised Access Keys 🚨

**Detect:** GuardDuty `UnauthorizedAccess`/`CryptoCurrency`, billing spike, AWS exposed-key notice, CloudTrail calls from unknown IPs/Regions.

**Contain (minutes matter):**
```bash
# 1) Deactivate the key immediately (don't delete yet — preserve for forensics)
aws iam update-access-key --user-name <user> --access-key-id <AKIA...> --status Inactive
# 2) If the identity is fully compromised, attach a deny-all/quarantine policy
aws iam put-user-policy --user-name <user> --policy-name QUARANTINE \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
# 3) Revoke active sessions for assumed roles (invalidate older temp creds)
aws iam put-role-policy --role-name <role> --policy-name RevokeOldSessions \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*",
    "Condition":{"DateLessThan":{"aws:TokenIssueTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}}}]}'
```

**Analyze:** CloudTrail — what did the key do? New IAM users/roles? Launched EC2? Touched S3? Changed logging?
```bash
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<AKIA...>
```

**Eradicate:** delete the key, remove any attacker-created users/roles/policies/resources, terminate rogue EC2, restore changed configs.

**Recover:** rotate all related secrets, re-issue clean credentials (prefer roles), restore from clean backups, verify logging intact, re-enable normal access.

**Post:** root cause (how did the key leak?), add secret scanning, switch to roles, enable budgets/anomaly detection, file AWS support case for fraudulent charges.

---

## Playbook 2 — Public S3 Bucket / Data Exposure 🚨

**Detect:** Access Analyzer/Config "public bucket," Macie PII finding, external report.

**Contain:**
```bash
# Re-enable Block Public Access on the bucket
aws s3api put-public-access-block --bucket <bucket> --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
# Remove any public bucket policy statement / public ACLs
aws s3api put-bucket-ownership-controls --bucket <bucket> \
  --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerEnforced"}]}'
```

**Analyze:** S3 access logs / CloudTrail data events — what was accessed, by whom, since when? Determine if PII was exposed (triggers breach-notification duties).

**Eradicate/Recover:** fix the policy permanently, rotate any secrets that were in the bucket, enable Config rule to prevent recurrence, notify per legal obligations if PII exposed.

**Post:** enforce Block Public Access org-wide via SCP; add Access Analyzer + Config monitoring.

---

## Playbook 3 — Compromised EC2 Instance 🚨

**Detect:** GuardDuty (`Backdoor`, `CryptoCurrency`, `InstanceCredentialExfiltration`), unusual outbound traffic, high CPU.

**Contain (isolate, don't terminate yet):**
```bash
# 1) Isolation security group: no inbound, no outbound (or only to forensics)
aws ec2 modify-instance-attribute --instance-id i-123 --groups sg-ISOLATION
# 2) Disable the instance role / remove instance profile to kill its AWS access
aws ec2 disassociate-iam-instance-profile --association-id <assoc-id>
# 3) Snapshot for forensics BEFORE any destructive action
aws ec2 create-snapshot --volume-id vol-123 --description "IR forensic i-123"
# 4) Tag and take memory capture if tooling allows; do NOT log in casually (alters state)
```

**Analyze:** review snapshot offline, VPC Flow Logs, CloudTrail for the instance role; identify entry vector (SSRF? exposed port? bad dependency?).

**Eradicate/Recover:** terminate the compromised instance, relaunch from a **clean golden AMI**, rotate any creds the role could reach, patch the vulnerability, enforce **IMDSv2**.

**Post:** least-privilege the instance role, add WAF, patching cadence, GuardDuty alerting.

---

## Playbook 4 — IAM Privilege Escalation / Rogue Admin 🚨

**Detect:** CloudTrail alarms on IAM changes (`CreateUser`, `AttachUserPolicy`, `CreatePolicyVersion`, `CreateAccessKey`), Access Analyzer findings.

**Contain:**
- Quarantine the offending principal (deny-all policy), deactivate its keys, revoke sessions (as in Playbook 1).
- Remove attacker-created identities/policies; revert policy versions.

**Analyze:** full CloudTrail timeline of the principal — what privileges were added, what was accessed/changed, did they touch logging?

**Eradicate/Recover:** restore correct policies, rotate affected credentials, verify no persistence (backdoor users/roles, access keys, Lambda, EventBridge rules).

**Post:** add **permission boundaries**, scope `iam:PassRole`, SCP to deny risky IAM actions, alarm on IAM changes, mandatory peer review for policy edits.

---

## Playbook 5 — Logging Disabled (anti-forensics) 🚨

**Detect:** CloudWatch alarm on `StopLogging`/`DeleteTrail`/`DeleteDetector`, Security Hub control failure.

**Contain/Recover:**
```bash
aws cloudtrail start-logging --name <trail>          # re-enable immediately
```
- Treat as a strong indicator of active compromise — escalate, begin full IR.
- Pull logs from the **separate audit account** (which the attacker couldn't reach).

**Post:** SCP to **deny** stopping/deleting CloudTrail/GuardDuty/Config; ensure logs live in a locked, separate account with Object Lock + log file validation.

---

## Playbook 6 — Ransomware / Mass Deletion on S3 🚨

**Detect:** GuardDuty anomalous deletes/exfil, CloudTrail mass `DeleteObject`/`PutObject`, app errors.

**Contain:** quarantine the offending principal; if versioning + Object Lock are on, data is recoverable.

**Recover:** restore prior **versions** / from **immutable cross-account backups**; rotate creds.

**Post:** ensure **versioning + Object Lock + MFA Delete + immutable backups** everywhere critical; least-privilege delete permissions.

---

## Playbook 7 — Exposed Secret (in code/CI/image) 🚨

**Contain:** **rotate the secret immediately** (assume it's compromised), revoke old value.
```bash
aws secretsmanager rotate-secret --secret-id prod/db          # or update + force new version
```
**Analyze:** where was it exposed (git history, image, logs)? What could it access? CloudTrail for misuse.
**Eradicate/Recover:** purge from history/images, move to Secrets Manager, fetch via role at runtime.
**Post:** CI secret scanning, pre-commit hooks, no plaintext env secrets, KMS-encrypt Lambda env.

---

## IR Quick Reference
```
Leaked keys     → deactivate key → quarantine → CloudTrail timeline → rotate → roles
Public S3       → BlockPublicAccess on → fix policy → assess exposure → notify if PII
Compromised EC2 → isolate SG + strip role → snapshot → relaunch clean → IMDSv2
Priv-esc IAM    → quarantine → remove rogue identities → boundaries/SCP after
Logs disabled   → start-logging → pull audit-account logs → full IR → SCP protect
Ransomware S3   → quarantine → restore versions/immutable backups → Object Lock
Exposed secret  → rotate NOW → purge → Secrets Manager + scanning
ALWAYS: preserve evidence • communicate • rotate exposed creds • document timeline
```

## Post-Incident Review (every time)
```
[ ] Timeline reconstructed from CloudTrail/logs
[ ] Root cause identified (which fundamental was missing?)
[ ] Blast radius + data impact assessed (notification duties?)
[ ] Controls added to prevent recurrence (and tested)
[ ] Detection improved (new alarm/GuardDuty/Config rule)
[ ] Runbook updated; blameless retro shared
```

💡 **The best IR is prevention + detection:** least privilege, roles-not-keys, MFA, encryption, immutable logging in a separate account, and tested backups turn most "disasters" into quick, contained events.

➡️ Next: [09-100-interview-questions.md](09-100-interview-questions.md)

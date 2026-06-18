# Module 9 — 100 AWS Security Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, technically correct — for security-engineer, DevOps, and Solutions Architect interviews.

---

## IAM Fundamentals (1–15)
**1. What is IAM?** AWS's service for authentication and authorization — it controls who (principals) can do what (actions) on which resources, under what conditions. It's free and global.

**2. How does IAM evaluate a request?** Default is implicit deny; an explicit Allow grants access; an explicit Deny anywhere always overrides. SCPs and permission boundaries can further cap it.

**3. Does an explicit Deny ever lose?** No — explicit Deny always wins, regardless of any Allow.

**4. Is IAM global or regional?** Global — IAM identities and policies aren't tied to a Region.

**5. What's a principal?** The entity making a request: an IAM user, role, federated identity, or AWS service.

**6. What's the difference between authentication and authorization?** Authentication proves who you are (credentials/MFA); authorization decides what you're allowed to do (policies).

**7. What are the main IAM entities?** Users, groups, roles, and policies.

**8. What is an ARN?** Amazon Resource Name — the unique identifier for an AWS resource, used in policies.

**9. What's the principle of least privilege?** Grant only the permissions needed to perform a task, on specific resources — nothing more.

**10. What is the root user and how should it be handled?** The all-powerful account owner; enable MFA, never create access keys for it, and don't use it for daily work.

**11. How do you secure the root user?** MFA (hardware/FIDO), no access keys, alternate contacts set, alarm on root login, and lock it away.

**12. What is the IAM policy evaluation order with SCP and boundaries?** Effective permissions = identity policies ∩ SCP ∩ permission boundary, minus any explicit Deny, plus resource policies for cross-account.

**13. What's the difference between IAM and Identity Center?** IAM manages identities/policies within an account; IAM Identity Center (SSO) centrally manages human access across many accounts with federation and MFA.

**14. What is STS?** Security Token Service — issues temporary, limited-privilege credentials (e.g., when assuming a role).

**15. Why is IAM described as 'deny by default'?** Because nothing is permitted until a policy explicitly allows it (implicit deny).

---

## Users, Groups, Roles (16–32)
**16. IAM user vs role?** A user is a long-lived identity with permanent credentials; a role is assumed temporarily and issues short-lived credentials — roles are preferred for apps/services/cross-account.

**17. Why prefer roles over access keys?** No long-lived secrets to leak; credentials are temporary and auto-rotated; scoped by trust + permissions policies.

**18. What is a group?** A collection of users that share permissions; you attach policies to the group and members inherit them.

**19. Can groups be nested?** No — IAM groups can't contain other groups.

**20. Can a role be assumed by multiple entities?** Yes, if the trust policy allows them (users, services, accounts, or federated identities).

**21. What two policies does a role have?** A trust policy (who can assume it) and a permissions policy (what it can do).

**22. What is an instance profile?** The container that attaches an IAM role to an EC2 instance so apps on it get temporary credentials.

**23. How does an EC2 app access S3 securely?** Attach an IAM role to the instance; the SDK uses the role's temporary credentials via the metadata service — no stored keys.

**24. What is cross-account access via roles?** A role in account A trusts account B; users/roles in B assume it to get scoped access in A.

**25. What is sts:ExternalId for?** Preventing the confused-deputy problem in third-party cross-account roles by requiring a shared secret on AssumeRole.

**26. What is a service-linked role?** A predefined role that lets an AWS service perform actions on your behalf.

**27. How long do assumed-role credentials last?** Configurable (typically 1 hour, up to 12), after which you must re-assume.

**28. How do you revoke an assumed role's active sessions?** Attach a policy denying actions for tokens issued before a cutoff time (`aws:TokenIssueTime`).

**29. When would you still use an IAM user?** Rarely — e.g., a legacy system that can't assume roles; otherwise use roles/Identity Center.

**30. How do you grant temporary access to a contractor?** A scoped cross-account role with ExternalId and MFA, or Identity Center with time-bound access.

**31. What's the risk of long-lived access keys?** They can leak (code, logs) and be abused; they don't expire unless rotated/deleted.

**32. How do you rotate access keys safely?** Create a second key, deploy it, verify, then deactivate and delete the old one (two-key rotation).

---

## Policies (33–48)
**33. What is an IAM policy?** A JSON document of statements (Effect, Action, Resource, Condition) that allow or deny permissions.

**34. Identity-based vs resource-based policy?** Identity-based attaches to a user/role (what they can do); resource-based attaches to a resource like an S3 bucket/KMS key (who can access it) and enables cross-account.

**35. Managed vs inline policies?** Managed (AWS or customer) are standalone, reusable, versioned; inline are embedded in a single identity — harder to audit/reuse.

**36. What are the parts of a policy statement?** Sid, Effect, Action, Resource, and optional Condition (and Principal for resource/trust policies).

**37. What are condition keys? Give examples.** Constraints on when a statement applies — e.g., `aws:MultiFactorAuthPresent`, `aws:SourceIp`, `aws:RequestedRegion`, `aws:SecureTransport`, `aws:PrincipalTag`.

**38. What is ABAC?** Attribute-Based Access Control — grant access by matching tags (e.g., resource tag == principal tag), which scales without per-resource policies.

**39. ABAC vs RBAC?** RBAC grants by role/group membership; ABAC grants by attributes/tags — ABAC scales better for large, dynamic environments.

**40. How do you require MFA in a policy?** A Deny statement with `Condition: BoolIfExists aws:MultiFactorAuthPresent = false` on sensitive actions.

**41. How do you restrict access by IP?** A condition on `aws:SourceIp` (careful to exclude legitimate AWS service calls via `aws:ViaAWSService`).

**42. How do you restrict to certain Regions?** Deny with `aws:RequestedRegion` not in your approved list (exclude global services with NotAction).

**43. What is the policy simulator?** A tool to test whether a principal's policies would allow/deny a given action before deploying.

**44. What's dangerous about iam:PassRole?** Unrestricted, it lets a user attach a powerful role to a service (privilege escalation); scope it to specific roles + services.

**45. What does a wildcard policy ("*":"*") imply?** Full admin — only true administrators should ever have it.

**46. How do you build a least-privilege policy from scratch?** Measure real usage (CloudTrail/Access Advisor), generate a policy from activity, scope ARNs, add conditions, then prune unused.

**47. What is a session policy?** A policy passed when assuming a role that further restricts that session's permissions.

**48. How do resource policies enable cross-account access?** They name the external account/principal directly, so access works without a role in the caller's account (e.g., an S3 bucket policy).

---

## MFA (49–56)
**49. What is MFA and why use it?** A second authentication factor beyond a password, so a stolen password alone can't grant access.

**50. What MFA types does AWS support?** Virtual TOTP apps, hardware TOTP tokens, FIDO2 security keys, and passkeys.

**51. Which MFA is phishing-resistant?** FIDO2 security keys (and passkeys).

**52. Where must MFA be enabled?** On the root user and all privileged IAM identities; ideally everywhere.

**53. How do you enforce MFA for the CLI?** Require MFA via policy and obtain an MFA session with `sts get-session-token` (serial number + token code).

**54. What if a user is locked out after enforcing MFA?** Ensure the policy still allows self-service MFA device setup actions on their own identity.

**55. How do you recover a lost root MFA device?** Use AWS account recovery via registered email/phone; for IAM users, an admin reassigns the device.

**56. Can you require MFA only for sensitive actions?** Yes — apply the MFA condition only to those actions (e.g., delete, IAM, KMS deletion).

---

## Permission Boundaries & SCP (57–70)
**57. What is a permission boundary?** A managed policy that sets the maximum permissions an IAM user/role can have; effective access is the intersection of its policies and the boundary.

**58. Does a boundary grant permissions?** No — it only caps them; you still need an allow policy.

**59. Why use permission boundaries?** To safely delegate IAM (let teams create roles/users) without allowing privilege escalation beyond the cap.

**60. What is an SCP?** A Service Control Policy in AWS Organizations that sets the maximum permissions for accounts/OUs.

**61. Does an SCP grant permissions?** No — it only limits; IAM still must allow the action.

**62. Does an SCP affect the root user?** Yes, for member accounts' root — but not the organization's management account.

**63. SCP vs permission boundary vs IAM policy?** SCP = org/account-wide cap; boundary = per-principal cap; IAM policy = actually grants. Effective = intersection of all, minus explicit Deny.

**64. Give an example SCP guardrail.** Deny `cloudtrail:StopLogging`, restrict to approved Regions, deny leaving the org, deny disabling GuardDuty.

**65. Allow-list vs deny-list SCP strategy?** Deny-list allows everything then denies specifics (common); allow-list denies everything then allows specifics (tighter, more work).

**66. Why isn't the management account restricted by SCPs?** By design, to avoid locking yourself out of org administration; keep workloads out of it.

**67. How do boundaries help a CI/CD that creates roles?** The pipeline can only create roles within the boundary, preventing it from minting admin roles.

**68. How do you prevent a Region from being used org-wide?** An SCP denying actions when `aws:RequestedRegion` isn't approved (excluding global services).

**69. Can SCPs enforce encryption?** Yes — e.g., deny S3 PutObject without SSE, or deny creating unencrypted resources.

**70. What's the layered model for max security?** SCP (org cap) + permission boundary (principal cap) + least-privilege IAM (grant) + resource policies + conditions.

---

## Secrets Manager & KMS (71–86)
**71. What is Secrets Manager?** A service to store, retrieve, and automatically rotate secrets (DB passwords, API keys), encrypted with KMS.

**72. Secrets Manager vs Parameter Store?** Secrets Manager has built-in automatic rotation (paid per secret); Parameter Store SecureString is cheaper but manual rotation — good for config/simple secrets.

**73. How should an app get a secret?** Fetch it at runtime via an IAM role from Secrets Manager — never hardcode it.

**74. How does secret rotation work?** A rotation schedule triggers a Lambda (built-in for RDS) that creates a new credential and updates both the service and the secret.

**75. What is KMS?** Key Management Service — creates/manages encryption keys and performs crypto operations, with access control and CloudTrail audit.

**76. Customer managed vs AWS managed keys?** Customer managed keys (CMKs) give you full control over key policy, rotation, and grants; AWS managed keys are auto-created per service with no policy control.

**77. What is a KMS key policy?** The resource policy on a key — the primary access control; IAM alone isn't enough if the key policy doesn't permit the principal.

**78. What is envelope encryption?** KMS encrypts a data key, which encrypts your data; efficient for large data (used by S3/EBS).

**79. How do you reduce KMS costs/throttling?** Enable S3 Bucket Keys and reuse data keys to cut KMS API calls.

**80. How do you audit who decrypted data?** CloudTrail logs every KMS Decrypt with the principal — pair with a CMK to get fine-grained accountability.

**81. How do you encrypt an existing unencrypted EBS volume?** Snapshot it, copy the snapshot with encryption (KMS), then create a new volume from the encrypted snapshot.

**82. SSE-S3 vs SSE-KMS vs SSE-C?** SSE-S3 = AWS-managed keys (simple); SSE-KMS = your KMS key with audit/control; SSE-C = you supply the key per request.

**83. What is key rotation?** Periodic generation of new key material (KMS supports automatic yearly rotation for CMKs) to limit exposure.

**84. How do you share encrypted data cross-account?** Grant the other account's principal access in the KMS key policy (and the resource policy) so they can decrypt.

**85. How do you protect against accidental key deletion?** KMS requires a waiting period (7–30 days) before deletion, which you can cancel; restrict `kms:ScheduleKeyDeletion`.

**86. Where should you never store secrets?** In code, git, AMIs, container images, plaintext env vars, or application logs.

---

## Detection, Audit & Best Practices (87–100)
**87. What does CloudTrail do?** Records API calls/management (and optionally data) events across the account — the primary audit/forensic log.

**88. How do you make logs tamper-resistant?** Store CloudTrail logs in a separate, locked audit account (S3 Object Lock) with log file validation, and SCP-deny stopping logging.

**89. What is GuardDuty?** A managed threat-detection service that analyzes CloudTrail, VPC Flow Logs, and DNS logs for malicious/anomalous activity.

**90. What is AWS Config?** Tracks resource configurations over time and evaluates them against rules for compliance and drift.

**91. What is Security Hub?** Aggregates and prioritizes security findings across accounts/Regions and runs best-practice standards (CIS, AWS FSBP).

**92. What is IAM Access Analyzer?** Identifies resources shared with external entities and unused access (roles, keys, excess permissions); also validates/generates policies.

**93. What is the IAM Credential Report?** A CSV of all users' credential status (passwords, keys, MFA, last used) for auditing.

**94. What is Macie?** ML-based discovery of sensitive data (PII) in S3.

**95. What is Inspector?** Automated vulnerability scanning for EC2, ECR images, and Lambda.

**96. How do you detect a compromised instance?** GuardDuty findings (credential exfiltration, crypto-mining, backdoor), VPC Flow Logs anomalies, and CloudTrail for the instance role.

**97. What is IMDSv2 and why enforce it?** A session-token-protected version of the instance metadata service that mitigates SSRF-based credential theft; enforce with `http-tokens=required`.

**98. What are the top AWS security best practices?** Least privilege, roles over keys, MFA everywhere, encrypt at rest/in transit, secrets in Secrets Manager, CloudTrail+GuardDuty on, Block Public Access, SCP/boundary guardrails, monitoring/alarms, and a tested IR plan.

**99. Walk through responding to leaked access keys.** Deactivate the key, quarantine the identity and revoke sessions, analyze CloudTrail for what it did, eradicate attacker resources, rotate all related secrets, restore from clean backups, then add prevention (roles, secret scanning, budgets).

**100. Design security for a multi-account organization.** Separate accounts (prod/dev/security/logging) under Organizations; SCP guardrails; centralized CloudTrail/GuardDuty/Config/Security Hub in a security account with immutable logs; Identity Center + MFA for humans; roles for workloads; KMS encryption; Secrets Manager; least privilege with permission boundaries; automated detection, alarms, and tested incident-response runbooks.

🎉 **Phase 02 complete.** You can now design IAM with least privilege, protect data with KMS and Secrets Manager, set org guardrails, audit posture, recognize real attacks, and run incident response.

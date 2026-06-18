# Module 7 — Security Troubleshooting Guide

> Symptom → cause → fix for the security problems you'll actually hit: access denied, role/trust issues, MFA, KMS, Secrets Manager, SCP/boundary conflicts, and logging. Plus the diagnostic toolkit.

---

## The Diagnostic Toolkit
```bash
aws sts get-caller-identity                 # who am I right now?
aws iam simulate-principal-policy \          # will this principal be allowed?
  --policy-source-arn arn:aws:iam::123:user/alice \
  --action-names s3:GetObject --resource-arns arn:aws:s3:::my-bucket/key
aws cloudtrail lookup-events \               # find the denied call + which policy
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject
aws iam get-account-authorization-details    # dump policies/roles for review
```
💡 **CloudTrail is the source of truth** — the `errorCode`/`errorMessage` on a denied event usually names the reason.

---

## A. "Access Denied" — the most common issue

```
Decision logic to walk:
1. Explicit DENY anywhere? (IAM, resource policy, SCP, boundary, session) → that's it
2. SCP blocks the action? (org guardrail)                                   → fix/scope SCP
3. Permission boundary excludes it? (intersection)                          → widen boundary
4. No ALLOW at all? (implicit deny)                                         → add least-priv allow
5. Resource policy missing/wrong? (S3/KMS cross-account)                    → fix resource policy
6. Wrong resource ARN granularity? (bucket vs bucket/*)                     → correct the ARN
7. Condition not met? (MFA/IP/Region/tag)                                   → satisfy condition
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| Denied despite an Allow policy | Explicit Deny (SCP/boundary/policy) wins | Find the Deny via simulate/CloudTrail; remove or satisfy it |
| Denied only in some Regions | SCP Region restriction | Use an approved Region or adjust SCP |
| Denied for a delegated role | Permission boundary intersection | Boundary must also allow the action |
| `s3:ListBucket` denied | Permission on object ARN, not bucket ARN | ListBucket → bucket ARN; GetObject → bucket/* |
| Cross-account denied | Missing resource policy or trust | Add bucket/KMS policy for the other account |
| Denied without MFA | `aws:MultiFactorAuthPresent=false` condition | Re-auth with MFA |

---

## B. Role / AssumeRole / Trust Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AccessDenied` on `sts:AssumeRole` | Trust policy doesn't allow the principal | Add the user/service/account to the role's trust policy |
| EC2 can't access AWS (no creds) | No instance profile attached | Attach the IAM role/instance profile to the instance |
| Lambda denied to a resource | Execution role lacks permission | Add least-priv permission to the Lambda role |
| Cross-account assume fails | Missing/incorrect ExternalId | Provide matching `sts:ExternalId` |
| "Cannot pass role" | `iam:PassRole` not granted/scoped | Grant scoped PassRole for that role+service |
| Temp creds expired | Session token timed out | Re-assume the role / refresh credentials |
| App still uses old creds after role change | Cached credentials | Restart app / clear SDK credential cache |

💡 A role needs **both**: a **trust policy** (who can assume) **and** a **permissions policy** (what it can do). Missing either causes failures.

---

## C. MFA Problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| Locked out after enforcing MFA | Policy requires MFA but user can't set it up | Allow self-service MFA setup actions even without MFA (`iam:*MFADevice` on self) |
| CLI denied with MFA-required policy | No MFA in the CLI session | Use `aws sts get-session-token` with `--serial-number` + `--token-code`, then use those temp creds |
| Lost MFA device | Can't sign in | Admin removes/reassigns the device; for root, use account recovery (email/phone) |
| MFA codes rejected | Device clock drift | Resync the authenticator app time |

```bash
# Get an MFA-authenticated session for the CLI
aws sts get-session-token --serial-number arn:aws:iam::123:mfa/alice --token-code 123456
```

---

## D. KMS / Encryption Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AccessDenied` decrypting S3/RDS object | No `kms:Decrypt` on the key | Grant decrypt in the key policy/IAM to the role |
| Upload denied by bucket policy | SSE-KMS required but header missing | Send `x-amz-server-side-encryption: aws:kms` |
| Cross-account can't use key | Key policy doesn't allow them | Update KMS key policy + their IAM |
| KMS throttling at scale | Too many KMS calls | Enable **S3 Bucket Keys**; cache data keys |
| Can't delete key / data unreadable | Key scheduled for deletion / disabled | Cancel deletion within the window; re-enable key |
| `kms:ViaService` condition blocks | Calling KMS directly vs via service | Match the condition (use via the intended service) |

🔒 KMS **key policy is the root of trust** — IAM alone isn't enough if the key policy doesn't permit the principal.

---

## E. Secrets Manager Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `AccessDenied` on GetSecretValue | Role lacks secrets permission | Grant `secretsmanager:GetSecretValue` on the secret ARN |
| Also denied with KMS error | Secret encrypted with a CMK the role can't use | Grant `kms:Decrypt` on the secret's key |
| App uses stale secret after rotation | Cached value | Re-fetch on rotation events / shorten cache TTL |
| Rotation failing | Rotation Lambda perms/network | Check Lambda role + VPC access to the secret/DB |
| Secret "not found" | Wrong Region/name/ARN | Verify Region + exact secret id |

---

## F. SCP / Permission Boundary Conflicts

| Symptom | Cause | Fix |
|---------|-------|-----|
| Admin can't do something obvious | SCP denies it org-wide | Adjust the SCP or perform from management account |
| Member-account root blocked | SCP applies to member root | Expected — change SCP if truly needed |
| Delegated user under-permissioned | Boundary intersection too tight | Widen the permission boundary |
| "Allow" added but still denied | SCP/boundary caps it | Effective = identity ∩ SCP ∩ boundary; loosen the cap |

💡 Remember the math: **effective = identity policies ∩ SCP ∩ permission boundary**, minus any explicit Deny.

---

## G. Logging / Detection Gaps

| Symptom | Cause | Fix |
|---------|-------|-----|
| No CloudTrail events for a Region | Trail not multi-Region | Enable a multi-Region trail |
| Object-level S3 access not logged | Data events not enabled | Enable CloudTrail **data events** for the bucket |
| Can't trust logs (tampering risk) | Logs in the same account, mutable | Ship to locked audit account (Object Lock) + log file validation |
| GuardDuty findings missing | Not enabled in that Region | Enable GuardDuty in all Regions |
| Alarm never fired | Metric filter/alarm misconfigured | Verify the metric filter pattern + SNS subscription |

---

## General Diagnostic Order
```
1. aws sts get-caller-identity     → confirm WHICH identity is acting
2. Reproduce; capture exact error + errorCode from CloudTrail
3. Use IAM Policy Simulator        → is it allowed in theory?
4. Walk the deny chain: SCP → boundary → identity → resource policy → condition
5. For KMS/Secrets: check the KEY/RESOURCE policy too, not just IAM
6. Fix the smallest thing (add least-priv allow / satisfy condition)
7. Re-test; confirm no new over-permissioning was introduced
```

## Quick Reference
```
Access denied      → deny chain (SCP→boundary→identity→resource→condition); simulate + CloudTrail
AssumeRole fails   → fix trust policy (and ExternalId)
EC2 no creds       → attach instance profile/role
MFA lockout        → allow self-service MFA; sts get-session-token for CLI
KMS denied         → key policy must allow the principal; Bucket Keys for throttling
Secret denied      → secrets perm + kms:Decrypt on its key
Effective perms    → identity ∩ SCP ∩ boundary, minus explicit Deny
Logs untrustworthy → separate audit account + Object Lock + validation
```

➡️ Next: [08-incident-response-examples.md](08-incident-response-examples.md)

# Module 4 — Least Privilege Examples

> Least privilege = grant **only** the permissions needed, on **only** the specific resources, under **the right conditions**. This module shows the journey from over-permissive → tight, with copy-paste policies.

---

## The Principle
```
Start from ZERO (implicit deny) → grant exactly what's needed → add conditions → review & shrink over time.
NOT: start from admin → remove things later (you never do).
```
**Workflow to reach least privilege:**
1. Identify the **actions** the workload actually calls (CloudTrail / Access Advisor).
2. Scope to **specific resource ARNs** (not `*`).
3. Add **conditions** (MFA, source IP, Region, tags).
4. Test, then **remove** anything unused (Access Analyzer unused-access).

---

## Example 1 — App that reads ONE S3 prefix

❌ **Over-permissive**
```json
{ "Effect":"Allow","Action":"s3:*","Resource":"*" }
```
✅ **Least privilege**
```json
{ "Version":"2012-10-17","Statement":[{
  "Sid":"ReadUploadsOnly",
  "Effect":"Allow",
  "Action":["s3:GetObject"],
  "Resource":"arn:aws:s3:::acme-app/uploads/*"
}]}
```
If it also lists that prefix:
```json
{ "Effect":"Allow","Action":"s3:ListBucket","Resource":"arn:aws:s3:::acme-app",
  "Condition":{"StringLike":{"s3:prefix":"uploads/*"}} }
```
💡 `GetObject`/`PutObject` target the **object** ARN (`/*`); `ListBucket` targets the **bucket** ARN.

---

## Example 2 — EC2 role to read app secrets + write logs

✅ Scoped to the exact secret and log group:
```json
{ "Version":"2012-10-17","Statement":[
  {"Sid":"ReadAppSecret","Effect":"Allow",
   "Action":"secretsmanager:GetSecretValue",
   "Resource":"arn:aws:secretsmanager:ap-south-1:123:secret:prod/db-*"},
  {"Sid":"WriteAppLogs","Effect":"Allow",
   "Action":["logs:CreateLogStream","logs:PutLogEvents"],
   "Resource":"arn:aws:logs:ap-south-1:123:log-group:/app/api:*"},
  {"Sid":"DecryptWithAppKey","Effect":"Allow",
   "Action":"kms:Decrypt",
   "Resource":"arn:aws:kms:ap-south-1:123:key/<app-key-id>"}
]}
```
Attach via an **instance role** (no static keys).

---

## Example 3 — Lambda execution role (DynamoDB + its own logs)
```json
{ "Version":"2012-10-17","Statement":[
  {"Effect":"Allow",
   "Action":["dynamodb:GetItem","dynamodb:PutItem","dynamodb:Query"],
   "Resource":"arn:aws:dynamodb:ap-south-1:123:table/Orders"},
  {"Effect":"Allow",
   "Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
   "Resource":"arn:aws:logs:ap-south-1:123:log-group:/aws/lambda/orders-fn:*"}
]}
```
Note: only the **specific table** and the function's **own** log group — not `dynamodb:*` on `*`.

---

## Example 4 — Require MFA for sensitive actions
```json
{ "Version":"2012-10-17","Statement":[{
  "Sid":"DenyWithoutMFA",
  "Effect":"Deny",
  "Action":["iam:*","s3:DeleteObject","ec2:TerminateInstances","kms:ScheduleKeyDeletion"],
  "Resource":"*",
  "Condition":{"BoolIfExists":{"aws:MultiFactorAuthPresent":"false"}}
}]}
```
Dangerous actions are blocked unless the session is MFA-authenticated.

---

## Example 5 — Restrict by source IP (office/VPN only)
```json
{ "Effect":"Deny","Action":"*","Resource":"*",
  "Condition":{"NotIpAddress":{"aws:SourceIp":["203.0.113.0/24"]},
               "Bool":{"aws:ViaAWSService":"false"}} }
```
⚠️ Be careful not to lock out legitimate AWS service calls — exclude `aws:ViaAWSService`.

---

## Example 6 — Restrict to approved Regions
```json
{ "Effect":"Deny","NotAction":["iam:*","sts:*","cloudfront:*","route53:*","support:*"],
  "Resource":"*",
  "Condition":{"StringNotEquals":{"aws:RequestedRegion":["ap-south-1","us-east-1"]}} }
```
Global services are excluded via `NotAction`.

---

## Example 7 — Scope `iam:PassRole` (stop priv-esc)
❌ `"Action":"iam:PassRole","Resource":"*"` lets a user pass **any** role to a service (e.g., attach admin role to a Lambda).
✅ Limit to specific roles + service:
```json
{ "Effect":"Allow","Action":"iam:PassRole",
  "Resource":"arn:aws:iam::123:role/app-lambda-role",
  "Condition":{"StringEquals":{"iam:PassedToService":"lambda.amazonaws.com"}} }
```

---

## Example 8 — ABAC (tag-based least privilege, scales nicely)
Grant access only when the resource tag matches the principal's tag:
```json
{ "Effect":"Allow","Action":["ec2:StartInstances","ec2:StopInstances"],
  "Resource":"*",
  "Condition":{"StringEquals":{"aws:ResourceTag/Team":"${aws:PrincipalTag/Team}"}} }
```
A "Team=payments" user can control only "Team=payments" instances — no per-resource policy needed.

---

## Example 9 — Cross-account role with ExternalId (anti confused-deputy)
**Trust policy** on the role in Account A:
```json
{ "Version":"2012-10-17","Statement":[{
  "Effect":"Allow",
  "Principal":{"AWS":"arn:aws:iam::PARTNER-ACCT:root"},
  "Action":"sts:AssumeRole",
  "Condition":{"StringEquals":{"sts:ExternalId":"a-unique-shared-secret"}}
}]}
```
Permissions policy stays least-privilege for exactly what the partner needs.

---

## Example 10 — Read-only auditor role
```json
{ "Version":"2012-10-17","Statement":[{
  "Effect":"Allow",
  "Action":["*:Describe*","*:List*","*:Get*","cloudtrail:LookupEvents"],
  "Resource":"*"
}]}
```
Or attach the AWS managed `SecurityAudit` / `ViewOnlyAccess` policy. Pair with a permission boundary to guarantee it can never write.

---

## Anti-Patterns to Eliminate ❌
```
"Action":"*","Resource":"*"          → admin in disguise (only true admins)
"s3:*" on "*"                        → scope to actions + specific bucket/prefix
iam:PassRole on "*"                  → priv-esc; scope to roles + service
Long-lived access keys for apps      → use roles
No conditions on sensitive actions   → add MFA/IP/Region/tag
One giant policy for everyone        → split by job function; use groups
Inline policies everywhere           → use customer-managed (auditable, reusable)
```

## How to Get There (practical)
1. **Measure** real usage: CloudTrail + IAM Access Advisor (last-accessed services).
2. **Generate** a starting policy from activity (Access Analyzer **policy generation**).
3. **Scope** ARNs + add conditions.
4. **Cap** with a permission boundary; **guardrail** with SCPs.
5. **Review** quarterly; remove unused (Access Analyzer unused-access).

💡 **Rule of thumb:** If you can't justify why a permission is on an identity, **remove it** and see what breaks in a test environment.

➡️ Next: [05-production-security-checklist.md](05-production-security-checklist.md)

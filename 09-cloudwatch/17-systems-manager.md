# 17 — AWS Systems Manager (SSM — Operations Management)

> The Swiss-army knife of AWS operations: securely access, configure, patch, automate, and inventory your fleet — at scale, without SSH or bastion hosts. A heavily-tested **SysOps** and **DevOps Professional** topic, and the answer to "how do I manage hundreds of instances?".

**By the end you can:**
- Access instances with **Session Manager** (no SSH, no open ports, fully audited).
- Store config/secrets in **Parameter Store** and know when to use Secrets Manager instead.
- Patch a fleet with **Patch Manager + Maintenance Windows**.
- Run commands and auto-remediate with **Run Command** and **Automation** runbooks.

**Prerequisites:** [Phase 03 — EC2](../03-ec2/README.md), [Phase 02 — IAM & Security](../02-iam-security/README.md), [01 — CloudWatch Core](01-cloudwatch-core-concepts.md).

---

## 1. What Systems Manager is
A suite of operations tools under one console. Core features are **free**; you pay only for advanced tiers/some actions. To manage an instance it must be a **managed node**:
```
Managed node = SSM Agent installed (default on Amazon Linux/Ubuntu/Windows AMIs)
             + an instance role with AmazonSSMManagedInstanceCore
             + network path to SSM endpoints (NAT or VPC endpoints)
```

## 2. The capabilities (know what each one is for)
| Capability | Solves |
|---|---|
| **Session Manager** | Shell access to instances — **no SSH, no bastion, no open port 22** |
| **Parameter Store** | Centralized config + secrets (SecureString via KMS) |
| **Patch Manager** | OS/app patching across the fleet, with compliance |
| **Run Command** | Run scripts/commands on many nodes at once (no SSH) |
| **Automation** | Runbooks for multi-step ops tasks + **auto-remediation** |
| **State Manager** | Enforce a desired configuration continuously |
| **Maintenance Windows** | Schedule disruptive tasks (patching, restarts) |
| **Inventory** | Collect installed software/config across nodes |
| **Fleet Manager** | Browser-based fleet admin (disks, registry, users) |
| **OpsCenter / Explorer** | Aggregate & act on operational issues (OpsItems) |

---

## 3. Session Manager (the SSH killer) 🔒
```
Admin → AWS console/CLI → Session Manager → SSM Agent on instance → shell
   (IAM-authorized, every keystroke logged to CloudWatch/S3)
```
- **No inbound ports**, no key pairs, no bastion — the instance only needs **outbound** to SSM.
- Access is governed by **IAM**; sessions are **fully audited** (CloudTrail + optional session logs).
- Works in private subnets via **VPC endpoints** (no internet needed).
- 💡 Exam: "secure shell access to private instances without opening SSH / managing keys" → **Session Manager**.

```bash
aws ssm start-session --target i-0123456789abcdef0
```

---

## 4. Parameter Store vs Secrets Manager
```
Parameter Store: /hrms/prod/DB_HOST = rds.internal       (String)
                 /hrms/prod/DB_PASSWORD = ****            (SecureString → KMS)
```
| | **Parameter Store** | **Secrets Manager** |
|---|---|---|
| Cost | Free (standard tier) | Per secret + API calls |
| Rotation | No built-in rotation | **Built-in automatic rotation** |
| Best for | Config + light secrets | Credentials needing rotation |
| Encryption | SecureString via KMS | Always KMS |
- Hierarchical paths (`/app/env/key`) + versioning. Reference parameters in ECS task defs, CloudFormation, Lambda, etc.
- 💡 Exam: "store DB password, **auto-rotate**" → **Secrets Manager**. "store config / light secrets cheaply" → **Parameter Store**.

---

## 5. Patch Manager + Maintenance Windows
- **Patch baseline** defines which patches are approved (by severity/age/classification).
- **Patch groups** (tags) target sets of instances.
- **Maintenance Windows** schedule patching during low-traffic periods.
- **Compliance** reporting shows which nodes are missing patches.
- 💡 Exam: "automatically patch a fleet on a schedule with compliance reporting" → **Patch Manager + Maintenance Windows**.

---

## 6. Run Command & Automation
- **Run Command** = execute a document (script) across many nodes at once — restart a service, deploy a config, gather logs — **no SSH**.
```bash
aws ssm send-command --document-name "AWS-RunShellScript" \
  --targets "Key=tag:env,Values=prod" \
  --parameters 'commands=["systemctl restart nginx"]'
```
- **Automation** = runbooks (SSM documents) that chain steps for ops tasks: AMI builds, instance recovery, and **auto-remediation** (e.g., triggered by a Config rule or CloudWatch alarm to fix a misconfiguration).
- **State Manager** continuously enforces desired state (e.g., "agent X always installed").

---

## 7. How it ties into monitoring
- CloudWatch **alarm** → EventBridge → **SSM Automation** runbook = self-healing (restart, scale, isolate).
- **OpsCenter** aggregates issues (OpsItems) from CloudWatch/Config/GuardDuty for triage.
- This is the bridge from *observability* (this phase) to *automated response*.

---

## 8. HRMS example
```
- Session Manager: ops team shells into private HRMS app instances (no bastion, audited).
- Parameter Store: /hrms/prod/* config; DB password as SecureString (KMS).
- Patch Manager: weekly maintenance window patches the HRMS fleet, compliance reported.
- Automation: CloudWatch high-error alarm → EventBridge → runbook restarts the API & opens an OpsItem.
```
🔒 Result: zero open SSH ports, centralized config, patched fleet, and automated first response.

---

## 9. Exam triggers 💡
- "Shell into private instances, no SSH/bastion, audited" → **Session Manager**.
- "Centralized hierarchical config, cheap, KMS for secrets" → **Parameter Store**.
- "Auto-rotate credentials" → **Secrets Manager** (not Parameter Store).
- "Patch hundreds of instances on a schedule + compliance" → **Patch Manager + Maintenance Windows**.
- "Run a command on all prod instances without SSH" → **Run Command**.
- "Auto-remediate a misconfiguration / self-heal" → **Automation runbook** (often via Config/EventBridge).
- "Manage instances without internet" → SSM via **VPC endpoints**.

## 10. Gotchas ⚠️
- No access if the **SSM Agent**, **instance role** (`AmazonSSMManagedInstanceCore`), or **network path** (NAT/endpoints) is missing — the classic "instance not showing as managed" issue.
- Parameter Store standard tier has size/throughput limits; advanced tier costs and raises them.
- Session Manager needs the agent + IAM perms; it's the modern replacement for opening port 22.

## 11. Quick reference
```
Session Manager → no-SSH shell (IAM-auth, audited)
Parameter Store → config + SecureString (KMS); no rotation
Secrets Manager → secrets WITH auto-rotation
Patch Manager   → fleet patching + compliance (+ Maintenance Windows)
Run Command     → run scripts across nodes (no SSH)
Automation      → runbooks + auto-remediation
State Manager   → enforce desired config
Inventory/Fleet Manager → software inventory / browser admin
Managed node    = SSM Agent + instance role + network path
```

**Official docs:** https://docs.aws.amazon.com/systems-manager/

---

*Back to [CloudWatch & Monitoring README](README.md). Related: [Phase 02 — IAM & Security](../02-iam-security/README.md) · [05 — Alarms](05-alarms.md) → automation.*

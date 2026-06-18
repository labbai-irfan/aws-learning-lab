# Module 4 — Cloud Migration Examples

> How organizations move from on-premises to AWS. Covers the **7 Rs** migration strategies, the **migration phases**, and four worked examples.

---

## Why Migrate to the Cloud?
- Reduce/avoid data-center costs (CapEx → OpEx)
- Scale elastically with demand
- Improve availability and disaster recovery
- Speed up delivery and innovation
- Modernize aging hardware and software

---

## The 7 Rs — Migration Strategies (memorize these)

| Strategy | Nickname | What it means | Example |
|----------|----------|---------------|---------|
| **Rehost** | "Lift & shift" | Move app as-is to EC2, no changes | Copy on-prem VM to an EC2 instance |
| **Replatform** | "Lift, tinker & shift" | Small optimizations, no core rewrite | Move DB to managed Amazon RDS |
| **Repurchase** | "Drop & shop" | Replace with a SaaS product | Swap on-prem CRM for Salesforce |
| **Refactor / Re-architect** | "Rebuild cloud-native" | Redesign using cloud services | Monolith → microservices + Lambda |
| **Retain** | "Revisit / keep" | Leave it on-prem for now | Legacy app not ready to move |
| **Retire** | "Decommission" | Turn it off — no longer needed | Shut down unused legacy server |
| **Relocate** | "Hypervisor move" | Move VMs without buying new HW (e.g., VMware Cloud on AWS) | Bulk-move vSphere VMs |

💡 **Exam tip:** Rehost = fastest/cheapest to start, least optimized. Refactor = most effort, most cloud benefit. Repurchase = switch to SaaS. Retire = delete. Retain = keep on-prem.

```
   EFFORT & CLOUD BENEFIT
   low  |  Retire / Retain
        |  Rehost (lift & shift)
        |  Relocate
        |  Replatform (lift, tinker & shift)
        |  Repurchase (move to SaaS)
   high |  Refactor / Re-architect (cloud-native)  <- most benefit
```

---

## AWS Migration Phases (3 simple stages)

```
   1) ASSESS            2) MOBILIZE             3) MIGRATE & MODERNIZE
   - Inventory apps     - Build landing zone    - Migrate in waves
   - Business case      - Skills & governance   - Validate & cut over
   - TCO / readiness    - Pilot migration       - Optimize cost & perf
```

**Helpful AWS tools:**
- **AWS Migration Hub** — track migration progress across tools.
- **AWS Application Migration Service (MGN)** — automated lift-and-shift to EC2.
- **AWS Database Migration Service (DMS)** — migrate databases with minimal downtime.
- **AWS DataSync / Snowball** — move large data sets (Snowball = physical device for huge/offline transfers).
- **AWS Migration Evaluator** — build the business case / TCO.

---

## Example 1 — Rehost: Traditional Web App (Lift & Shift)

**Before (on-prem):**
```
   [Physical web server] + [Physical MySQL server] in a server room
```
**Migration:** Use **AWS Application Migration Service** to replicate servers into **EC2**. Keep the same OS and app.

**After:**
```
   [EC2 web server] ---- [EC2 MySQL server]   (in one AZ to start)
```
**Result:** Fast move (weeks), no code changes. Optimize later (add Auto Scaling, move DB to RDS).

**Strategy:** Rehost. **Best when:** speed matters, app can't be changed yet.

---

## Example 2 — Replatform: Move Database to Managed RDS

**Before:** Self-managed MySQL on an EC2 instance — you patch, back up, and scale it manually.

**Migration:** Use **AWS DMS** to migrate data to **Amazon RDS for MySQL** with Multi-AZ.

**After:**
```
   [EC2 web tier] ---> [Amazon RDS MySQL Multi-AZ]
                        (AWS handles patching, backups, failover)
```
**Result:** Less operational work, automatic backups, high availability. Minimal app change (just the DB endpoint).

**Strategy:** Replatform. **Best when:** you want managed-service benefits without rewriting the app.

---

## Example 3 — Refactor: Monolith to Serverless

**Before:** A single large monolithic application on one big server; hard to scale, costly idle time.

**Migration:** Re-architect into cloud-native components:
```
   API Gateway ---> AWS Lambda (functions) ---> DynamoDB
        |                |                          
   CloudFront        S3 (static front-end)         
```
**Result:** Pay only per request, scales automatically to zero and to millions, no servers to manage.

**Strategy:** Refactor / Re-architect. **Best when:** long-term agility and cost-efficiency are the goal and you can invest engineering effort.

---

## Example 4 — Hybrid / Phased: Enterprise Gradual Migration

**Scenario:** A large enterprise can't move everything at once.

**Approach:**
1. **Retire** unused legacy apps (free quick wins).
2. **Retain** a compliance-locked system on-prem (for now).
3. **Rehost** general web apps to EC2.
4. **Replatform** databases to RDS.
5. **Repurchase** email/CRM as SaaS.
6. Connect on-prem to AWS with **Direct Connect** during the transition (hybrid).

```
   ON-PREM (shrinking)            AWS (growing)
   +------------------+   DX/VPN  +-------------------------+
   | Compliance app   |<========> | EC2 web, RDS, S3, SaaS  |
   | (Retain)         |           | (Rehost/Replatform/...) |
   +------------------+           +-------------------------+
   Over time, more workloads move right.
```
**Result:** Risk-managed, wave-by-wave migration with no "big bang" outage.

---

## Migration Cost & Risk Tips
- 💰 Start with **Retire/Retain** decisions — don't pay to migrate things you can delete.
- 💰 Rehost first to exit the data center, then **optimize** (replatform/refactor) once in AWS.
- 🔒 Build a secure **landing zone** (accounts, IAM, logging, guardrails) before migrating at scale.
- ⚠️ Always run a **pilot** wave before mass migration.
- 📊 Use **Migration Evaluator** for a TCO business case to justify the move.

---

➡️ Next: [05-aws-account-setup-guide.md](05-aws-account-setup-guide.md)

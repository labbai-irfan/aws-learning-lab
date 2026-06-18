# Module 6 — Backup Strategy & Disaster Recovery

> Building a backup strategy with RPO/RTO targets, and a disaster-recovery plan across AZs and Regions.

---

## 1. The vocabulary: RPO and RTO

- **RPO (Recovery Point Objective)** — *how much data can you afford to lose?* (the age of the last good recovery point). RDS automated backups give RPO ≈ **5 minutes** (transaction logs every ~5 min).
- **RTO (Recovery Time Objective)** — *how fast must you be back up?* Restoring a snapshot to a new instance takes minutes–hours depending on size; failover is seconds.

```
   <----------- RPO --------->|          |<--------- RTO --------->
   last good backup        incident    recovery starts        back online
```

---

## 2. Backup strategy (layered)

| Layer | Mechanism | RPO | Retention |
|---|---|---|---|
| Continuous | Automated backups + transaction logs → **PITR** | ~5 min | 1–35 days |
| Daily | Automated snapshot in backup window | 1 day | within retention |
| Milestone | **Manual snapshots** (before migrations/releases) | point-in-time | until deleted |
| Long-term | Snapshot **export to S3 (Parquet)** / copy to vault account | — | months–years |
| DR | **Cross-region** snapshot copy / read replica | minutes | as configured |

### Recommended baseline for production
- Automated backup retention: **7–14 days** (35 for compliance-heavy).
- **Manual snapshot** before every schema migration and major version upgrade.
- **Cross-region snapshot copy** (automated, daily) for regional DR.
- Enable **deletion protection** and **final snapshot on delete**.

🛠️ Automate retention + window:
```bash
aws rds modify-db-instance --db-instance-identifier hrms-db \
  --backup-retention-period 14 \
  --preferred-backup-window 03:00-03:30 \
  --deletion-protection --apply-immediately
```

🛠️ Automated cross-region copy with AWS Backup (preferred for org-wide policy):
- Create an **AWS Backup plan** → rule with a schedule, lifecycle (cold/expire), and a **copy action** to the DR Region.
- Assign resources by tag (e.g. `Backup=prod`).

---

## 3. Restore mechanics (recap)

Every restore creates a **new instance** — you never restore in place. After restore, **repoint the app endpoint** and re-apply security group / parameter group (a restored instance gets the **default** parameter group unless you specify yours).

| Scenario | Use |
|---|---|
| Bad `DELETE` 20 min ago | **PITR** to just before it → extract rows |
| Corrupt instance | Restore latest **snapshot** to new instance |
| Region down | Promote **cross-region replica** or restore copied snapshot |
| Clone for staging | Restore prod snapshot → scrub PII |

⚠️ Restored instances start with **default config** — remember to attach your custom parameter group, security group, Multi-AZ setting, and re-enable backups.

---

## 4. Disaster Recovery strategies (and their cost/RTO trade-offs)

```
   Cheaper / slower RTO  <------------------------------>  Costlier / faster RTO
   Backup & Restore   Pilot Light   Warm Standby   Multi-Region Active-Active
```

| Strategy | How | RTO | RPO | Cost |
|---|---|---|---|---|
| **Backup & Restore** | Copy snapshots to DR Region; restore on disaster | Hours | Minutes–hours | $ |
| **Pilot Light** | Cross-region read replica kept small/stopped; promote on disaster | 10s of min | Seconds–min | $$ |
| **Warm Standby** | Smaller live stack + replica in DR; scale up on failover | Minutes | Seconds | $$$ |
| **Active-Active** | Full stack in both Regions (Aurora Global / app-level) | Near-zero | Near-zero | $$$$ |

For most apps (and the HRMS capstone), **Pilot Light with a cross-region read replica** is the sweet spot.

### Cross-region read replica DR flow
1. Create a **cross-region read replica** in the DR Region (encrypted with a DR KMS key).
2. It stays in sync asynchronously.
3. On regional disaster: **promote** the replica to standalone primary.
4. Repoint Route 53 / app config to the DR endpoint.
5. Rebuild a new replica/Multi-AZ in the DR Region for ongoing HA.

🛠️
```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier hrms-db-dr \
  --source-db-instance-identifier arn:aws:rds:us-east-1:123:db:hrms-db \
  --region us-west-2 --kms-key-id alias/rds-dr-key

# On disaster:
aws rds promote-read-replica \
  --db-instance-identifier hrms-db-dr --region us-west-2
```

💡 **Aurora Global Database** does this natively with ~1s cross-region replication and ~1 min failover — consider it if RTO/RPO must be very tight.

---

## 5. Testing your DR (the step everyone skips)
- **Quarterly game day:** actually restore a snapshot / promote a replica into an isolated VPC and run smoke tests. A backup you've never restored is a hope, not a plan.
- Document the runbook: who, what commands, expected RTO, how to repoint the app, how to fail back.
- Measure actual RTO/RPO and compare to targets.

---

## 6. Backup/DR checklist
- [ ] Automated backups ≥7d, window set off-peak
- [ ] Manual snapshot before every risky change
- [ ] Deletion protection + final snapshot on delete
- [ ] Cross-region snapshot copy or replica for DR
- [ ] Encryption keys exist in the DR Region (KMS keys are regional!)
- [ ] DR runbook written and **rehearsed** (RTO measured)
- [ ] Restores validated (row counts, app tests)
- [ ] Long-term/compliance copies exported to S3 if required

⚠️ **KMS keys are Region-specific.** A snapshot encrypted with a us-east-1 key must be **re-encrypted with a us-west-2 key** during cross-region copy, or the copy fails.

➡️ Next: [Module 7 — Scaling & Cost Optimization](07-scaling-and-cost-optimization.md)

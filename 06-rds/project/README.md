# Capstone Project — Deploy an HRMS MySQL Database on Amazon RDS

> Build the production database tier for an **HRMS (Human Resource Management System)**: a Multi-AZ MySQL 8.0 instance on RDS, with a read replica for reporting, automated backups + PITR, Secrets Manager credentials, a Node.js/Prisma API, and a tested DR plan.

**Time:** 6+ hours · **Cost:** a few dollars if you tear down (use `db.t4g` and delete at the end).

---

## 🎯 What you'll build

```
   Internet ─► ALB ─► EC2 (Node.js + Prisma API, PM2) ──writes──┐
                                                                │
   AZ-a  ┌─────────────────────────────────────────────┐       ▼
         │  RDS MySQL 8.0 PRIMARY  ══sync══►  STANDBY (AZ-b)  Multi-AZ
         │        │ async                                  │
         │        ▼                                         │
         │  READ REPLICA (AZ-c) ◄── HR reporting/payroll analytics
         └─────────────────────────────────────────────────┘
   Backups (7d) + manual snapshots + PITR · Secrets Manager · KMS · CloudWatch
```

**The HRMS data model:** departments, employees, attendance, leave requests, payroll, and audit log.

---

## 📋 Architecture decisions

| Decision | Choice | Why |
|---|---|---|
| Engine | MySQL 8.0 | Classic relational CRUD with transactions; framework default |
| Class | `db.r6g.large` (prod) / `db.t4g.micro` (lab) | Memory for buffer pool; Graviton cost |
| HA | Multi-AZ | Auto failover for payroll-critical data |
| Reads | 1 read replica | Offload reporting from OLTP |
| Storage | gp3, 100 GB autoscale→500 | Decoupled IOPS, room to grow |
| Backups | 7 days + manual pre-release snapshots | PITR for accidental payroll edits |
| Security | Private subnets, SG from app only, KMS, TLS, Secrets Manager | Defense in depth |
| Access | Prisma over connection pool (+ RDS Proxy optional) | Stable connections |

---

## Step 1 — Network & security prerequisites
Use the VPC from Phase 04 (or create one) with:
- 2 public subnets (ALB), 2 private-app subnets (EC2), **≥2 private-db subnets** (AZ-a, AZ-b, AZ-c).
- Security groups:
```
ALB-SG : inbound 443 from 0.0.0.0/0
APP-SG : inbound 3000 from ALB-SG
DB-SG  : inbound 3306 from APP-SG   ← only the app can reach MySQL
```
🛠️ DB subnet group:
```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name hrms-subnets \
  --db-subnet-group-description "HRMS private DB subnets" \
  --subnet-ids subnet-dbA subnet-dbB subnet-dbC
```

## Step 2 — Parameter group (tuning)
🛠️
```bash
aws rds create-db-parameter-group \
  --db-parameter-group-name hrms-mysql8 \
  --db-parameter-group-family mysql8.0 --description "HRMS tuning"

aws rds modify-db-parameter-group --db-parameter-group-name hrms-mysql8 \
  --parameters \
   "ParameterName=character_set_server,ParameterValue=utf8mb4,ApplyMethod=immediate" \
   "ParameterName=collation_server,ParameterValue=utf8mb4_0900_ai_ci,ApplyMethod=immediate" \
   "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
   "ParameterName=long_query_time,ParameterValue=2,ApplyMethod=immediate" \
   "ParameterName=require_secure_transport,ParameterValue=ON,ApplyMethod=immediate" \
   "ParameterName=time_zone,ParameterValue=UTC,ApplyMethod=immediate"
```

## Step 3 — Launch the Multi-AZ primary
🛠️
```bash
aws rds create-db-instance \
  --db-instance-identifier hrms-db \
  --db-instance-class db.t4g.micro \
  --engine mysql --engine-version 8.0.39 \
  --allocated-storage 100 --max-allocated-storage 500 --storage-type gp3 \
  --master-username hrms_admin --manage-master-user-password \
  --db-subnet-group-name hrms-subnets \
  --vpc-security-group-ids sg-DB \
  --db-parameter-group-name hrms-mysql8 \
  --backup-retention-period 7 --preferred-backup-window 03:00-03:30 \
  --storage-encrypted --kms-key-id alias/aws/rds \
  --multi-az --no-publicly-accessible \
  --enable-performance-insights --deletion-protection
```
✅ Wait for `available`. The master password is now in **Secrets Manager** (`--manage-master-user-password`).

## Step 4 — Create schema and least-privilege users
Connect from the app/bastion EC2 and run [`schema.sql`](schema.sql):
```bash
mysql -h hrms-db.xxxx.us-east-1.rds.amazonaws.com -u hrms_admin -p < schema.sql
```
Then create the app users:
```sql
SQL> CREATE USER 'hrms_app'@'%' IDENTIFIED BY 'STORE-IN-SECRETS-MANAGER';
SQL> GRANT SELECT, INSERT, UPDATE, DELETE ON hrms.* TO 'hrms_app'@'%';
SQL> CREATE USER 'hrms_ro'@'%' IDENTIFIED BY 'STORE-IN-SECRETS-MANAGER';
SQL> GRANT SELECT ON hrms.* TO 'hrms_ro'@'%';
SQL> FLUSH PRIVILEGES;
```

## Step 5 — Add a read replica (reporting)
🛠️
```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier hrms-db-replica \
  --source-db-instance-identifier hrms-db \
  --db-instance-class db.t4g.micro \
  --enable-performance-insights
```
Reporting/analytics queries use the replica endpoint with the `hrms_ro` user.

## Step 6 — Wire up the Node.js + Prisma API
See [`prisma/schema.prisma`](prisma/schema.prisma) and [`db.ts`](db.ts).
```bash
npm install @prisma/client @aws-sdk/client-secrets-manager
npm install -D prisma
npx prisma db pull        # introspect the schema you created
npx prisma generate
```
- `DATABASE_URL_PRIMARY` → primary endpoint (`hrms_app`) for writes.
- `DATABASE_URL_REPLICA` → replica endpoint (`hrms_ro`) for reports.
- Credentials fetched from Secrets Manager at boot (no `.env` secrets in prod).

## Step 7 — Monitoring & alarms
- Performance Insights is on. Export slow query + error logs to CloudWatch Logs.
- Create alarms (CPU, FreeStorageSpace, FreeableMemory, DatabaseConnections, ReplicaLag) — see [Module 9](../09-monitoring-guide.md).
- RDS event subscription → SNS for failover/low-storage.

## Step 8 — Backup & DR setup
- Confirm automated backups (7d) and take a milestone snapshot before go-live:
  ```bash
  aws rds create-db-snapshot --db-instance-identifier hrms-db \
    --db-snapshot-identifier hrms-db-golive
  ```
- Cross-region snapshot copy for DR:
  ```bash
  aws rds copy-db-snapshot \
    --source-db-snapshot-identifier arn:aws:rds:us-east-1:ACCT:snapshot:hrms-db-golive \
    --target-db-snapshot-identifier hrms-db-golive-dr \
    --source-region us-east-1 --region us-west-2 --kms-key-id alias/aws/rds
  ```

## Step 9 — Test failover & restore (don't skip)
```bash
# Failover test: keep a query loop running, then:
aws rds reboot-db-instance --db-instance-identifier hrms-db --force-failover

# PITR drill: simulate a bad payroll DELETE, then restore to before it:
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier hrms-db \
  --target-db-instance-identifier hrms-db-pitr \
  --restore-time <ISO-8601-just-before-the-delete>
```
✅ Confirm the app reconnects after failover and the lost rows exist on the PITR instance.

---

## ✅ Acceptance criteria
- [ ] Multi-AZ MySQL 8.0 instance, private, encrypted, backups 7d
- [ ] Read replica serving reporting reads
- [ ] Custom parameter group (utf8mb4, slow log, TLS forced)
- [ ] App connects via Prisma with Secrets Manager creds + TLS
- [ ] Read/write split working (writes→primary, reports→replica)
- [ ] Alarms + Performance Insights + event subscription live
- [ ] Forced failover tested; app recovered
- [ ] PITR drill recovered a "deleted" payroll row
- [ ] Cross-region snapshot copy exists
- [ ] Deletion protection ON

## 🧹 Teardown
```bash
aws rds modify-db-instance --db-instance-identifier hrms-db --no-deletion-protection --apply-immediately
for db in hrms-db-replica hrms-db-pitr hrms-db; do
  aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups; done
aws rds delete-db-snapshot --db-snapshot-identifier hrms-db-golive
aws rds delete-db-snapshot --db-snapshot-identifier hrms-db-golive-dr --region us-west-2
```

## 📁 Files in this project
- [`schema.sql`](schema.sql) — HRMS tables, indexes, seed data
- [`prisma/schema.prisma`](prisma/schema.prisma) — Prisma data model
- [`db.ts`](db.ts) — Prisma clients + Secrets Manager credential loader

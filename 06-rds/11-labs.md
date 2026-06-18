# Module 11 — Hands-on Labs

> Do these in order in a throwaway VPC. 💰 Tear down at the end — use `db.t4g.micro`, single-AZ where noted, and delete when done.

**Setup once:** a VPC with 2+ private subnets in different AZs, a bastion/EC2 to run `mysql`, and a DB security group.

---

## Lab 1 — Launch your first RDS MySQL instance
**Goal:** create a private MySQL 8.0 instance and connect.
```bash
aws rds create-db-subnet-group --db-subnet-group-name lab-subnets \
  --db-subnet-group-description "lab" --subnet-ids subnet-a subnet-b

aws rds create-db-instance \
  --db-instance-identifier lab-mysql \
  --db-instance-class db.t4g.micro \
  --engine mysql --engine-version 8.0.39 \
  --allocated-storage 20 --storage-type gp3 \
  --master-username admin --manage-master-user-password \
  --db-subnet-group-name lab-subnets \
  --vpc-security-group-ids sg-xxxx \
  --backup-retention-period 1 --no-publicly-accessible
```
✅ **Verify:** `aws rds describe-db-instances --db-instance-identifier lab-mysql --query 'DBInstances[0].DBInstanceStatus'` → `available`; connect from the bastion with `mysql -h <endpoint> -u admin -p`.

---

## Lab 2 — Parameter group tuning
**Goal:** enable the slow query log without OS access.
```bash
aws rds create-db-parameter-group --db-parameter-group-name lab-pg \
  --db-parameter-group-family mysql8.0 --description lab
aws rds modify-db-parameter-group --db-parameter-group-name lab-pg \
  --parameters "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
               "ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate"
aws rds modify-db-instance --db-instance-identifier lab-mysql \
  --db-parameter-group-name lab-pg --apply-immediately
```
✅ **Verify:** `SHOW VARIABLES LIKE 'slow_query_log';` → `ON`. Run a `SELECT SLEEP(2);` and confirm it appears in the slow log (export logs to CloudWatch).

---

## Lab 3 — Convert to Multi-AZ and test failover
```bash
aws rds modify-db-instance --db-instance-identifier lab-mysql --multi-az --apply-immediately
# wait until available, then force a failover:
aws rds reboot-db-instance --db-instance-identifier lab-mysql --force-failover
```
✅ **Verify:** keep a `SELECT NOW();` loop running; observe the brief drop and automatic reconnect. Check events for `Multi-AZ failover`.

---

## Lab 4 — Create and use a read replica
```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier lab-mysql-replica \
  --source-db-instance-identifier lab-mysql --db-instance-class db.t4g.micro
```
✅ **Verify:** write on the primary, read it on the replica endpoint. Watch `ReplicaLag` in CloudWatch. Try writing on the replica → fails (read-only).

---

## Lab 5 — Snapshot, then restore to a new instance
```bash
aws rds create-db-snapshot --db-instance-identifier lab-mysql \
  --db-snapshot-identifier lab-snap-1
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier lab-mysql-restored --db-snapshot-identifier lab-snap-1
```
✅ **Verify:** restored instance has your data. ⚠️ Note it came back with the **default** parameter group — re-attach `lab-pg`.

---

## Lab 6 — Point-in-time recovery
1. Insert a row, note the time. Wait 6+ minutes.
2. `DELETE` the row ("accident").
3. PITR to just before the delete:
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier lab-mysql \
  --target-db-instance-identifier lab-mysql-pitr \
  --restore-time 2026-06-17T14:30:00Z
```
✅ **Verify:** the row exists on `lab-mysql-pitr`. Practice extracting it and re-inserting into the live DB.

---

## Lab 7 — Encryption & TLS
- Launch a **new** encrypted instance (`--storage-encrypted --kms-key-id alias/aws/rds`). ⚠️ Confirm you can't encrypt `lab-mysql` in place.
- Force TLS: set `require_secure_transport=ON` in the parameter group; connect with `--ssl-mode=REQUIRED` and verify a non-TLS connection is rejected.

---

## Lab 8 — Cross-region snapshot copy (DR)
```bash
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:123:snapshot:lab-snap-1 \
  --target-db-snapshot-identifier lab-snap-dr \
  --source-region us-east-1 --region us-west-2 \
  --kms-key-id alias/aws/rds
```
✅ **Verify:** the snapshot appears in us-west-2; restore it there. Note the KMS key had to be a **us-west-2** key.

---

## Lab 9 — Monitoring & alarm
- Enable **Performance Insights**. Run a deliberately slow scan; find it in Top SQL; add an index; watch DB Load drop.
- Create a `FreeStorageSpace` alarm (see [Module 9](09-monitoring-guide.md)).

---

## Lab 10 — Connection pool stress
- From a script, open 200 connections without closing → hit `Too many connections`.
- Re-run through Prisma with `connection_limit=10` → stable. (Bonus: front it with RDS Proxy.)

---

## 🧹 Teardown
```bash
for db in lab-mysql lab-mysql-replica lab-mysql-restored lab-mysql-pitr; do
  aws rds delete-db-instance --db-instance-identifier $db \
    --skip-final-snapshot --delete-automated-backups; done
aws rds delete-db-snapshot --db-snapshot-identifier lab-snap-1
```
💰 Confirm in the console nothing is left running. Delete the DR snapshot in us-west-2 too.

➡️ Next: [Module 12 — 100 MCQs](12-100-mcqs.md)

# Module 4 — Migration from Local MySQL to RDS

> Two paths: simple **mysqldump** (downtime-tolerant) and **AWS DMS** (near-zero downtime). With validation and cutover.

---

## Decide your migration path

| Method | Downtime | Data size | Use when |
|---|---|---|---|
| **mysqldump / mysqlpump** | Minutes–hours | < ~20 GB | Small DB, a maintenance window is OK |
| **Physical (Percona XtraBackup → S3)** | Low | Large | Big MySQL DB, faster than logical dump |
| **AWS DMS** | **Near-zero** | Any | Can't afford downtime; ongoing replication during cutover |

---

## Path A — mysqldump (simple, with a short downtime window)

### 1. Pre-flight
- Create the RDS instance (MySQL 8.0, Multi-AZ, private). Get its endpoint.
- Ensure your EC2/bastion can reach RDS (DB-SG allows 3306 from the bastion SG).
- Match charset: use `utf8mb4` on RDS to match a modern local DB.

### 2. Dump the local database
🛠️
```bash
# --single-transaction = consistent snapshot without locking InnoDB tables
mysqldump \
  --single-transaction --routines --triggers --events \
  --set-gtid-purged=OFF \
  -h 127.0.0.1 -u root -p hrms > hrms_dump.sql
```
⚠️ `--set-gtid-purged=OFF` avoids GTID errors when importing into RDS (you don't control RDS GTID state).
⚠️ RDS has **no SUPER privilege** — strip `DEFINER=` clauses from triggers/views if the dump fails on import:
```bash
sed -i 's/DEFINER=[^*]*\*/\*/g' hrms_dump.sql
```

### 3. Import into RDS
🛠️
```bash
mysql -h hrms-db.abc123.us-east-1.rds.amazonaws.com -u admin -p hrms < hrms_dump.sql
```
💡 For large dumps, run from an **EC2 instance in the same Region/AZ** (not your laptop) — far faster and avoids timeouts.

### 4. Create the app user (least privilege)
```sql
SQL> CREATE USER 'hrms_app'@'%' IDENTIFIED BY 'use-secrets-manager';
SQL> GRANT SELECT, INSERT, UPDATE, DELETE ON hrms.* TO 'hrms_app'@'%';
SQL> FLUSH PRIVILEGES;
```

### 5. Cutover
1. Put the app in maintenance mode (stop writes).
2. Run a final incremental dump/import (or full if quick).
3. Point the app's `DATABASE_URL` at the RDS endpoint.
4. Smoke test, then lift maintenance mode.

---

## Path B — AWS DMS (near-zero downtime)

Use DMS when you can't take a long outage. DMS does a **full load** then **CDC (change data capture)** to keep RDS in sync with the live source until cutover.

```
   Local MySQL (source)  ──► DMS Replication Instance ──►  RDS MySQL (target)
        (binlog/CDC)              full load + ongoing            (kept in sync)
```

### Steps
1. **Enable binlog** on the source (`binlog_format = ROW`, retain logs) so DMS can capture changes.
2. Create a **DMS replication instance** (in the VPC that can reach both source and target).
3. Create **source** and **target endpoints**; test connections.
4. Create a **migration task**: *Migrate existing data and replicate ongoing changes*.
5. Start the task → monitor **full load** then **CDC latency** ≈ 0.
6. **Validate** (DMS data validation flags row mismatches).
7. **Cutover:** stop app writes → wait for CDC to drain → repoint app to RDS → resume.

💡 DMS migrates **data**, not schema objects like secondary indexes/foreign keys optimally — use the **AWS Schema Conversion Tool (SCT)** or a `mysqldump --no-data` to pre-create the schema, then DMS for the data.

---

## Validation (do this for either path)

```sql
-- Row counts per table must match source vs target
SQL> SELECT table_name, table_rows
     FROM information_schema.tables
     WHERE table_schema = 'hrms' ORDER BY table_name;

-- Spot-check checksums on critical tables
SQL> CHECKSUM TABLE hrms.employees, hrms.payroll;
```
- Compare row counts, run app integration tests against RDS, verify charset/collation, verify foreign keys and triggers exist.

---

## Common migration gotchas ⚠️
- **DEFINER / SUPER**: RDS forbids SUPER — strip DEFINERs (above).
- **GTID mismatch**: use `--set-gtid-purged=OFF`.
- **`local_infile`**: disabled by default on RDS — enable via parameter group if you use `LOAD DATA LOCAL INFILE`.
- **Time zone**: RDS defaults to **UTC**. Set `time_zone` parameter or store UTC and convert in the app.
- **Charset drift**: local `latin1` → RDS `utf8mb4` can corrupt characters. Convert explicitly.
- **Users & grants don't transfer** with `mysqldump` of a single DB — recreate users on RDS.
- **Max packet size**: bump `max_allowed_packet` on RDS for large rows/BLOBs.

➡️ Next: [Module 5 — Prisma Integration + Connection Pooling](05-prisma-and-connection-pooling.md)

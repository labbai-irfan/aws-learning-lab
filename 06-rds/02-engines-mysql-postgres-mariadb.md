# Module 2 — Engines: MySQL · PostgreSQL · MariaDB

> The three open-source engines RDS runs, how they differ, and how to choose. Plus RDS vs Aurora.

---

## At-a-glance comparison

| | **MySQL** | **PostgreSQL** | **MariaDB** |
|---|---|---|---|
| Default port | 3306 | 5432 | 3306 |
| RDS major versions | 8.0, 8.4 | 13–17 | 10.6, 10.11, 11.x |
| Personality | Simple, ubiquitous, web-default | Feature-rich, standards-compliant | MySQL fork, community-driven |
| JSON | `JSON` type, decent | **`jsonb` (indexable, powerful)** | `JSON` (alias of LONGTEXT) |
| Extensions | Plugins via option group | **Rich: PostGIS, pg_trgm, pgvector…** | Plugins, MySQL-compatible |
| Window functions / CTEs | Yes (8.0+) | Yes (mature) | Yes |
| Full-text / GIS | Basic | **Strong (PostGIS)** | Basic |
| Replication into RDS | Yes | Yes (logical) | Yes |
| Best for | Web apps, WordPress, HRMS, general CRUD | Complex queries, geospatial, analytics, vectors | Drop-in MySQL alt, open-source purists |

---

## MySQL on RDS
- The **most common** RDS engine; what most web frameworks (Laravel, Rails, Node/Prisma, Django) assume by default.
- Storage engine: **InnoDB** (transactional, row-level locking, foreign keys). Avoid MyISAM.
- Version note: **MySQL 5.7 reached end of standard support** — new deployments should use **8.0** (or 8.4 LTS). 8.0 adds CTEs, window functions, better JSON, and `utf8mb4` defaults.
- 💡 Always use **`utf8mb4`** charset and `utf8mb4_0900_ai_ci` (8.0) collation for full Unicode (emoji, multilingual names).
- This is the engine for the **HRMS capstone** ([project](project/README.md)).

🛠️ Connect:
```bash
mysql -h hrms-db.abc123.us-east-1.rds.amazonaws.com -P 3306 -u admin -p
```

## PostgreSQL on RDS
- The pick when you need **advanced SQL**: `jsonb`, arrays, CTEs, window functions, `GENERATED` columns, partial/expression indexes, materialized views.
- **Extensions** are the superpower: `PostGIS` (geospatial), `pg_stat_statements` (query stats), `pg_trgm` (fuzzy search), **`pgvector`** (AI/embeddings), `uuid-ossp`.
- Stronger standards compliance and stricter typing than MySQL.
- 💡 Enable `pg_stat_statements` via parameter group + `shared_preload_libraries` — essential for query tuning.

🛠️ Connect:
```bash
psql "host=app-db.abc123.us-east-1.rds.amazonaws.com port=5432 dbname=app user=admin sslmode=require"
```

## MariaDB on RDS
- A **community fork of MySQL** (created by MySQL's original authors after the Oracle acquisition). Largely wire/protocol compatible with MySQL.
- Differences: some engines/features unique to MariaDB (e.g. `ColumnStore`, Aria, different optimizer, audit plugin built-in), version numbering diverges from MySQL.
- Choose it if you want an **open-governance** alternative to Oracle-owned MySQL, or specific MariaDB features. For most teams MySQL 8 is the safer default due to ecosystem/tooling.

---

## How to choose (decision guide)

```
Need geospatial / vectors / heavy analytical SQL / jsonb?  -> PostgreSQL
Standard web/CRUD app, framework defaults to MySQL?        -> MySQL 8.0
Want open-governance MySQL fork / specific MariaDB feature?-> MariaDB
Need >100k IOPS, 15 replicas, fastest failover, serverless?-> Aurora
```

For the **HRMS** app (employees, payroll, leave, attendance — classic relational CRUD with transactions), **MySQL 8.0** is the natural choice.

---

## RDS vs Aurora (know the difference for interviews)

| | RDS (MySQL/PG/MariaDB) | **Aurora** (MySQL/PG-compatible) |
|---|---|---|
| Storage | EBS attached to one instance | Distributed, 6 copies across 3 AZs, auto-grows to 128 TB |
| Read replicas | Up to 15, async | Up to 15, **share storage**, ~ms lag |
| Failover | 60–120s (Multi-AZ) | **~30s or less** |
| Throughput | Standard | ~3–5× MySQL on same hardware |
| Serverless | No | **Aurora Serverless v2** (auto-scale capacity) |
| Backups | Snapshots + PITR | Continuous to S3, PITR, fast clones |
| Cost | Lower | Higher (pay for performance + I/O or I/O-Optimized) |
| When | Cost-sensitive, standard load, lift-and-shift | High scale, spiky, need fast failover / serverless |

💡 Aurora is **API/CLI-compatible** with RDS — same `aws rds` commands, `--engine aurora-mysql`. Migrating RDS MySQL → Aurora MySQL is supported via snapshot/replica.

⚠️ Aurora's cost model includes **I/O charges** (standard) — for I/O-heavy workloads consider **Aurora I/O-Optimized** for predictable pricing.

---

## Engine version & upgrade notes
- **Minor version upgrades** (8.0.39 → 8.0.40): can be auto-applied in the maintenance window. Low risk.
- **Major version upgrades** (5.7 → 8.0, or PG 15 → 16): **manual, test first** — possible breaking changes. Take a snapshot before. Use the **major version upgrade pre-check** and a cloned/restored instance to rehearse.
- ⚠️ AWS **deprecates** old versions on a schedule; if you don't upgrade, AWS may force an automatic upgrade. Track the engine version deprecation calendar.

➡️ Next: [Module 3 — Production Database Architecture](03-production-architecture.md)

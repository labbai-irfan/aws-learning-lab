# Module 8 — RDS Security Deep Dive

> Defense in depth for RDS: network, IAM/auth, encryption, secrets, auditing, and compliance.

---

## The layers

```
  ┌─ Network ──── private subnets · security groups · no public access
  ├─ Identity ─── master user · least-privilege DB users · IAM auth
  ├─ Secrets ──── Secrets Manager rotation · no hardcoded creds
  ├─ Encryption ─ KMS at rest · TLS in transit
  ├─ Audit ────── CloudTrail · CloudWatch Logs · audit plugin
  └─ Governance ─ AWS Config rules · deletion protection · backups
```

---

## 1. Network security
- 🔒 **Private subnets only.** `--no-publicly-accessible`. No route to IGW.
- **Security group** inbound: DB port **only from the app SG** (reference the SG, not a CIDR).
- ⚠️ Never `0.0.0.0/0` on 3306/5432. The #1 RDS breach cause is a publicly exposed instance.
- Use a **bastion host / SSM Session Manager** for DBA access — not public access.
- **VPC endpoints** for Secrets Manager / KMS so app→AWS traffic stays private.

```
   Internet --X--> (no route)
   App-SG  --3306--> DB-SG  (source = App-SG only)
   DBA --> SSM/bastion --> DB-SG
```

## 2. Authentication & authorization
- **Master user**: bootstrap only. Don't let the app use it.
- Create **least-privilege app users**:
  ```sql
  SQL> CREATE USER 'hrms_app'@'%' IDENTIFIED BY '...';
  SQL> GRANT SELECT, INSERT, UPDATE, DELETE ON hrms.* TO 'hrms_app'@'%';
  -- read-only reporting user for the replica:
  SQL> CREATE USER 'hrms_ro'@'%' IDENTIFIED BY '...';
  SQL> GRANT SELECT ON hrms.* TO 'hrms_ro'@'%';
  ```
- **IAM database authentication**: app requests a **15-min token** instead of a password.
  - Enable on the instance, create a DB user `IDENTIFIED WITH AWSAuthenticationPlugin`, grant the EC2/ECS role `rds-db:connect`.
  - 🔒 No long-lived passwords; great for short-lived compute. ⚠️ Token has a connection-rate limit — combine with pooling/RDS Proxy.

## 3. Secrets management
- `--manage-master-user-password` → RDS stores the master secret in **Secrets Manager** and rotates it.
- App fetches credentials at runtime (see [Module 5](05-prisma-and-connection-pooling.md)); EC2/ECS role grants `secretsmanager:GetSecretValue`.
- **Rotation** on a schedule (e.g. 30 days). Handle reconnect on rotation.

## 4. Encryption
**At rest (KMS):**
- Enable **at creation** — covers instance, automated backups, snapshots, and read replicas.
- ⚠️ Cannot encrypt an existing **unencrypted** instance in place. Path: snapshot → **copy snapshot with encryption** → restore → cut over.
- Use **customer-managed KMS keys (CMK)** for key policy control and cross-account/region DR.

**In transit (TLS):**
- Download the **RDS CA bundle** (`rds-combined-ca-bundle.pem`).
- Enforce server-side: MySQL/MariaDB `require_secure_transport=ON`; PostgreSQL `rds.force_ssl=1`.
- Client: `sslaccept=strict` (Prisma) / `sslmode=verify-full` (psql).

## 5. Auditing & logging
- Publish **error, slow query, general, and audit logs** to **CloudWatch Logs**.
- **MariaDB/MySQL audit plugin** (via option group): logs connections, queries, DDL.
- **CloudTrail**: every RDS control-plane API call (who modified/deleted the instance).
- **Performance Insights**: also a security signal (unusual query patterns).

## 6. Governance & resilience controls
- **Deletion protection** ON (prevents accidental/ malicious delete).
- **Final snapshot** required on delete.
- **AWS Config** managed rules: `rds-instance-public-access-check`, `rds-storage-encrypted`, `rds-multi-az-support`, `rds-snapshots-public-prohibited`.
- ⚠️ Never make a snapshot **public** — it exposes all your data.

---

## Production security checklist 🔒
- [ ] Private subnets, `publicly-accessible=false`
- [ ] DB-SG inbound only from App-SG (no `0.0.0.0/0`)
- [ ] Encryption at rest (KMS CMK) enabled at creation
- [ ] TLS enforced (`require_secure_transport` / `rds.force_ssl`)
- [ ] App uses least-privilege user, not master
- [ ] Credentials in Secrets Manager (rotating) or IAM auth
- [ ] Audit + error + slow logs → CloudWatch Logs
- [ ] Deletion protection + final snapshot
- [ ] AWS Config rules + CloudTrail enabled
- [ ] DBA access via SSM/bastion, not public

➡️ Next: [Module 9 — Monitoring & Performance](09-monitoring-guide.md)

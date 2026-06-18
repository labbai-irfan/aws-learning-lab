# Module 5 — Prisma Integration + Connection Pooling

> Connecting a Node.js/TypeScript app to RDS MySQL with Prisma, doing it securely, and managing connections so you don't exhaust `max_connections`.

---

## 1. Prisma + RDS quick start

### Install
```bash
npm install prisma --save-dev
npm install @prisma/client
npx prisma init --datasource-provider mysql
```

### `.env` — the connection string
```ini
# Never commit this. Load the password from Secrets Manager at runtime in prod.
DATABASE_URL="mysql://hrms_app:PASSWORD@hrms-db.abc123.us-east-1.rds.amazonaws.com:3306/hrms?connection_limit=10&pool_timeout=20&sslaccept=strict"
```

### `schema.prisma`
```prisma
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model Employee {
  id        Int      @id @default(autoincrement())
  empCode   String   @unique @map("emp_code")
  firstName String   @map("first_name")
  lastName  String   @map("last_name")
  email     String   @unique
  deptId    Int      @map("dept_id")
  department Department @relation(fields: [deptId], references: [id])
  createdAt DateTime @default(now()) @map("created_at")

  @@map("employees")
}

model Department {
  id        Int        @id @default(autoincrement())
  name      String
  employees Employee[]

  @@map("departments")
}
```

### Workflow
```bash
# You already migrated the schema in Module 4 -> introspect existing DB:
npx prisma db pull         # generate schema.prisma from the RDS database
npx prisma generate        # generate the typed client

# Or, greenfield -> author schema then:
npx prisma migrate deploy  # apply migrations to RDS (prod-safe, no prompts)
```
⚠️ Use `prisma migrate deploy` in CI/prod (non-interactive). `prisma migrate dev` is for local dev only — it can reset data.

---

## 2. The connection-pool problem on RDS

RDS has a finite `max_connections` (a formula of instance RAM — e.g. ~`{DBInstanceClassMemory/12582880}`, so a `db.t3.medium` ≈ ~340). Every app process opening many connections can **exhaust** that limit → `Too many connections` errors.

```
   10 app instances × 30 connections each = 300 connections
   db.t3.medium max_connections ≈ 340   →  near the cliff
```

### Three layers of pooling — know which you're using
1. **Driver/ORM pool (Prisma's built-in pool)** — per process. Set with `connection_limit`.
2. **App-level pool** (e.g. `mysql2` pool) — if you use raw queries.
3. **External proxy pool (RDS Proxy / PgBouncer)** — shared across all app instances. The real fix at scale.

### Prisma pool sizing
- Prisma's default `connection_limit` = `num_physical_cpus * 2 + 1`. Override explicitly:
  ```
  ...?connection_limit=10&pool_timeout=20
  ```
- **Budget:** `total_connections = app_instances × connection_limit` must stay **well under** `max_connections` (leave headroom for admin, replicas, failover).
- ⚠️ **Serverless (Lambda + Prisma)**: each concurrent Lambda = its own pool → connection storms. Use **RDS Proxy** (or Prisma Accelerate / `@prisma/adapter` with a proxy) and keep `connection_limit=1`.

---

## 3. RDS Proxy with Prisma (the scalable pattern)

```
   Lambda/EC2 fleet ─► RDS Proxy ─► pooled ─► RDS MySQL
```
- Point `DATABASE_URL` host at the **proxy endpoint** instead of the DB endpoint.
- RDS Proxy multiplexes thousands of client connections into a small pool of DB connections, and survives failover by holding connections.
- Auth: RDS Proxy pulls credentials from **Secrets Manager** and supports **IAM auth** — no password in the app.

🛠️ (high level)
```bash
aws rds create-db-proxy \
  --db-proxy-name hrms-proxy \
  --engine-family MYSQL \
  --auth '[{"AuthScheme":"SECRETS","SecretArn":"arn:aws:secretsmanager:...:hrms-db"}]' \
  --role-arn arn:aws:iam::...:role/rds-proxy-role \
  --vpc-subnet-ids subnet-a subnet-b
```

---

## 4. Read/write splitting in Prisma

Prisma talks to one URL per client. To split reads to a replica, instantiate **two clients**:
```ts
// db.ts
import { PrismaClient } from '@prisma/client';

export const dbWrite = new PrismaClient({
  datasources: { db: { url: process.env.DATABASE_URL_PRIMARY } },
});

export const dbRead = new PrismaClient({
  datasources: { db: { url: process.env.DATABASE_URL_REPLICA } },
});

// usage
await dbWrite.employee.create({ data: {...} });        // primary
const report = await dbRead.employee.findMany({...});  // replica
```
- Or use the official **`@prisma/extension-read-replicas`** extension to route automatically.
- ⚠️ **Read-after-write**: immediately reading a just-written row from a replica may miss it (lag). Route such reads to `dbWrite`.

---

## 5. Secure credential handling (no passwords in code)

Fetch the password from **Secrets Manager** at startup and build the URL:
```ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

async function buildDatabaseUrl() {
  const sm = new SecretsManagerClient({});
  const res = await sm.send(new GetSecretValueCommand({ SecretId: 'hrms-db' }));
  const { username, password, host, port, dbname } = JSON.parse(res.SecretString!);
  return `mysql://${username}:${encodeURIComponent(password)}@${host}:${port}/${dbname}?sslaccept=strict&connection_limit=10`;
}
process.env.DATABASE_URL = await buildDatabaseUrl();
```
- The EC2/ECS task role grants `secretsmanager:GetSecretValue` — no static keys.
- 🔒 With Secrets Manager **rotation** on, refresh the URL/reconnect when auth fails.

---

## 6. TLS to RDS from Prisma
- Download the **RDS CA bundle** and require strict SSL:
  ```
  DATABASE_URL="mysql://...:3306/hrms?sslaccept=strict&sslcert=/etc/ssl/rds-combined-ca-bundle.pem"
  ```
- Enforce server-side with parameter `require_secure_transport=ON`.

---

## 7. Production checklist (Prisma + RDS)
- [ ] `connection_limit` set; `app_instances × limit` < `max_connections` with headroom
- [ ] RDS Proxy in front if serverless or large/elastic fleet
- [ ] `prisma migrate deploy` in CI (never `migrate dev` in prod)
- [ ] Password from Secrets Manager, not `.env` committed
- [ ] TLS enforced (`sslaccept=strict`)
- [ ] Reads routed to replica where staleness is acceptable
- [ ] Graceful shutdown: `await prisma.$disconnect()` on SIGTERM
- [ ] Retry logic on transient/failover errors (P1001/P1017)

➡️ Next: [Module 6 — Backup, Snapshots, PITR & Disaster Recovery](06-backup-and-disaster-recovery.md)

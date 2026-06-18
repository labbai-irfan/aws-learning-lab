/**
 * HRMS database access layer.
 *
 * - Loads DB credentials from AWS Secrets Manager at startup (no secrets in code).
 * - Exposes TWO Prisma clients:
 *      dbWrite  -> Multi-AZ PRIMARY endpoint  (INSERT/UPDATE/DELETE, transactions)
 *      dbRead   -> READ REPLICA endpoint      (reporting / analytics SELECTs)
 * - Enforces TLS to RDS and a bounded connection pool.
 *
 * EC2/ECS task role must allow secretsmanager:GetSecretValue on the secrets below.
 */
import { PrismaClient } from '@prisma/client';
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';

interface DbSecret {
  username: string;
  password: string;
  host: string;
  port: number;
  dbname: string;
}

const sm = new SecretsManagerClient({});

async function getSecret(secretId: string): Promise<DbSecret> {
  const res = await sm.send(new GetSecretValueCommand({ SecretId: secretId }));
  if (!res.SecretString) throw new Error(`Secret ${secretId} has no value`);
  return JSON.parse(res.SecretString) as DbSecret;
}

function buildUrl(s: DbSecret, connectionLimit = 10): string {
  const pw = encodeURIComponent(s.password);
  // sslaccept=strict enforces TLS against the RDS CA bundle.
  return (
    `mysql://${s.username}:${pw}@${s.host}:${s.port}/${s.dbname}` +
    `?sslaccept=strict&connection_limit=${connectionLimit}&pool_timeout=20`
  );
}

let dbWrite: PrismaClient;
let dbRead: PrismaClient;

export async function initDb(): Promise<void> {
  // Secret IDs created by RDS (--manage-master-user-password) or your own app-user secrets.
  const primary = await getSecret(process.env.DB_SECRET_PRIMARY ?? 'hrms-app-primary');
  const replica = await getSecret(process.env.DB_SECRET_REPLICA ?? 'hrms-app-replica');

  dbWrite = new PrismaClient({
    datasources: { db: { url: buildUrl(primary) } },
    log: ['warn', 'error'],
  });
  dbRead = new PrismaClient({
    datasources: { db: { url: buildUrl(replica) } },
    log: ['warn', 'error'],
  });

  await dbWrite.$connect();
  await dbRead.$connect();
}

export function getWriteClient(): PrismaClient {
  if (!dbWrite) throw new Error('initDb() not called');
  return dbWrite;
}

export function getReadClient(): PrismaClient {
  if (!dbRead) throw new Error('initDb() not called');
  return dbRead;
}

// Release pooled connections cleanly so failover/restart doesn't leak them.
async function shutdown(): Promise<void> {
  await Promise.allSettled([dbWrite?.$disconnect(), dbRead?.$disconnect()]);
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

/* ------------------------------------------------------------------ *
 * Example usage
 * ------------------------------------------------------------------ */

// Write goes to the PRIMARY.
export async function recordPayroll(input: {
  employeeId: number;
  payPeriod: string;
  basic: number;
  allowances: number;
  deductions: number;
}) {
  const db = getWriteClient();
  return db.payroll.create({
    data: {
      employeeId: input.employeeId,
      payPeriod: input.payPeriod,
      basic: input.basic,
      allowances: input.allowances,
      deductions: input.deductions,
      netPay: input.basic + input.allowances - input.deductions,
    },
  });
}

// Heavy reporting read goes to the REPLICA (tolerates slight lag).
export async function monthlyPayrollReport(payPeriod: string) {
  const db = getReadClient();
  return db.payroll.findMany({
    where: { payPeriod },
    include: { employee: { include: { department: true } } },
    orderBy: { netPay: 'desc' },
  });
}

// Read-after-write: read from PRIMARY to avoid replica lag.
export async function getEmployeeFresh(id: number) {
  return getWriteClient().employee.findUnique({ where: { id } });
}

# 08 — Amazon DynamoDB (Serverless NoSQL Deep Dive)

> The fully-managed, serverless, key-value + document database that pairs naturally with Lambda. This is the **single most important data store for the AWS Developer Associate exam** and for real serverless apps.

**By the end you can:**
- Explain DynamoDB's data model and choose correct partition/sort keys.
- Decide between on-demand and provisioned capacity, and size RCUs/WCUs.
- Design Global/Local Secondary Indexes and avoid hot partitions.
- Use Streams, TTL, transactions, and DAX correctly.
- Model an HRMS access pattern with single-table design.

**Prerequisites:** [01 — Lambda](01-lambda-core-concepts.md), basic [02 — IAM & Security](../02-iam-security/README.md).

---

## 1. Why DynamoDB (and when NOT to use it)

| Use DynamoDB when… | Use RDS/Aurora instead when… |
|---|---|
| You know your **access patterns** up front | You need ad-hoc queries / complex JOINs |
| You need **single-digit-ms** latency at any scale | You need strong relational integrity & transactions across many tables |
| Traffic is **spiky** or unpredictable (scales to zero cost on-demand) | Reporting / analytics with aggregations |
| **Serverless** — no servers, patching, or capacity planning | Existing SQL app / team SQL expertise |

💡 **Exam framing:** "millions of requests, millisecond latency, key-based access, serverless" → **DynamoDB**. "Complex queries, JOINs, relational" → **RDS/Aurora**.

---

## 2. Data model

```
TABLE  (Employees)
 └── ITEM  (a row; up to 400 KB)
       ├── Partition Key (PK)   "EMP#123"     ← required, decides physical partition
       ├── Sort Key (SK)        "PROFILE"      ← optional, sorts items within a PK
       └── Attributes           name, dept, salary, ...  (schemaless per item)
```

- **No fixed schema** beyond the primary key. Every item can have different attributes.
- **Primary key options:**
  - **Simple** = partition key only (must be unique).
  - **Composite** = partition key + sort key (PK can repeat; PK+SK must be unique).
- **Attribute types:** scalar (S, N, B, BOOL, NULL), document (Map `M`, List `L`), set (SS, NS, BS).

### Partition key choice = the most important decision
DynamoDB hashes the partition key to pick a physical partition. **Even distribution = even performance.**

```
GOOD PK: userId, orderId, deviceId   (high cardinality, evenly accessed)
BAD  PK: status ("active"/"inactive") → only 2 values → HOT PARTITION
BAD  PK: today's date                 → all writes hit one partition
```

⚠️ A **hot partition** (one PK getting disproportionate traffic) causes throttling even when total table capacity looks fine. Fix with **write sharding** (append a random suffix `DATE#2026-06-18#7`) or a better key.

---

## 3. Capacity modes

| | **On-Demand** | **Provisioned** |
|---|---|---|
| Billing | Per request (pay-per-use) | Per RCU/WCU per hour |
| Scaling | Instant, automatic, to zero | You set capacity (+ optional auto scaling) |
| Best for | Spiky/unknown traffic, new apps, dev | Predictable, steady traffic at scale |
| Cost at scale | Higher per request | **Cheaper** if well-tuned |

### Capacity units (provisioned)
```
1 RCU = 1 strongly-consistent read/sec of up to 4 KB
      = 2 eventually-consistent reads/sec of up to 4 KB
1 WCU = 1 write/sec of up to 1 KB

Example: read 8 KB item, strongly consistent, 100/sec
  → ceil(8/4) = 2 RCU per read × 100 = 200 RCU
Same but eventually consistent → 100 RCU (half)
Transactional read → 2× → 400 RCU
```

💡 **Auto Scaling** (provisioned) adjusts RCU/WCU between min/max to hit a target utilization (e.g. 70%). It reacts in minutes — not for sudden spikes; for bursty traffic prefer **on-demand**.

---

## 4. Reads: Query vs Scan vs GetItem

```
GetItem  → fetch ONE item by full primary key            (cheapest)
Query    → items sharing a PARTITION KEY, optional SK condition  (efficient)
Scan     → reads the ENTIRE table, then filters           (avoid! expensive)
```

⚠️ **A `FilterExpression` runs AFTER the read** — you are billed for all items scanned/queried, not just the ones returned. Filtering ≠ indexing. Design indexes so you `Query`, never `Scan`.

- **Consistency:** reads are *eventually consistent* by default; pass `ConsistentRead=true` for strongly consistent (2× cost, single-region only, not on GSIs).
- **Pagination:** results capped at 1 MB; follow `LastEvaluatedKey`.
- **PartiQL:** SQL-like syntax (`SELECT * FROM Employees WHERE ...`) — convenient, but a `SELECT` with no key condition is still a Scan under the hood.

---

## 5. Secondary indexes

| | **LSI** (Local) | **GSI** (Global) |
|---|---|---|
| Key | Same PK, **different SK** | **Different PK** and SK |
| When created | **Only at table creation** | Anytime |
| Consistency | Strong or eventual | **Eventual only** |
| Capacity | Shares table's | **Its own** RCU/WCU |
| Limit | 5 per table | 20 per table (default) |

```
Base table:   PK=userId           SK=orderDate
GSI:          PK=status           SK=orderDate   → "all SHIPPED orders by date"
LSI:          PK=userId           SK=totalAmount → "this user's orders by amount"
```

⚠️ A GSI with **insufficient write capacity throttles the base table's writes**. ⚠️ GSIs only project the attributes you choose (KEYS_ONLY / INCLUDE / ALL) — querying a non-projected attribute forces a costly fetch.

---

## 6. Streams, TTL, Transactions, DAX

**DynamoDB Streams** — ordered change log (24h retention) of item-level modifications.
```
Item change → Stream → Lambda trigger
Use cases: replicate to OpenSearch, fan-out events, audit log, aggregations,
           Global Tables (cross-region replication is built on Streams)
View types: KEYS_ONLY | NEW_IMAGE | OLD_IMAGE | NEW_AND_OLD_IMAGES
```

**TTL** — set a numeric epoch attribute; DynamoDB deletes expired items **for free** (within ~48h, best-effort). Great for sessions, carts, temporary tokens. TTL deletes appear in Streams.

**Transactions** — `TransactWriteItems` / `TransactGetItems` give ACID across up to **100 items / 4 MB**, all-or-nothing. Cost = **2× WCU/RCU**. Use for "debit + credit", idempotent order creation, conditional multi-item updates.

**DAX (DynamoDB Accelerator)** — in-memory cache, **microsecond** reads, write-through. Sits in your VPC. Use for read-heavy, eventually-consistent workloads. (For session/object caching unrelated to a table, use [ElastiCache](../13-advanced-aws/02-elasticache-redis.md) instead.)

**Global Tables** — multi-region, active-active replication (built on Streams) for low-latency global apps and regional DR.

---

## 7. Writes & concurrency

- **Conditional writes:** `ConditionExpression` (e.g. `attribute_not_exists(PK)`) → idempotency and optimistic locking. Failed condition = `ConditionalCheckFailedException` (no WCU wasted beyond the attempt).
- **Atomic counters:** `UpdateExpression: SET views = views + :inc` — increments without read-modify-write races.
- **BatchWriteItem:** up to 25 put/delete; **no conditions**, may return unprocessed items (retry with backoff).
- **Optimistic locking** (SDK): a `version` attribute + condition prevents lost updates.

---

## 8. Single-table design (the DynamoDB mindset)

Relational instinct = one table per entity. DynamoDB pro instinct = **one table, many entity types**, overloaded keys, designed around access patterns.

```
PK              SK                 attributes
EMP#123         PROFILE            name, dept, hireDate
EMP#123         LEAVE#2026-07      days, status
EMP#123         PAYSLIP#2026-05    gross, net, pdfKey
DEPT#eng        EMP#123            role            ← GSI flips this to list a dept's employees
```
One `Query(PK=EMP#123)` returns the employee **and** their leave + payslips in a single call. This is why you model access patterns *first*, schema *never*.

---

## 9. HRMS example (with Lambda)

```js
// Node.js (AWS SDK v3) — record a payslip, idempotently
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.TABLE_NAME;

export async function addPayslip(empId, period, data) {
  await ddb.send(new PutCommand({
    TableName: TABLE,
    Item: { PK: `EMP#${empId}`, SK: `PAYSLIP#${period}`, ...data },
    ConditionExpression: "attribute_not_exists(SK)",   // don't double-create
  }));
}

export async function getEmployeeBundle(empId) {           // profile + leave + payslips in ONE query
  const r = await ddb.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: "PK = :pk",
    ExpressionAttributeValues: { ":pk": `EMP#${empId}` },
  }));
  return r.Items;
}
```
🔒 The Lambda's IAM role grants only `dynamodb:PutItem`/`Query` on this one table ARN — least privilege ([see serverless IAM section](README.md#iam-least-privilege-for-lambda)).

---

## 10. Limits & quotas (exam favourites)

| Limit | Value |
|---|---|
| Item size (incl. attribute names) | **400 KB** |
| Query/Scan result page | 1 MB |
| Partition key length | 1–2048 bytes |
| Sort key length | 1–1024 bytes |
| Transaction | 100 items / 4 MB |
| BatchWriteItem | 25 items |
| BatchGetItem | 100 items / 16 MB |
| GSIs per table | 20 (default) · LSIs | 5 |
| On-demand throughput | scales automatically (no preset ceiling) |

💡 Store large blobs (PDFs, images) in **S3** and keep only the S3 key in DynamoDB.

---

## 11. Cost optimization

1. **On-demand for spiky/new** workloads; **provisioned + auto scaling** for steady ones.
2. Avoid `Scan`; design GSIs so every access pattern is a `Query`.
3. Project **only needed attributes** into GSIs (KEYS_ONLY/INCLUDE) to cut storage + write cost.
4. Use **TTL** to auto-purge stale items (free deletes).
5. **Standard-IA** table class for infrequently-accessed data (cheaper storage, pricier reads).
6. Compress large attributes; offload blobs to S3.
7. Reserved capacity for predictable provisioned workloads (1/3-yr discount).

---

## 12. Common pitfalls ⚠️

- Choosing a low-cardinality partition key → hot partitions & throttling.
- Using `Scan` + `FilterExpression` as a substitute for an index.
- Forgetting GSIs are **eventually consistent** and have **separate capacity**.
- Assuming TTL deletes instantly (it's best-effort, up to 48h).
- Items >400 KB (must split or offload to S3).
- Not handling `UnprocessedItems` from BatchWrite / pagination from Query.

---

## 13. Quick reference

```
GetItem    → one item by key
Query      → items by partition key (+ SK condition)   ✅ design for this
Scan       → whole table                                ❌ avoid
LSI        → same PK, alt SK, strong-consistent, create-time only
GSI        → alt PK, eventual, own capacity, anytime
Streams    → change log → Lambda → fan-out / replicate
TTL        → free expiry deletes
Transactions → ACID, 2× cost, ≤100 items
DAX        → microsecond read cache
Global Tables → multi-region active-active
```

**Official docs:** https://docs.aws.amazon.com/amazondynamodb/ · DynamoDB Streams: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html

---

*Next: [09 — Cost Optimization](README.md#cost-optimization) (inline) · then [10 — Interview Questions](10-interview-questions.md). Back to [Serverless README](README.md).*

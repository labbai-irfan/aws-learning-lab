# Project 4 — Multi-Tenant Serverless API Backend

> A production-style serverless REST backend with JWT auth and per-tenant data isolation. Ties together **API Gateway + Lambda + Cognito + DynamoDB (+ optional Aurora Serverless)**. Maps directly to the HRMS API tier.

**You'll build:** a secured `/employees` and `/payroll` API where each company (tenant) sees only its own data, authenticated by Cognito, with X-Ray tracing and least-privilege IAM.

**Prerequisites:** [01 Lambda](../../01-lambda-core-concepts.md), [02 API Gateway](../../02-api-gateway.md), [08 DynamoDB](../../08-dynamodb.md), [09 Cognito](../../09-cognito.md).

---

## Architecture
```
React SPA ──(Authorization Code + PKCE)──► Cognito Hosted UI
   │  ID/Access JWT (claims: sub, email, custom:tenantId, cognito:groups)
   ▼
API Gateway (HTTP API, JWT authorizer → Cognito User Pool)
   │  GET/POST /employees   GET /payroll   (verified claims in context)
   ▼
Lambda (Node 20)  ── least-privilege role ──►  DynamoDB (single table)
   │  enforces tenant isolation: PK = TENANT#<tenantId>             │
   └── X-Ray active tracing                                          │
                                                       (optional: Aurora Serverless v2 via RDS Proxy)
```

## Data model (single-table, tenant-isolated)
```
PK                   SK                attributes
TENANT#acme          EMP#101           name, dept, salary
TENANT#acme          PAYSLIP#2026-05   gross, net, pdfKey(S3)
TENANT#globex        EMP#101           name, dept              ← different tenant, isolated
```
Every query is scoped to `PK = TENANT#<tenantId from the JWT>` → a tenant can never read another's rows.

## Tenant isolation (the key idea)
```js
// the tenantId comes from the verified JWT claim, NEVER from the request body
export const handler = async (event) => {
  const claims = event.requestContext.authorizer.jwt.claims;
  const tenantId = claims["custom:tenantId"];           // trusted: set by Cognito
  const pk = `TENANT#${tenantId}`;
  const res = await ddb.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: "PK = :pk AND begins_with(SK, :sk)",
    ExpressionAttributeValues: { ":pk": pk, ":sk": "EMP#" },
  }));
  return { statusCode: 200, body: JSON.stringify(res.Items) };
};
```
🔒 **Pool model** (shared table, partition-key isolation) is cheap and scalable; for stricter isolation use the **silo model** (table/account per tenant). See [Phase 13 — SaaS Multi-Tenant](../../../13-advanced-aws/13-saas-multi-tenant.md).

## Build steps (high level)
1. **Cognito User Pool** + app client (Authorization Code + PKCE); add a `custom:tenantId` attribute and a `hr-admin` group. A `PreTokenGeneration` trigger can inject `custom:tenantId`.
2. **DynamoDB** single table (`PK`/`SK`, on-demand).
3. **Lambdas** (`listEmployees`, `createEmployee`, `getPayroll`) — each with an IAM role scoped to `Query/PutItem` on the table ARN only.
4. **HTTP API** with a **JWT authorizer** (issuer = the pool); routes → Lambdas. `/payroll` additionally checks `cognito:groups` contains `hr-admin`.
5. **X-Ray** active tracing on the functions + API stage.
6. (Optional) **Aurora Serverless v2** behind **RDS Proxy** for relational reporting; Lambda reads creds from **Secrets Manager**.

## Security checklist 🔒
- [ ] `tenantId` derived from the **JWT claim**, never from client input.
- [ ] Lambda roles scoped to the **table ARN** + needed actions only.
- [ ] `/payroll` gated on the `hr-admin` group claim.
- [ ] MFA (TOTP) for privileged groups; advanced security on.
- [ ] WAF on the API; secrets in Secrets Manager; encryption at rest (KMS).
- [ ] DLQ on async paths; idempotency keys on writes.

## Verify ✅
- A token for tenant `acme` cannot read tenant `globex` rows (returns only acme's data).
- A non-`hr-admin` user gets 403 on `/payroll`.
- The X-Ray service map shows API GW → Lambda → DynamoDB.

## Cleanup 💰
Delete the API, Lambdas, DynamoDB table, Cognito pool (and Aurora/RDS Proxy if created) to avoid charges.

---
*Back to [Serverless README](../../README.md) · sibling projects: [01 Order Processing](../01-ecommerce-order-processing/README.md) · [02 Notifications](../02-realtime-notifications/README.md) · [03 Data Pipeline](../03-data-pipeline/README.md).*

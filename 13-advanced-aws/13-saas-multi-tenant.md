# Module 13 — SaaS & Multi-Tenant Architecture

> The three tenancy models, data isolation patterns, tenant routing, noisy-neighbour mitigation, and how to build a scalable SaaS HRMS on AWS.

---

## 1. Tenancy models

### Silo (full isolation)
Each tenant gets **dedicated** AWS resources:
```
   Tenant A: own VPC + own RDS + own ECS cluster + own S3 bucket
   Tenant B: own VPC + own RDS + own ECS cluster + own S3 bucket
```
- **Pros**: maximum isolation (compliance, noisy-neighbour free), easy to right-size per tenant.
- **Cons**: high cost per tenant, complex operations (N clusters to manage), slow provisioning.
- **When**: large enterprise customers, regulated industries (banking, healthcare), high-paying contracts.

### Pool (full sharing)
All tenants share resources; a **tenant ID** column/partition isolates data:
```
   All tenants → shared ALB → shared ECS → shared RDS (tenant_id column) → shared S3 (prefix /tenantId/)
```
- **Pros**: lowest cost per tenant, simple operations, fast provisioning.
- **Cons**: noisy-neighbour risk, harder compliance, data leakage risk if query bug.
- **When**: SMB SaaS, high volume/low value tenants, non-regulated.

### Bridge (tiered hybrid)
Free/Starter tenants on pool; Enterprise tenants on silo:
```
   Free tier:       shared pool (many tenants, cheap)
   Pro tier:        shared pool (better SLAs, some dedicated resources)
   Enterprise tier: silo (dedicated VPC, RDS, contract SLAs)
```
- **When**: most real SaaS products — optimize cost for small, premium for large.

---

## 2. Data isolation patterns

### Schema-per-tenant (PostgreSQL)
```sql
-- Tenant A: schema hrms_tenant_a
-- Tenant B: schema hrms_tenant_b
-- App connects with search_path=hrms_${tenantId}
```
Pros: easy to export/delete a tenant's data. Cons: schema migrations must run N times.

### Row-level security (RLS) — pool on one schema
```sql
CREATE POLICY tenant_isolation ON employees
  USING (tenant_id = current_setting('app.current_tenant_id')::int);
SET app.current_tenant_id = '42';  -- set at start of each connection
```
Pros: clean isolation in SQL, one schema. Cons: must set tenant context on every connection; bugs risk cross-tenant leakage.

### Database-per-tenant (silo DB)
Own RDS instance; maximum isolation; Terraform provisions each. Scale: Aurora Serverless v2 makes this economical.

### S3 isolation
Pool: `s3://hrms-saas/tenants/{tenantId}/documents/`. S3 prefix is an organizational unit; IAM condition on prefix. Silo: separate buckets.

---

## 3. Tenant routing

### Path-based routing (pool)
```
   api.hrms.com/t/{tenantId}/employees → ALB → ECS (tenant context from path)
```

### Subdomain-based routing (silo or bridge)
```
   acme.hrms.com     → ACME's dedicated ECS + RDS
   globex.hrms.com   → GLOBEX's shard of pool (Route 53 CNAME → ALB)
```
CloudFront + Lambda@Edge: extract subdomain → set `X-Tenant-Id` header → origin routes.

### JWT claim-based (stateless, preferred)
```
   User authenticates → JWT with { "tenantId": "42", "plan": "enterprise" }
   ALB listener rule: forward to ECS; ECS reads tenantId from JWT; all DB queries add WHERE tenant_id=?
```

---

## 4. Noisy-neighbour mitigation

```
   Tenant A runs a heavy report → consumes 80% DB CPU → Tenant B's requests slow
```

Mitigations:
- **Per-tenant resource limits** at the app layer (request rate limiting per tenantId in Redis).
- **Separate DB read replicas** for large reports (or route analytics to Redshift).
- **SQS queues** for heavy async work — tenant A's reports queue up, OLTP unaffected.
- **ElastiCache** absorbs read spikes; per-tenant cache namespace.
- **Throttling** in API Gateway: usage plans per tenant (API key) with rate and burst limits.
- **Container-level limits**: ECS task CPU/memory limits prevent runaway tenant impact.
- **Aurora Serverless v2**: per-tenant clusters that scale to near-zero when idle.

---

## 5. SaaS control plane vs data plane

```
   CONTROL PLANE (shared)
   ├── Tenant registry (DynamoDB): tenantId, plan, config, metadata
   ├── Account vending: provision silo resources for enterprise tenants
   ├── Billing/metering: usage events → SNS → billing service
   ├── Authentication: Cognito user pool per tenant (or shared + custom domain)
   └── Admin portal: tenant management

   DATA PLANE (per-tenant isolation level)
   ├── API (ECS/Lambda): reads tenantId from JWT; enforces isolation
   ├── Database: schema/row/table isolation based on plan
   └── Storage: S3 prefix or dedicated bucket
```

---

## 6. SaaS HRMS architecture on AWS (bridge model)

```
   Route 53 (per-subdomain CNAME)
        │
   CloudFront + WAF (rate limit per tenantId via Lambda@Edge)
        │
   ALB (shared)
        │ X-Tenant-Id header
   ECS Fargate (shared pool, stateless, tenant context from JWT)
        │
   ├── RDS Aurora Serverless (pool: schema-per-tenant, up to 100 tenants/cluster)
   ├── ElastiCache Redis (tenant-namespaced keys: tenant:{id}:employee:{empId})
   ├── SQS per-tenant queue (payroll job isolation)
   └── S3 (prefix-per-tenant, signed URLs for downloads)

   ENTERPRISE TIER: each tenant gets a dedicated VPC + Aurora cluster (Terraform-provisioned)
```

---

## 7. Tenant onboarding automation

New tenant created → EventBridge event → Step Functions workflow:
1. Create Cognito user pool (or add to shared, custom domain).
2. Provision DB schema (migration Lambda).
3. Create S3 prefix / bucket (if silo).
4. Register in tenant registry (DynamoDB).
5. Set up API Gateway usage plan.
6. Send welcome email.
7. (Enterprise) trigger Terraform to provision dedicated VPC + RDS.

Target time: < 5 minutes for pool tier; < 30 minutes for silo tier.

---

## ✅ SaaS architecture checklist
- [ ] Tenancy model chosen and documented (silo/pool/bridge with upgrade path)
- [ ] Tenant ID in every DB query (row policy or schema prefix)
- [ ] JWT with tenant claim; never trust client-provided tenant ID alone
- [ ] Per-tenant rate limiting (Redis sorted set or API Gateway usage plan)
- [ ] Noisy-neighbour: async heavy work via SQS + separate workers
- [ ] Onboarding automated (Step Functions < 5 min)
- [ ] Control plane separated from data plane
- [ ] Tenant data export and deletion (GDPR) implemented

➡️ Next: [Module 14 — Enterprise Case Studies](14-enterprise-case-studies.md)

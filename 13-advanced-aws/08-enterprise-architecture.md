# Module 8 — Enterprise Architecture Patterns

> Hub-spoke networking, Transit Gateway, shared services, service mesh, event-driven architecture, and the patterns that hold large AWS estates together.

---

## 1. Enterprise AWS estate anatomy

```
   AWS Organizations (Management Account)
   │
   ├── Network Account (Hub)
   │     Transit Gateway ── Direct Connect / VPN (on-prem)
   │     Route 53 Resolver (central DNS)
   │     Shared egress (NAT GW + Inspection VPC)
   │
   ├── Security Account
   │     GuardDuty aggregator · Security Hub · Config Aggregator
   │
   ├── Shared Services Account
   │     ECR (container registry) · Secrets Manager · Artifactory
   │     Internal Route 53 Hosted Zone
   │
   ├── Log Archive Account
   │     CloudTrail · Config snapshots · VPC flow logs (immutable S3)
   │
   └── Workload Accounts (spokes)
         HRMS-Prod · Finance-Prod · HR-Dev etc.
         Each with their own VPC, connected to Hub via TGW
```

---

## 2. Hub-and-spoke with Transit Gateway

**AWS Transit Gateway (TGW)** is a regional hub connecting VPCs and on-prem in one place:
```
   On-prem ──VPN/DX──► TGW (Network Account)
                         ├── Spoke: HRMS-Prod VPC
                         ├── Spoke: Finance-Prod VPC
                         ├── Spoke: Shared Services VPC
                         └── Spoke: Inspection VPC (firewall)
```
- Replaces N×(N-1)/2 VPC peering connections with a single hub.
- **Route tables on TGW** control which spokes can reach each other (dev can't reach prod).
- **Network Firewall** in the Inspection VPC inspects east-west traffic between spokes.

### TGW route tables (security zoning)
```
   Production RT:  propagate Prod VPCs + Shared Services; route 0.0.0.0/0 → Inspection
   Dev RT:         propagate Dev VPCs only; route 0.0.0.0/0 → Inspection
   Inspection VPC: receives all traffic, runs AWS Network Firewall, returns allowed
```

---

## 3. AWS Direct Connect (hybrid connectivity)

```
   On-prem ──[private DX circuit 1Gbps/10Gbps]──► DX Location ──► TGW
```
- Dedicated bandwidth; lower latency than internet VPN.
- **Direct Connect Gateway** spans multiple regions.
- **Active/standby**: primary DX + backup Site-to-Site VPN.
- **LAG (Link Aggregation Group)**: bundle multiple 1G ports for higher throughput + redundancy.

---

## 4. Shared services patterns

### Central ECR (container registry)
All accounts pull from a single ECR in Shared Services. Policy grants pull to workload account roles.

### Internal DNS
Route 53 **Private Hosted Zones** shared via **Route 53 Resolver** rules across accounts:
```
   hrms-api.internal ──► HRMS-Prod ALB (private)
   redis.internal     ──► ElastiCache endpoint
```

### Secrets Manager cross-account
Workload accounts read shared credentials from a central Secrets Manager via cross-account role.

---

## 5. Event-driven enterprise architecture

```
   Service A (HRMS) ──► EventBridge Bus (HRMS account)
                                 │ put-event rule → cross-account
                                 ▼
                         EventBridge Bus (Finance account)
                                 │
                         ├── Lambda: update payroll GL
                         └── SQS: queue for Finance batch processor
```

- **EventBridge event buses** enable cross-account event routing (no polling, no tight coupling).
- **Schema Registry** — discover and document event schemas.
- **Event replay** — store events for replay during bugs/migrations.
- **Dead letter queues** on EventBridge targets for failed deliveries.

**CQRS** (Command Query Responsibility Segregation): separate write path (commands → event store → SQS) from read path (materialized views → ElastiCache / read replica). Scales reads and writes independently.

---

## 6. Service mesh (ECS/EKS at scale)

For microservices with complex inter-service auth, observability, and traffic management:
- **AWS App Mesh** — sidecar proxy (Envoy) for East-West service traffic; mTLS, retries, circuit breaking.
- **EKS + Istio/Linkerd** — for Kubernetes-native workloads.
- Exposes: traffic metrics per service pair, per-route latency, error rates → CloudWatch or Prometheus.

---

## 7. API management at scale

```
   External ──► CloudFront ──► API Gateway (edge-optimized or regional)
                                   ├── /hrms/v1/* → ECS service (Fargate)
                                   ├── /auth/*    → Cognito
                                   └── /legacy/*  → on-prem via VPN
   Internal ──► ALB (internal) → private APIs
```
- API Gateway: throttling, auth (Cognito/Lambda authorizer), request/response transforms, usage plans.
- **API versioning**: URL path (`/v1/`), subdomain, or header-based.
- **API lifecycle**: deprecate old versions gracefully using usage plan warnings.

---

## 8. Data architecture at enterprise scale

```
   Transactional (OLTP): RDS MySQL/Aurora  → for app reads/writes
   Analytics (OLAP):     Redshift / Athena → for BI / reporting
   Data lake:            S3 + Glue + Athena
   Streaming:            Kinesis Data Streams / Firehose → S3 / Redshift
   CDC (change capture): DMS → Kinesis → Redshift Streaming Ingestion
```

---

## 9. Well-Architected Framework alignment

| Pillar | Key enterprise pattern |
|---|---|
| **Operational Excellence** | IaC (Terraform/CFN), CI/CD, runbooks, chaos engineering |
| **Security** | Least privilege, Zero Trust, defense in depth, SCPs |
| **Reliability** | Multi-AZ, Multi-Region, auto-scaling, health checks, DR |
| **Performance** | Caching (ElastiCache), CDN (CloudFront), async (SQS), read replicas |
| **Cost Optimization** | Reserved/Savings Plans, right-sizing, multi-account cost visibility |
| **Sustainability** | Graviton, serverless (scale to zero), efficient code |

---

## ✅ Enterprise architecture checklist
- [ ] Hub-and-spoke with TGW (no full-mesh peering)
- [ ] Separate route tables per zone (prod / dev / inspection)
- [ ] DX primary + VPN backup for hybrid
- [ ] Event-driven with EventBridge cross-account routing
- [ ] API Gateway + CloudFront for external APIs
- [ ] Central ECR, DNS, Secrets Manager in Shared Services
- [ ] Data lake + OLAP separated from OLTP
- [ ] Aligned to all 6 Well-Architected pillars

➡️ Next: [Module 9 — Multi-Region Architecture & DR](09-multi-region-dr.md)

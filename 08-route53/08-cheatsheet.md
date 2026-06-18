# 08 — Route 53 Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-route53-core-concepts.md).

## What it is
A **global** DNS web service (+ domain registrar + health checks). 100% availability SLA. "53" = the DNS port.

## Record types
| Record | Maps to |
|---|---|
| **A** | IPv4 address |
| **AAAA** | IPv6 address |
| **CNAME** | Another domain name (**not at apex**) |
| **Alias** | An AWS resource (ALB, CloudFront, S3, API GW) — **works at apex**, free queries |
| **MX** | Mail servers |
| **NS / SOA** | Name servers / zone authority |
| **TXT** | SPF/DKIM/verification |
| **CAA** | Which CAs may issue certs |

## Alias vs CNAME (classic)
| | **Alias** | **CNAME** |
|---|---|---|
| Apex (`example.com`) | ✅ yes | ❌ no |
| Targets | AWS resources | any hostname |
| Cost | free (AWS targets) | charged |
| Health-aware | yes (evaluate target health) | no |
💡 Point an apex at an ALB/CloudFront → **Alias A record**.

## Routing policies
| Policy | Use |
|---|---|
| **Simple** | One record, no health checks |
| **Weighted** | Split by % (A/B, canary, gradual migration) |
| **Latency** | Lowest-latency Region |
| **Failover** | Active-passive DR (primary + secondary + health check) |
| **Geolocation** | Route by user's country/continent |
| **Geoproximity** | Bias traffic toward/away from a location (Traffic Flow) |
| **Multivalue** | Up to 8 healthy records returned (client-side LB) |

## Health checks
- Types: **endpoint** (HTTP/HTTPS/TCP), **calculated** (combine children), **CloudWatch alarm** (for private resources).
- Failed health check → Route 53 stops returning that record (drives **failover**).

## TTL & registration
- **TTL** = how long resolvers cache. **Lower TTL before** a planned change. Alias to AWS = managed TTL.
- Registrar for many TLDs; using Route 53 DNS for an external domain = point the registrar's **NS** at Route 53.
- **Resolver** (inbound/outbound endpoints) = hybrid DNS between VPC and on-prem.

## Exam triggers 💡
- "Apex domain → ALB/CloudFront" → **Alias A record** (CNAME can't).
- "Active-passive DR auto-cutover" → **failover + health checks**.
- "Lowest latency across Regions" → **latency routing**.
- "Send 10% to a new stack" → **weighted**.
- "Different content per country" → **geolocation**.
- "Email setup" → **MX** (+ SPF/DKIM **TXT**).
- "Hybrid on-prem ⇄ VPC DNS" → **Route 53 Resolver endpoints**.

## Gotchas ⚠️
- No CNAME at the zone apex — use Alias.
- Change not visible → **TTL caching**; lower TTL ahead of changes.
- Failover not cutting over → check health-check status + "evaluate target health".
- Route 53 is global (not Region-bound); hosted zones billed monthly + per query.

---
*Back to [Route 53 README](README.md).*

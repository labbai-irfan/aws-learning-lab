# Module 1 — Route 53 Core Concepts

> Every DNS / Route 53 building block explained, with definitions, analogies, key points, CLI examples, and exam/production tips.

## Table of Contents
1. [DNS Basics](#1-dns-basics)
2. [Domain Registration](#2-domain-registration)
3. [Hosted Zones](#3-hosted-zones)
4. [A Records](#4-a-records)
5. [CNAME](#5-cname)
6. [Alias](#6-alias)
7. [MX Records](#7-mx-records)
8. [TXT Records](#8-txt-records)
9. [Routing Policies](#9-routing-policies)
10. [Health Checks](#10-health-checks)
11. [Failover Routing](#11-failover-routing)

---

## What is Amazon Route 53?

**Amazon Route 53** is AWS's highly available, scalable **DNS web service** + **domain registrar** + **health-checking** service. (The name "53" = DNS port 53.) It does three jobs:
1. **Register** domain names.
2. **Route** internet traffic to resources (DNS resolution) using flexible routing policies.
3. **Check the health** of resources and route around failures.

It boasts a **100% availability SLA** — the only AWS service with one.

---

## 1. DNS Basics

**Definition:** **DNS (Domain Name System)** is the internet's "phone book" — it translates human-friendly **names** (`www.example.com`) into machine **IP addresses** (`192.0.2.10`).

**Analogy:** You remember "Pizza Palace," not their phone number. DNS is the directory that looks up the number for you.

### How a DNS lookup works (resolution flow)
```
   1. Browser → DNS Resolver (usually your ISP / 8.8.8.8): "IP for www.example.com?"
   2. Resolver → Root server (.)      : "ask the .com servers"
   3. Resolver → TLD server (.com)    : "ask example.com's name servers"
   4. Resolver → Authoritative NS     : (Route 53 hosted zone) "it's 192.0.2.10"
   5. Resolver caches the answer (per TTL) and returns it to the browser
   6. Browser connects to 192.0.2.10
```

### Key vocabulary
| Term | Meaning |
|------|---------|
| **Domain name** | `example.com` |
| **TLD** | Top-Level Domain: `.com`, `.org`, `.io`, `.in` |
| **Subdomain** | `app.example.com`, `api.example.com` |
| **Zone apex / root** | the bare domain `example.com` (no subdomain) |
| **FQDN** | Fully Qualified Domain Name, e.g. `www.example.com.` |
| **DNS record** | An entry mapping a name to a value (A, CNAME, MX…) |
| **Resolver** | The server that performs lookups on your behalf |
| **Authoritative name server** | The server that holds the real answers for a zone (Route 53) |
| **TTL** | Time To Live — how long a record may be cached (seconds) |
| **Propagation** | The delay while old cached records expire and new ones spread |

### TTL — the thing beginners trip on ⚠️
- TTL controls **caching duration**. A 24-hour TTL means resolvers may serve the old value for up to 24h after you change it.
- **Lower the TTL (e.g., 60s) BEFORE a planned change** so the cutover is fast; raise it later for efficiency.

💡 **Exam tip:** Route 53 is **authoritative** DNS (it holds the answers). Recursive **resolvers** (ISP/8.8.8.8) cache and look up. TTL governs caching, not how fast Route 53 updates (Route 53 changes are near-instant; *caches* are what take time).

---

## 2. Domain Registration

**Definition:** Registering a domain means **leasing a name** (e.g., `example.com`) from a registrar for a period (usually yearly). Route 53 is both a **registrar** and a **DNS host** — you can do both in one place, or register elsewhere and host DNS in Route 53.

### What happens when you register in Route 53
1. You search for and buy an available name. 💰 (price varies by TLD, e.g., `.com` ≈ $13/yr — verify current pricing.)
2. Route 53 **automatically creates a hosted zone** for the domain.
3. Route 53 sets the domain's **name servers (NS)** to that hosted zone's 4 NS records.
4. You manage records in the hosted zone.

### Registrar vs DNS host (important distinction)
- **Registrar** = who you bought the name from (GoDaddy, Namecheap, Route 53…).
- **DNS host** = whose name servers actually answer queries (where the hosted zone lives).
- These can be **different**: register at GoDaddy, but point its NS records to a Route 53 hosted zone → Route 53 hosts your DNS.

### Bringing an external domain to Route 53
```
1. Create a Route 53 hosted zone for example.com (get its 4 NS records)
2. At your current registrar, replace the NS records with Route 53's 4 NS
3. Wait for propagation; Route 53 is now authoritative
```

### CLI
```bash
aws route53domains check-domain-availability --domain-name example.com   # (us-east-1)
aws route53domains list-domains
```

💡 **Tip:** Enable **auto-renew** and **privacy protection** (WHOIS privacy) on registration. ⚠️ A lapsed domain can be lost — renewals matter.

---

## 3. Hosted Zones

**Definition:** A **hosted zone** is the **container for all DNS records** of a single domain (and its subdomains). It's where you define A, CNAME, MX, TXT, etc.

### Two types
| Type | Resolvable from | Use |
|------|-----------------|-----|
| **Public hosted zone** | The public internet | Websites, APIs, email — anything internet-facing |
| **Private hosted zone** | Inside associated VPC(s) only | Internal names (e.g., `db.internal.example.com`) for private resources |

### Auto-created records in every zone
- **NS (Name Server)** — the 4 authoritative name servers for the zone. These must match what the registrar advertises.
- **SOA (Start of Authority)** — zone metadata (primary NS, admin email, serial, refresh/retry/expiry/min-TTL).
- ⚠️ Don't delete/break the NS and SOA records.

### Key facts & cost 💰
- Each hosted zone costs ~**$0.50/month** + per-query charges (first 1B queries cheap). 💰
- ⚠️ Deleting and recreating a hosted zone changes its NS records — you'd have to update the registrar again.
- One zone per domain; subdomains live as records inside it (or in their own delegated zone).

### CLI
```bash
aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)
aws route53 list-hosted-zones
aws route53 get-hosted-zone --id /hostedzone/Z123456ABCDEFG    # shows the NS records
aws route53 list-resource-record-sets --hosted-zone-id Z123456ABCDEFG
```

💡 **Exam tip:** Public zone = internet; private zone = VPC-internal. The hosted zone's **NS records must match the registrar** or resolution breaks.

---

## 4. A Records

**Definition:** An **A record** maps a name to an **IPv4 address**. (**AAAA** record = same but for **IPv6**.)

```
   www.example.com   A   192.0.2.10
   www.example.com   AAAA 2001:db8::10     (IPv6)
```

### Key facts
- Used to point a name at a **fixed IP** — e.g., an EC2 instance's **Elastic IP**, or an on-prem server.
- Can hold **multiple IPs** (Route 53 returns them, basic round-robin).
- Has a **TTL**.

### When to use a plain A record vs Alias
- Use a plain **A record** for non-AWS targets or a static IP (Elastic IP).
- Use an **Alias** (see §6) to point at AWS resources (ALB, CloudFront, S3 website) — Alias is preferred and works at the apex.

### CLI (UPSERT via change-batch)
```bash
aws route53 change-resource-record-sets --hosted-zone-id Z123 --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"www.example.com","Type":"A","TTL":300,
    "ResourceRecords":[{"Value":"192.0.2.10"}]}}]}'
```

💡 **Exam tip:** A = name→IPv4, AAAA = name→IPv6. Point apex domains at AWS resources with **Alias**, not a hard-coded IP.

---

## 5. CNAME

**Definition:** A **CNAME (Canonical Name)** record maps a name to **another name** (not an IP). The resolver then looks up that target name.

```
   www.example.com   CNAME   example.com           (www points to the apex)
   shop.example.com  CNAME   myshop.myhost.com      (point to a vendor host)
   blog.example.com  CNAME   myblog.wordpress.com
```

### Critical rules ⚠️
- **Cannot be used at the zone apex** (`example.com` itself). DNS forbids a CNAME coexisting with the required NS/SOA at the apex. → Use an **Alias** for the apex instead.
- A CNAME's name **cannot have other records** of different types at the same name.
- Adds an **extra lookup** (slightly slower than A/Alias).

### CNAME vs Alias (the #1 Route 53 interview question)
| | CNAME | Alias |
|---|-------|-------|
| Points to | Any DNS name | AWS resources (ALB, CloudFront, S3, API GW, another R53 record) + some |
| Apex (`example.com`)? | ❌ Not allowed | ✅ Allowed |
| Cost per query | Charged like normal DNS | **Free** for Alias queries to AWS resources |
| Returns | Another name (extra lookup) | Resolves directly to the target's IPs |
| AWS-specific? | No (standard DNS) | Yes (Route 53 feature) |

💡 **Exam tip:** Need the **apex** to point at an ALB/CloudFront/S3? You **must** use an **Alias** (CNAME is illegal at apex). For subdomains pointing to non-AWS hosts, CNAME is fine.

---

## 6. Alias

**Definition:** An **Alias record** is a **Route 53-specific** extension that works like an A/AAAA record but points to an **AWS resource** (or another Route 53 record) by its hostname, resolving directly to its IP addresses. It's the recommended way to map domains to AWS endpoints.

### Why Alias is better than CNAME for AWS resources
- ✅ Works at the **zone apex** (`example.com`).
- ✅ **Free** — Route 53 doesn't charge for Alias queries to AWS resources.
- ✅ Auto-updates if the target's IPs change (e.g., ALB scaling).
- ✅ Can target: **CloudFront, ALB/NLB/Classic ELB, S3 static website, API Gateway, VPC endpoints, Elastic Beanstalk, Global Accelerator, another record in the same zone**.

### Typical Alias targets
```
   example.com        Alias → CloudFront distribution (React site)
   www.example.com    Alias → example.com (or CloudFront)
   api.example.com    Alias → Application Load Balancer
```

### CLI (Alias to an ALB)
```bash
aws route53 change-resource-record-sets --hosted-zone-id Z123 --change-batch '{
 "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
   "Name":"api.example.com","Type":"A",
   "AliasTarget":{
     "HostedZoneId":"ZXXXXALBZONE",          // the ALB''s canonical hosted zone id
     "DNSName":"my-alb-123.ap-south-1.elb.amazonaws.com",
     "EvaluateTargetHealth":true}}}]}'
```
> Each AWS resource type has its own **canonical hosted zone ID** (different from your domain's zone). The console fills it in automatically.

💡 **Exam tip:** **Alias = apex-capable + free + AWS-targets**. Default to Alias for ALB/CloudFront/S3; use CNAME only for non-AWS subdomain targets. `EvaluateTargetHealth=true` integrates with health checks.

---

## 7. MX Records

**Definition:** An **MX (Mail Exchange)** record directs **email** for your domain to the correct mail servers. Each MX has a **priority** (lower number = higher priority/tried first).

```
   example.com   MX   10 mail1.mailprovider.com
   example.com   MX   20 mail2.mailprovider.com    (backup, used if 10 is down)
```

### Key facts
- The number before the hostname is the **priority/preference** (lowest first).
- Usually set at the **apex** (`example.com`) so `you@example.com` routes correctly.
- Provided by your email host (Google Workspace, Microsoft 365, Amazon WorkMail, etc.).
- Pair MX with **TXT** records for SPF/DKIM/DMARC (anti-spam, see §8).

### Example: Google Workspace
```
example.com  MX  1  smtp.google.com         (modern single-host setup)
example.com  TXT    "v=spf1 include:_spf.google.com ~all"
```

💡 **Exam tip:** MX = email routing; priority = lowest number wins. MX points to **hostnames**, not IPs. Always add SPF/DKIM/DMARC via TXT for deliverability.

---

## 8. TXT Records

**Definition:** A **TXT record** holds arbitrary **text**. In practice it's used for **machine-readable verification and email-security** policies.

### Common uses
| Use | Example value |
|-----|---------------|
| **Domain verification** | `google-site-verification=abc123...` (prove ownership to Google/AWS/etc.) |
| **SPF** (anti-spoofing) | `v=spf1 include:_spf.google.com ~all` |
| **DKIM** (email signing) | `v=DKIM1; k=rsa; p=MIGfMA0...` (often on a `selector._domainkey` subdomain) |
| **DMARC** (email policy) | `v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com` (on `_dmarc.example.com`) |
| **ACM cert validation** | AWS uses **CNAME** records for ACM DNS validation (not TXT) — don't confuse |

```
   example.com           TXT  "v=spf1 include:_spf.google.com ~all"
   _dmarc.example.com    TXT  "v=DMARC1; p=none; rua=mailto:dmarc@example.com"
```

### Key facts
- A name can have **multiple TXT records**; each string max 255 chars (longer values are split into chunks).
- Quotes are part of the value.

💡 **Exam tip:** TXT = verification + email security (SPF/DKIM/DMARC). Domain "verify ownership" steps almost always use a TXT (or CNAME) record.

---

## 9. Routing Policies

**Definition:** A **routing policy** controls **which record value Route 53 returns** when there are choices — enabling load distribution, performance optimization, and resilience.

| Policy | What it does | Use case |
|--------|--------------|----------|
| **Simple** | One record, returns its value(s) | Basic single resource |
| **Weighted** | Splits traffic by assigned weights | A/B testing, canary, gradual rollout (e.g., 90/10) |
| **Latency-based** | Returns the Region with lowest latency to the user | Multi-Region apps, best performance |
| **Failover** | Primary/secondary; routes to secondary if primary unhealthy | Active-passive DR (see §11) |
| **Geolocation** | Routes by the user's geographic location | Localized content, compliance, geo-blocking |
| **Geoproximity** | Routes by geographic distance, with bias to shift traffic | Fine-grained geo traffic shaping (Traffic Flow) |
| **Multivalue answer** | Returns multiple healthy records (with health checks) | Simple client-side load balancing + health |

### Visual
```
   WEIGHTED                LATENCY                 FAILOVER
   ┌─ 90% → v1 (stable)    user→ nearest Region    Primary (healthy?) ─► serve
   └─ 10% → v2 (canary)    (us / eu / ap)           └─unhealthy─► Secondary (standby)

   GEOLOCATION             MULTIVALUE
   EU users → EU site      return up to 8 healthy records, client picks
   IN users → IN site
```

### Choosing (decision hints)
```
Split/percentage rollout?          → Weighted
Best performance across Regions?   → Latency-based
Active-passive DR?                 → Failover
Content/compliance by country?     → Geolocation
Distance + traffic bias control?   → Geoproximity
Simple HA with health checks?      → Multivalue answer
One target, no logic?              → Simple
```

💡 **Exam tip:** Memorize the 7 policies and one use case each. **Weighted** = % split (canary). **Latency** = performance. **Failover** = DR. **Geolocation** = by country/continent. **Multivalue** = multiple healthy answers (not a substitute for a load balancer).

---

## 10. Health Checks

**Definition:** A **health check** monitors the health of an endpoint (or other health checks / CloudWatch alarms). Route 53 uses results to decide whether to return a record — enabling failover and removing unhealthy targets.

### Three types
| Type | Monitors |
|------|----------|
| **Endpoint** | An IP/domain + port + path (HTTP/HTTPS/TCP) — "is this server up?" |
| **Calculated** | Combines other health checks (e.g., healthy if ≥2 of 3 pass) |
| **CloudWatch alarm** | Health derived from a CloudWatch alarm state (great for private resources) |

### How it works
- Route 53 **checkers worldwide** probe the endpoint at intervals (default 30s; 10s "fast").
- After a configurable number of consecutive failures (**failure threshold**, default 3), the endpoint is marked **unhealthy**.
- Health checks can trigger **failover routing**, remove records from **multivalue** answers, and send **CloudWatch/SNS alerts**.

### Endpoint health check config (key fields)
```
Protocol:        HTTP / HTTPS / TCP
Endpoint:        IP or domain + port (e.g., 443) + path (e.g., /health)
Request interval:30s (or 10s fast)
Failure threshold:3
String matching: optionally require a response body string
```

### CLI
```bash
aws route53 create-health-check --caller-reference $(date +%s) \
  --health-check-config '{
    "Type":"HTTPS","FullyQualifiedDomainName":"api.example.com",
    "Port":443,"ResourcePath":"/health","RequestInterval":30,"FailureThreshold":3}'
```

💡 **Exam tip:** Health checks enable **failover** and clean **multivalue** answers. Use a lightweight `/health` endpoint. For private/internal resources, use a **CloudWatch alarm** health check (R53 checkers can't reach private IPs directly).

---

## 11. Failover Routing

**Definition:** **Failover routing** is an **active-passive** pattern: Route 53 sends all traffic to a **primary** resource while it's healthy, and automatically switches to a **secondary** (standby) when the primary's health check fails.

### How to set it up
```
1. Create a health check on the PRIMARY endpoint
2. Create a record (e.g., api.example.com) with:
     - Failover routing = PRIMARY, associated health check
     - Failover routing = SECONDARY, pointing to the standby
3. When primary health check = unhealthy → Route 53 returns the SECONDARY
```

```
   api.example.com (Failover)
        ├─ PRIMARY   → ALB in ap-south-1   [health check]
        └─ SECONDARY → ALB in us-east-1 (or an S3 "we're down" page)
                         ▲
        health check fails on primary ─► clients get SECONDARY
```

### Common patterns
- **Multi-Region DR:** primary app Region + standby app Region.
- **Static fallback:** primary app + secondary = an S3 static "maintenance" site (cheap graceful degradation).
- Combine with **Alias + EvaluateTargetHealth** so an ALB's own health propagates.

### Failover vs other resilience
- **Failover routing** = active-passive (one serves at a time).
- For **active-active** across Regions, use **latency-based** or **weighted** with health checks (all serve, route by performance/share).

💡 **Exam tip:** Failover = active-passive DR using a health check. Secondary can be a full standby **or** a cheap static S3 page. For active-active, use latency/weighted + health checks.

---

## ✅ Module 1 Recap
You can now explain: DNS resolution & TTL · domain registration vs DNS hosting · public/private hosted zones (NS/SOA) · A/AAAA records · CNAME (and why not at apex) · Alias (apex-capable, free, AWS targets) · MX (email, priority) · TXT (SPF/DKIM/DMARC, verification) · the 7 routing policies · health checks (3 types) · failover (active-passive DR).

➡️ Next: [02-architectures.md](02-architectures.md)

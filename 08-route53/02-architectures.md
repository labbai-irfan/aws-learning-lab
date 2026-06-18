# Module 2 — Route 53 Architectures

> Four practical architectures: how domains resolve end-to-end, how SSL/HTTPS fits in, and exactly how to put a custom domain on a **React front end** and a **Node API**. Diagrams + the exact record sets you create.

## Index
1. [Domain Architecture](#1-domain-architecture)
2. [SSL Architecture](#2-ssl-architecture)
3. [React Deployment Domain Setup](#3-react-deployment-domain-setup)
4. [Backend API Domain Setup](#4-backend-api-domain-setup)

---

## 1. Domain Architecture

**Goal:** Understand the full path from a user typing a domain to reaching your AWS resource, and where Route 53 sits.

```
   USER  https://app.example.com
     │
     ▼
   ┌──────────────┐   not cached?    ┌─────────┐   ┌──────────────┐   ┌─────────────────────┐
   │ DNS Resolver │ ───────────────► │ Root(.) │ ─►│ TLD (.com)   │ ─►│ Authoritative NS     │
   │ (ISP/8.8.8.8)│ ◄─── answer ──── └─────────┘   └──────────────┘   │  = ROUTE 53          │
   └──────┬───────┘   (cached per TTL)                                 │  hosted zone         │
          │                                                            │  example.com         │
          │                                          ┌─────────────────┴─────────────────────┐
          │                                          │ app  Alias → CloudFront                │
          │                                          │ api  Alias → ALB                        │
          │                                          │ @    A/Alias, MX, TXT, NS, SOA          │
          │                                          └─────────────────┬─────────────────────┘
          ▼                                                            ▼
   browser connects to the returned target ──────────────► CloudFront / ALB / EC2 / S3
```

### The registration ↔ resolution chain
```
Registrar (who you bought example.com from)
   stores ─► NS records pointing to Route 53's 4 name servers
                         │
                         ▼
Route 53 Hosted Zone (authoritative) ─► answers all queries for example.com
                         │
                         ▼
Records (A / Alias / CNAME / MX / TXT) ─► tell resolvers where to send each name
```

**Design notes:**
- The hosted zone's **NS records must match** what the registrar advertises — the #1 cause of "domain doesn't resolve."
- **TTL** controls cache duration; lower it before planned changes.
- Use **Alias** for AWS targets (apex-capable, free); CNAME only for non-AWS subdomains.
- Keep a clean record map: `@` (apex), `www`, `app`, `api`, plus `MX`/`TXT` for email.

---

## 2. SSL Architecture

**Goal:** Serve everything over **HTTPS** with a free, auto-renewing **AWS Certificate Manager (ACM)** certificate, validated via Route 53 DNS.

```
   Browser ──TLS handshake──► CloudFront / ALB  (presents ACM certificate)
                                   │  cert covers example.com + *.example.com
                                   ▼
                              Origin (S3 / EC2) over HTTPS/HTTP internally

   HOW THE CERT IS ISSUED (DNS validation):
   1. Request ACM cert for example.com & *.example.com
   2. ACM gives you CNAME validation records
   3. Add those CNAMEs to the Route 53 hosted zone (one click: "Create records in Route 53")
   4. ACM verifies you control the domain → issues the cert
   5. ACM AUTO-RENEWS as long as the validation CNAMEs stay in place
```

### Where the certificate lives (critical detail) ⚠️
| Front service | Where ACM cert must be | Region requirement |
|---------------|------------------------|--------------------|
| **CloudFront** | Attached to the distribution | Cert MUST be in **us-east-1 (N. Virginia)** |
| **ALB / API Gateway (regional)** | Attached to the listener | Cert in the **same Region** as the resource |

**Design notes:**
- 🔒 ACM certs are **free** and **auto-renew** (no Certbot needed) — but only when used with CloudFront/ALB/API Gateway/etc. (you can't export them to a raw EC2; for EC2-only, use Let's Encrypt — see [Phase 03 §6](../03-ec2/07-production-deployment-guide.md)).
- Request a **wildcard** `*.example.com` to cover all subdomains in one cert.
- DNS validation via Route 53 is one-click and renews automatically; **don't delete** the validation CNAMEs.
- Terminate TLS at CloudFront/ALB; traffic to the origin can be HTTP (within VPC) or HTTPS.

---

## 3. React Deployment Domain Setup

**Goal:** Put `example.com` (+ `www`) on a React SPA hosted on **S3 + CloudFront** with HTTPS. (Ties together [Phase 05 S3](../05-s3/01-s3-core-concepts.md#11-cloudfront-integration) + Route 53.)

```
   Users ─► example.com / www.example.com
              │  (Route 53 Alias)
              ▼
        CloudFront (HTTPS via ACM us-east-1, caches at edge)
              │  Origin Access Control (OAC)
              ▼
        PRIVATE S3 bucket (React build: index.html, assets)
```

### Records you create in the hosted zone
```
Name              Type    Routing   Target
example.com       A Alias Simple    → CloudFront distribution (dxxxx.cloudfront.net)
example.com       AAAA Alias Simple → CloudFront distribution (IPv6)
www.example.com   A Alias Simple    → CloudFront distribution (or → example.com)
```

### Step outline
```
1. Build React (npm run build) → upload to a PRIVATE S3 bucket  [Phase 05]
2. Request ACM cert for example.com + www.example.com  (in us-east-1)  → validate via Route 53
3. Create CloudFront distribution:
     - Origin = the S3 bucket (with OAC, bucket stays private)
     - Alternate domain names (CNAMEs) = example.com, www.example.com
     - Attach the ACM cert; default root object = index.html
     - Custom error response: 403/404 → /index.html (SPA routing)
4. In Route 53: Alias example.com & www → the CloudFront distribution
5. Browse https://example.com  ✅  (padlock, served from edge)
```

**Design notes:**
- ⚠️ Apex (`example.com`) → CloudFront **must** be an **Alias** (CNAME illegal at apex).
- SPA routing: map CloudFront 403/404 to `/index.html` so React Router paths work on refresh.
- After deploys, **invalidate** the CloudFront cache (`/*` or changed paths).
- Redirect `www` → apex (or vice-versa) for one canonical URL (CloudFront function or a second record).

---

## 4. Backend API Domain Setup

**Goal:** Put `api.example.com` on a **Node API behind an Application Load Balancer (ALB)** with HTTPS, health checks, and (optionally) failover. (Ties together [Phase 03 EC2](../03-ec2/02-ec2-architecture.md) + Route 53.)

```
   Clients ─► https://api.example.com
                 │  (Route 53 Alias, EvaluateTargetHealth=true)
                 ▼
            Application Load Balancer  (HTTPS listener, ACM cert in same Region)
                 │  target group, /health checks
        ┌────────┴────────┐
      EC2 (Node/PM2) AZ-a   EC2 (Node/PM2) AZ-b      [Phase 03]
```

### Records you create
```
Name              Type    Routing   Target
api.example.com   A Alias Simple    → ALB (my-alb-123.ap-south-1.elb.amazonaws.com)
api.example.com   AAAA Alias Simple → ALB (IPv6, if enabled)
```

### Step outline
```
1. Deploy the Node API on EC2 behind an ALB (target group + /health)  [Phase 03]
2. Request ACM cert for api.example.com IN THE ALB'S REGION → validate via Route 53
3. Add an HTTPS (443) listener on the ALB using the ACM cert
   (optional: redirect 80 → 443)
4. In Route 53: Alias api.example.com → the ALB (EvaluateTargetHealth=true)
5. Test: curl https://api.example.com/health  → 200 ✅
```

### Single EC2 (no ALB) variant
```
api.example.com  A  →  Elastic IP of the EC2     (plain A record, not Alias)
HTTPS via Let's Encrypt/Nginx on the instance     [Phase 03 §6-7]
```

### Adding resilience (optional)
```
api.example.com  (Failover routing)
   ├─ PRIMARY   Alias → ALB ap-south-1   [health check on /health]
   └─ SECONDARY Alias → ALB us-east-1     (standby Region)   → DR
```
Or **latency-based** routing across two Regions for active-active performance.

**Design notes:**
- ⚠️ ALB cert must be in the **ALB's Region** (CloudFront cert must be us-east-1).
- Use **Alias + EvaluateTargetHealth** so DNS reflects ALB/target health.
- Keep front end and API on the **same parent domain** (`example.com` / `api.example.com`) to simplify CORS and cookies.
- Add a lightweight `/health` endpoint for health checks and ALB target checks.

---

## Putting It All Together (one domain, full stack)
```
   example.com         Alias → CloudFront → S3 (React)        + ACM (us-east-1)
   www.example.com     Alias → CloudFront
   api.example.com     Alias → ALB → EC2 (Node/PM2 → RDS)     + ACM (region)
   @  MX               → email provider
   @  TXT              → SPF;  _dmarc TXT → DMARC;  selector._domainkey → DKIM
   (optional) failover/latency routing + health checks for DR
```
Records summary table:
| Name | Type | Target | Purpose |
|------|------|--------|---------|
| example.com | A/AAAA Alias | CloudFront | React site (apex) |
| www | A Alias | CloudFront / apex | www site |
| api | A/AAAA Alias | ALB | Node API |
| @ | MX | mail host | email |
| @ | TXT | SPF | anti-spoof |
| _dmarc | TXT | DMARC policy | email security |
| (ACM) | CNAME | ACM-provided | cert validation (auto) |

➡️ Next: [03-labs.md](03-labs.md)

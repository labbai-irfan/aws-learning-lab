# Module 1 — ELB Core Concepts

> Everything that makes up Elastic Load Balancing, explained from the ground up with diagrams and real CLI. Read top to bottom the first time; use it as a reference after.

**Topics:** What/why of load balancing · ELB family · ALB · NLB · GWLB (overview) · Listeners & Rules · Target Groups & Targets · Health Checks · SSL/TLS Termination · Sticky Sessions · Cross-Zone LB · Deregistration Delay (connection draining).

---

## 1. Why load balancing exists

A single EC2 instance is a **single point of failure** and a **scaling ceiling**:

```
   WITHOUT a load balancer                WITH a load balancer
   ──────────────────────                 ─────────────────────
   client ─► one EC2 (1.2.3.4)            client ─► LB DNS name
              │                                       │
   • instance dies → site down              ┌─────────┼─────────┐
   • CPU maxes  → slow for everyone         ▼         ▼         ▼
   • deploy     → downtime                EC2-a     EC2-b     EC2-c
   • IP changes → clients break           (any can die; LB routes around it)
```

A load balancer gives you:
1. **High availability** — spreads targets across Availability Zones; routes around failures.
2. **Scalability** — add/remove backends without changing the client-facing endpoint.
3. **One stable endpoint** — a single DNS name (and for NLB, static IPs) hides the fleet.
4. **Health awareness** — stops sending traffic to broken instances automatically.
5. **TLS offload** — terminates HTTPS centrally so backends stay simple.

💡 **Mental model:** the load balancer is a **smart receptionist** standing in front of your servers. Clients only ever talk to the receptionist; the receptionist decides which healthy worker handles each request.

---

## 2. The ELB family

| Type | Layer | Protocols | Use it for |
|------|-------|-----------|-----------|
| **Application Load Balancer (ALB)** | 7 | HTTP, HTTPS, gRPC, WebSocket | Web apps, REST APIs, microservices, anything needing content-based routing |
| **Network Load Balancer (NLB)** | 4 | TCP, UDP, TLS | Extreme performance, static IPs, non-HTTP protocols, source-IP preservation |
| **Gateway Load Balancer (GWLB)** | 3 | IP (GENEVE) | Inserting third-party virtual appliances (firewalls, IDS/IPS) inline |
| **Classic Load Balancer (CLB)** | 4 & 7 | HTTP, HTTPS, TCP, SSL | **Legacy** — EC2-Classic era. Don't build new systems on it. |

This course focuses on **ALB and NLB** (the two you'll actually use), with a short GWLB overview.

### Common anatomy (all modern ELBs share this)

```
   LOAD BALANCER  ──has──►  LISTENER(s)  ──has──►  RULE(s) [ALB]  ──forward to──►  TARGET GROUP
        │                       │                                                      │
   spans ≥2 subnets       port + protocol                                     health checks +
   (one per AZ)           (+ TLS cert for HTTPS)                               targets (EC2/IP/Lambda)
```

Memorize the chain: **LB → Listener → (Rule) → Target Group → Targets.** Almost every config and bug lives somewhere on this chain.

---

## 3. Application Load Balancer (ALB)

A **Layer 7** load balancer. It understands HTTP — so it can read the **path, host header, query string, HTTP method, and headers** and route accordingly.

### What ALB can do that NLB can't
- **Path-based routing** — `/api/*` → API fleet, `/*` → web fleet.
- **Host-based routing** — `app.example.com` vs `admin.example.com` on one ALB.
- **Header / query / method routing** — e.g. route `X-Version: beta` to a canary group.
- **Redirects & fixed responses** — HTTP→HTTPS redirect, or return a 503 maintenance page with no backend.
- **Authenticate users** — integrate Cognito / OIDC before the request reaches your app.
- **Native WebSocket & HTTP/2.**

### ALB request flow

```
   GET https://shop.example.com/api/orders
            │
            ▼
   [Listener HTTPS:443]  ── terminates TLS (ACM cert) ──► now plain HTTP internally
            │
            ▼   evaluate rules top-down (lowest priority number first)
   Rule 1: IF host = admin.example.com      → forward to TG-admin
   Rule 2: IF path  = /api/*                → forward to TG-api     ◄── matches
   Rule 3: IF path  = /static/*             → forward to TG-cdn
   Default: (everything else)               → forward to TG-web
            │
            ▼
   [TG-api] → pick a HEALTHY target → forward as HTTP to EC2:8080
```

⚠️ **ALB does NOT preserve the client's source IP** to the backend. The backend sees the ALB's private IP. The real client IP arrives in the **`X-Forwarded-For`** header (and proto in `X-Forwarded-Proto`, port in `X-Forwarded-Port`). Configure your app/web server to trust and read these.

💰 ALB billing = hourly charge + **LCUs** (Load Balancer Capacity Units). An LCU measures the max across: new connections/s, active connections, processed bytes, and rule evaluations.

---

## 4. Network Load Balancer (NLB)

A **Layer 4** load balancer. It forwards **TCP/UDP/TLS** without reading the payload — making it extremely fast (millions of requests/sec, ultra-low latency).

### NLB superpowers
- **Static IP per AZ** — you can assign an **Elastic IP** to each AZ. Great for allow-lists / firewall rules that demand fixed IPs. (ALB only gives a DNS name whose IPs rotate.)
- **Preserves the client source IP** natively — the backend sees the real client IP. No `X-Forwarded-For` needed.
- **Handles any TCP/UDP protocol** — databases, MQTT, SMTP, game servers, DNS, syslog.
- **TLS termination** at L4 (or pure TCP passthrough to let the backend terminate).
- **Scales instantly** with no pre-warming.

### NLB routing
NLB routes by **flow hash** (a 5-tuple: source IP, source port, dest IP, dest port, protocol). There are no path/host rules — only a listener per port forwarding to a target group.

```
   Client (TCP:443) ──► [NLB Listener TCP:443, EIP per AZ] ──► [TG TCP:8443]
                                                                   │ flow-hash
                                                          ┌────────┴────────┐
                                                          ▼                 ▼
                                                      EC2 (sees real     EC2
                                                       client IP)
```

⚠️ **NLB security:** an NLB does **not** have its own security group in the classic sense (newer NLBs optionally support SGs). Traffic often arrives at targets **with the client IP**, so your **target instances' security groups must allow the client CIDRs**, not the LB. (For instance targets with default settings, the SG sees the original client IP.) Test this carefully — it's a top source of "why is it timing out" bugs.

💰 NLB billing = hourly charge + **NLCUs** (new connections, active connections, processed bytes).

---

## 5. Gateway Load Balancer (GWLB) — overview only

A **Layer 3** load balancer used to deploy and scale **third-party network virtual appliances** — firewalls, deep-packet inspection, intrusion detection. It uses the **GENEVE protocol (port 6081)** and pairs with **GWLB Endpoints** to transparently route traffic through a fleet of appliances.

You'll rarely touch GWLB unless you run a security inspection layer. Know that it exists and what problem it solves; that's enough for most roles and exams.

---

## 6. Listeners & Rules

A **listener** = a **protocol + port** the load balancer accepts connections on.

| Listener | Common protocols/ports |
|----------|------------------------|
| ALB | `HTTP:80`, `HTTPS:443` |
| NLB | `TCP:443`, `UDP:53`, `TLS:443`, `TCP_UDP:port` |

### ALB listener rules
Each ALB listener has an **ordered list of rules** evaluated by **priority** (lowest number first). Each rule has:
- **Conditions** — `path-pattern`, `host-header`, `http-header`, `http-request-method`, `query-string`, `source-ip`.
- **Actions** — `forward` (to a target group, optionally weighted), `redirect`, `fixed-response`, `authenticate-cognito`, `authenticate-oidc`.
- A **default action** catches anything no rule matched.

🛠️ Classic, must-have rule — **redirect all HTTP to HTTPS**:
```bash
aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTP --port 80 \
  --default-actions '[{
    "Type":"redirect",
    "RedirectConfig":{"Protocol":"HTTPS","Port":"443","StatusCode":"HTTP_301"}
  }]'
```

🛠️ **Weighted forward** (the basis of blue/green & canary) — send 90% to blue, 10% to green:
```bash
aws elbv2 modify-listener --listener-arn <https-listener-arn> \
  --default-actions '[{
    "Type":"forward",
    "ForwardConfig":{"TargetGroups":[
      {"TargetGroupArn":"<tg-blue>","Weight":90},
      {"TargetGroupArn":"<tg-green>","Weight":10}
    ]}
  }]'
```

---

## 7. Target Groups & Targets

A **target group** is a named pool of backends **plus the health-check config that guards them**. Listeners/rules forward to target groups; target groups decide which actual target gets the request.

### Target types
| Target type | What it is | Notes |
|-------------|-----------|-------|
| **instance** | EC2 instance ID | LB sends to the instance's primary private IP |
| **ip** | Any IP in the VPC/peered/on-prem | For containers, on-prem (via Direct Connect/VPN), or fixed IPs |
| **lambda** | A Lambda function | ALB only — invoke a function per request |
| **alb** | Another ALB | NLB → ALB chaining (static IP in front of L7 routing) |

A target group is **protocol + port + target-type + VPC + health check**. The same instances can belong to multiple target groups (e.g. one TG per port).

### Key target-group attributes
- **Algorithm:** ALB = `round_robin` (default) or `least_outstanding_requests`; NLB = flow hash.
- **Deregistration delay** (connection draining) — see §11.
- **Stickiness** — see §10.
- **Slow start** — ramp traffic to newly-healthy targets over N seconds so they warm up.
- **Cross-zone load balancing** — see §9.

🛠️ Create a target group + register instances:
```bash
aws elbv2 create-target-group \
  --name tg-web --protocol HTTP --port 8080 \
  --vpc-id <vpc-id> --target-type instance \
  --health-check-path /healthz --health-check-protocol HTTP \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --health-check-interval-seconds 15 --health-check-timeout-seconds 5

aws elbv2 register-targets --target-group-arn <tg-arn> \
  --targets Id=<i-aaaa> Id=<i-bbbb>
```

💡 **Don't register instances by hand in production.** Attach the target group to an **Auto Scaling Group** so it registers/deregisters instances automatically as the fleet scales (see [Module 2](02-architectures.md)).

---

## 8. Health Checks

The health check is the **single most important** ELB concept to get right. It's a probe the target group sends to each target on an interval; targets that pass go **healthy** (receive traffic), targets that fail go **unhealthy** (cut off).

### Parameters
| Setting | Meaning | Sensible default |
|---------|---------|------------------|
| **Protocol** | HTTP / HTTPS (ALB), or TCP/HTTP/HTTPS (NLB) | HTTP |
| **Path** | URL to probe (ALB/HTTP) | `/healthz` |
| **Port** | `traffic-port` (same as target) or override | traffic-port |
| **Healthy threshold** | consecutive passes to mark healthy | 2–3 |
| **Unhealthy threshold** | consecutive fails to mark unhealthy | 2–3 |
| **Interval** | seconds between checks | 15–30 |
| **Timeout** | seconds to wait for a response | 5 |
| **Success codes** | HTTP codes counted as healthy (ALB) | `200` (or `200-299`) |

```
   Target group  ── every 15s ──►  GET /healthz on each target
                                      │
                    200 OK ──► pass    │     timeout / 5xx / wrong code ──► fail
                       │               │                                      │
              2 in a row → HEALTHY     │                          2 in a row → UNHEALTHY
              (gets traffic)           │                          (no traffic, stays in TG)
```

### Build a real health endpoint
A **good** `/healthz` checks the things that make *this instance* able to serve — ideally including its critical dependency (DB), but cheaply:

```js
// Express example
app.get('/healthz', async (req, res) => {
  try {
    await db.query('SELECT 1');           // shallow DB check
    res.status(200).send('ok');
  } catch (e) {
    res.status(503).send('db down');      // pull myself out of rotation
  }
});
```

⚠️ **Common health-check mistakes:**
- Health-check **port/path returns 301/302** (redirect) but success code is only `200` → all targets unhealthy. Set success codes or point at a non-redirecting path.
- **Security group** doesn't allow the LB (ALB) to reach the health-check port → all unhealthy.
- Health check hits `/` which loads the whole app/DB → slow, flaky checks. Use a light dedicated endpoint.
- Threshold/interval **too aggressive** → healthy instances flap during brief GC pauses. Too lax → slow to evict dead ones. Tune for your app.
- Health endpoint **too deep** (checks every downstream) → one slow dependency marks your whole fleet unhealthy and takes the site down. Keep it shallow.

💡 **Diagnose fast:** `aws elbv2 describe-target-health --target-group-arn <arg>` shows each target's state and a **reason** (`Target.Timeout`, `Target.ResponseCodeMismatch`, `Elb.RegistrationInProgress`, etc.). Start every "503 from the LB" investigation here.

---

## 9. Cross-Zone Load Balancing

Determines whether the LB spreads requests **evenly across all targets in all AZs**, or only across targets **within the same AZ** the request landed in.

```
   AZ-a: 2 targets      AZ-b: 8 targets

   Cross-zone OFF: each AZ's LB node splits its share only within its AZ
     → traffic hitting AZ-a node is split between 2 targets (each gets a LOT)
     → traffic hitting AZ-b node is split between 8 targets (each gets a little)
     → UNEVEN load per target

   Cross-zone ON: every LB node can send to ALL 10 targets
     → each of the 10 targets gets ~equal share → EVEN
```

| | ALB | NLB |
|---|-----|-----|
| Default | **ON** (and free within the LB) | **OFF** |
| Cross-AZ data charge | Free | **Charged** when ON (inter-AZ data transfer) |

💡 With **NLB**, turning cross-zone on gives smoother balancing but adds inter-AZ data-transfer cost. Keep AZ target counts balanced and you may not need it.

🛠️ Toggle it (target-group level):
```bash
aws elbv2 modify-target-group-attributes --target-group-arn <tg-arn> \
  --attributes Key=load_balancing.cross_zone.enabled,Value=true
```

---

## 10. Sticky Sessions (Session Affinity)

Stickiness pins a given client to the **same target** across requests. Useful when a server holds **in-memory session state** (a logged-in cart, a WebSocket, a server-side session not shared via Redis/DB).

### ALB stickiness — cookie based
| Mode | Cookie | When to use |
|------|--------|-------------|
| **Duration-based** | ALB-generated `AWSALB` cookie | Generic apps; you set how long the pin lasts |
| **Application-based** | Your app's cookie name (ALB wraps it as `AWSALBAPP`) | You want stickiness tied to your own session cookie lifecycle |

```
   First request  ──► ALB picks Target-B ──► response + Set-Cookie: AWSALB=<encodes B>
   Next requests  ──► client sends AWSALB ──► ALB routes straight to Target-B
```

🛠️ Enable duration-based stickiness (1 hour):
```bash
aws elbv2 modify-target-group-attributes --target-group-arn <tg-arn> \
  --attributes \
    Key=stickiness.enabled,Value=true \
    Key=stickiness.type,Value=lb_cookie \
    Key=stickiness.lb_cookie.duration_seconds,Value=3600
```

### NLB stickiness — source-IP (flow) based
NLB can pin by **source IP** (client stays on one target as long as the flow lives). No cookies (it's L4).

### ⚠️ The big caveat
Sticky sessions are a **crutch, not an architecture**:
- They cause **uneven load** — one popular client/target gets hot.
- They break **graceful scaling** — when a sticky target is removed, those users lose their session.
- They don't survive **target replacement** (Auto Scaling, deploys).

💡 **Better pattern:** make your app **stateless** — store sessions in **ElastiCache (Redis)**, **DynamoDB**, or a JWT — and you won't need stickiness at all. Any target can serve any request, scaling and failover "just work." Use stickiness only when you genuinely can't externalize state (legacy apps, certain WebSocket setups).

---

## 11. Connection Draining (Deregistration Delay)

When a target is removed (scale-in, deploy, manual deregister), you don't want to **kill in-flight requests**. The **deregistration delay** keeps the target in `draining` state — it finishes existing connections but receives no new ones — for up to N seconds.

```
   Deregister target ──► state: draining (default 300s)
       • existing requests: allowed to complete
       • new requests:      NOT routed here
   ──► after delay (or all conns done) ──► target fully removed
```

🛠️ Set it (e.g. 30s for short-lived HTTP APIs):
```bash
aws elbv2 modify-target-group-attributes --target-group-arn <tg-arn> \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30
```

💡 Tune to your **longest reasonable request**. APIs: 15–30s. Long downloads/uploads or WebSockets: longer. Too long and deploys/scale-in crawl; too short and you cut off users mid-request.

---

## 12. SSL / TLS Termination

**TLS termination** = the load balancer decrypts incoming HTTPS, so your backends can speak plain HTTP (or re-encrypted HTTP/HTTPS). This centralizes certificate management and offloads crypto from your app servers.

```
   Client ──HTTPS (encrypted)──► [ALB HTTPS:443]  ── decrypt (ACM cert) ──► ──HTTP──► EC2:8080
                                  TLS terminates here          (backend speaks plain HTTP)
```

### Three patterns
| Pattern | Client→LB | LB→Target | Use when |
|---------|-----------|-----------|----------|
| **TLS termination** | HTTPS | HTTP | Most web apps. Simplest. Backend is in a private subnet. |
| **TLS re-encryption (end-to-end)** | HTTPS | HTTPS | Compliance (PCI/HIPAA) requires encryption on the wire even inside the VPC. ALB re-encrypts to backend. |
| **TLS passthrough** | TLS (TCP) | TLS (TCP) | NLB only; backend must hold the cert and terminate. The LB never sees plaintext. |

### Certificates with ACM
**AWS Certificate Manager (ACM)** issues **free, public, auto-renewing** TLS certs you attach to ALB/NLB listeners. No more manual cert renewals.

🛠️ Request a cert (DNS validation is easiest if your domain is in Route 53):
```bash
aws acm request-certificate --domain-name shop.example.com \
  --subject-alternative-names "*.shop.example.com" \
  --validation-method DNS
# then create the CNAME records ACM gives you (Route 53 can do this in one click)
```

🛠️ Attach it to an HTTPS listener:
```bash
aws elbv2 create-listener --load-balancer-arn <alb-arn> \
  --protocol HTTPS --port 443 \
  --certificates CertificateArn=<acm-cert-arn> \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>
```

### SNI — many certs on one listener
**Server Name Indication** lets one HTTPS listener serve **multiple domains, each with its own cert**. Add a default cert plus extra certs; the ALB picks the right one based on the hostname the client requested.
```bash
aws elbv2 add-listener-certificates --listener-arn <https-listener-arn> \
  --certificates CertificateArn=<cert-for-admin.example.com>
```

### Security policies
The **SSL policy** controls which TLS versions & cipher suites the LB accepts. Prefer a modern policy (e.g. `ELBSecurityPolicy-TLS13-1-2-2021-06`) to drop old TLS 1.0/1.1. 🔒 Don't use legacy policies unless a client truly requires them.

⚠️ **ACM region gotcha:** for ALB/NLB the cert must be in the **same region** as the load balancer. (Only CloudFront needs certs in `us-east-1`.)

---

## 13. Putting it together — full request lifecycle

```
   1. Client resolves  shop.example.com  → Route 53 → ALB DNS (A/ALIAS record)
   2. Client opens HTTPS:443 to an ALB node (one per AZ)
   3. Listener HTTPS:443 terminates TLS using the ACM cert
   4. Listener rules evaluate (path/host) → choose Target Group
   5. Target Group lists HEALTHY targets (health checks passing)
   6. Algorithm picks one (round-robin / least-outstanding); stickiness may pin it
   7. ALB forwards as HTTP to EC2:8080, adding X-Forwarded-For/Proto/Port
   8. App responds; ALB returns it over the client's TLS connection
   9. On scale-in/deploy, deregistration delay drains the target gracefully
```

---

## ✅ Module 1 checklist
You should now be able to explain, without notes:
- [ ] When to choose ALB vs NLB (and why CLB is legacy).
- [ ] The chain LB → Listener → Rule → Target Group → Target.
- [ ] How health checks decide healthy/unhealthy and the top failure reasons.
- [ ] What TLS termination/re-encryption/passthrough mean and where ACM fits.
- [ ] Why sticky sessions are a crutch and what to do instead.
- [ ] Cross-zone LB and deregistration delay, and how to set them.

➡️ Next: [02-architectures.md](02-architectures.md) — turn these pieces into HA, multi-server, auto-scaling production designs.

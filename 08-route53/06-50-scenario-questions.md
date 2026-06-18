# Module 6 — 50 Route 53 Scenario Questions (with Solutions)

> Real "what would you do / design" situations. Decide first, then check the **Solution**. Mirrors Solutions Architect interviews and on-call DNS incidents.

---

### Domain & Hosted Zone Setup
**1.** You bought example.com at GoDaddy but want to manage DNS in AWS.
→ Create a **Route 53 hosted zone**, copy its 4 **NS** records, and set them as GoDaddy's name servers. Route 53 becomes authoritative.

**2.** After moving NS to Route 53, the site still shows the old host for some users.
→ **DNS caching/propagation**; wait out the TTL and verify with `dig @8.8.8.8`. Nothing is broken if records are correct.

**3.** You need internal names (db.internal.example.com) resolvable only inside your VPC.
→ A **private hosted zone** associated with the VPC.

**4.** You deleted and recreated a hosted zone; resolution broke.
→ The new zone has **new NS records**; update the registrar's NS to match.

**5.** Same name must resolve to a private IP internally and a public IP externally.
→ **Split-horizon DNS**: a private hosted zone (VPC) + a public hosted zone, same name, different records.

**6.** A domain expired and the site went down.
→ Renew immediately (grace period); enable **auto-renew** and registrar lock to prevent recurrence.

---

### A / CNAME / Alias
**7.** You must point example.com (apex) at a CloudFront distribution.
→ Use an **Alias A/AAAA** record (CNAME is illegal at the apex).

**8.** A developer set a CNAME on the apex and it won't save.
→ Expected — replace it with an **Alias** record.

**9.** You're being charged for DNS queries pointing www → ALB via CNAME.
→ Switch to an **Alias** (free for AWS targets) and it works at apex too.

**10.** Map blog.example.com to a third-party WordPress host.
→ A **CNAME** to the vendor's hostname (non-AWS target, subdomain — CNAME is fine).

**11.** Point api.example.com at an ALB whose IPs change as it scales.
→ **Alias** to the ALB (auto-tracks IPs); don't hard-code an A record.

**12.** Need both www and apex to serve the same React site on CloudFront.
→ Alias **example.com** and **www.example.com** to the distribution (or alias www → apex), and add both to the cert/CloudFront alternate names.

**13.** You want one canonical URL (force www → apex).
→ Redirect at the edge (CloudFront function / S3 redirect / ALB rule); DNS just points both names.

**14.** Point an apex at an S3 static website with HTTPS.
→ Front S3 with **CloudFront** + ACM, then **Alias** the apex to CloudFront (S3 website endpoint alone is HTTP-only).

---

### Email (MX/TXT)
**15.** Set up Google Workspace email for example.com.
→ Add the provider's **MX** record(s) at the apex plus **SPF/DKIM/DMARC** TXT/CNAME records.

**16.** Outbound mail keeps landing in spam.
→ Add/repair **SPF, DKIM, and DMARC** records; warm up sender reputation.

**17.** A SaaS asks you to "verify domain ownership."
→ Add the provided **TXT** (or CNAME) record to the hosted zone.

**18.** You need a backup mail server.
→ Add a second **MX** with a higher priority number (used if the primary is down).

**19.** SPF check fails with "too many DNS lookups."
→ Consolidate includes to stay within the **10-lookup** SPF limit.

**20.** DKIM isn't validating.
→ Add the provider's **selector._domainkey** record exactly as given.

---

### Routing Policies
**21.** Roll out a new app version to 10% of users first.
→ **Weighted routing** (90/10), increasing the canary weight as confidence grows.

**22.** Serve users from the lowest-latency Region across us/eu/ap.
→ **Latency-based routing** to per-Region endpoints.

**23.** EU users must hit EU servers for data-residency compliance.
→ **Geolocation routing** by continent/country (with a default record).

**24.** Block traffic from a specific country.
→ **Geolocation routing** returning a block page (or no answer) for that location, default for the rest.

**25.** Simple client-side load balancing with health awareness, no ELB.
→ **Multivalue answer routing** with health checks (returns up to 8 healthy records).

**26.** Active-passive disaster recovery between two Regions.
→ **Failover routing**: primary with a health check, secondary standby.

**27.** Active-active across two Regions, split by performance.
→ **Latency-based** (or weighted) routing with health checks on both.

**28.** Gradually shift traffic from an on-prem data center to AWS.
→ **Weighted routing**, increasing the AWS weight over time.

**29.** You set weighted records but all traffic goes to one.
→ Each needs a unique **SetIdentifier**; check weights aren't 0 and records are distinct.

**30.** Nested logic: route by country, then by latency within the country's Region group.
→ **Traffic Flow** to combine geolocation → latency → weighted policies.

---

### Health Checks & Failover
**31.** Automatically route around a downed primary endpoint.
→ Attach a **health check** to the PRIMARY failover record; secondary serves on failure.

**32.** Failover works but clients take minutes to switch.
→ **Lower the record TTL** (e.g., 60s) so clients re-resolve faster.

**33.** Health check reports unhealthy though the server is up.
→ Route 53 checker IPs are blocked — **allow the health-checker ranges** in the SG, or use a CloudWatch-alarm check.

**34.** Need to health-check a private internal service.
→ Use a **CloudWatch alarm** health check (public checkers can't reach private IPs).

**35.** Provide a cheap "we're down" page during outages.
→ Failover **secondary = an S3 static maintenance site**.

**36.** /health returns 200 but the app is actually broken (DB down).
→ Make **/health verify real dependencies** so it fails when they do.

**37.** Combine multiple checks into one decision.
→ A **calculated health check** (e.g., healthy if ≥2 of 3 pass).

**38.** Get alerted when the primary fails.
→ Health check → **CloudWatch alarm → SNS** notification.

---

### SSL / HTTPS
**39.** Add free HTTPS to a CloudFront-hosted React app.
→ **ACM certificate in us-east-1**, DNS-validated via Route 53, attached to the distribution.

**40.** ACM cert for an ALB won't attach.
→ The cert must be in the **ALB's Region** (CloudFront needs us-east-1; ALB needs its own Region).

**41.** ACM cert stuck on "Pending validation."
→ Add the **validation CNAME** records to the hosted zone (one-click in ACM).

**42.** Cert expired even though ACM auto-renews.
→ Someone deleted the **validation CNAMEs**; re-add them and reissue.

**43.** Cover example.com and all subdomains with one cert.
→ Request a **wildcard** `*.example.com` (plus the apex as a SAN).

**44.** EC2-only app (no ALB/CloudFront) needs HTTPS.
→ ACM can't be exported to EC2 — use **Let's Encrypt/Nginx** on the instance ([Phase 03 §6–7](../03-ec2/07-production-deployment-guide.md)).

---

### Full-Stack & Operations
**45.** Wire example.com (React) + api.example.com (Node) under one domain.
→ Alias **apex/www → CloudFront** (S3 React) and **api → ALB** (EC2 Node); ACM certs in the right Regions; keep them same-parent-domain to simplify CORS.

**46.** Need near-zero-downtime DNS cutover to a new endpoint.
→ **Pre-lower the TTL**, change the record, verify, then raise TTL.

**47.** Multi-Region app with automatic regional failover and best performance.
→ **Latency-based routing + health checks** (active-active), or failover for active-passive.

**48.** Audit who changed DNS records.
→ **CloudTrail** logs Route 53 API changes.

**49.** Reduce DNS costs on a high-traffic AWS-fronted site.
→ Use **Alias** records (free for AWS targets) and reasonable TTLs to cut query volume.

**50.** End-to-end: a user can't reach https://app.example.com — triage.
→ Check registration/expiry → registrar NS == hosted zone NS → record exists/correct → fresh resolver (`dig @8.8.8.8`) → endpoint up + valid TLS (`curl -v`) → routing/health logic. See [Module 4](04-troubleshooting.md).

---

## Pattern Reflexes (memorize)
```
"apex → AWS resource"        → Alias (never CNAME)
"subdomain → non-AWS host"   → CNAME
"% / canary rollout"         → Weighted
"best performance multi-Region" → Latency-based
"by country / compliance"    → Geolocation
"active-passive DR"          → Failover + health check
"active-active"              → Latency/Weighted + health checks
"HA without ELB"             → Multivalue + health checks
"free auto HTTPS (CF)"       → ACM in us-east-1 + Alias
"free auto HTTPS (ALB)"      → ACM in ALB Region + Alias
"private resource health"    → CloudWatch-alarm health check
"fast cutover/failover"      → lower TTL first
"doesn't resolve"            → registrar NS == hosted zone NS
"email + anti-spam"          → MX + SPF/DKIM/DMARC (TXT)
```

🎉 **Phase 08 complete.** You can now register domains, design hosted zones, choose the right record type and routing policy, add HTTPS, build failover, and put real apps on real domains.

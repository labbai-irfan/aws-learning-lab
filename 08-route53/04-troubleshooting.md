# Module 4 — Route 53 Troubleshooting Guide

> Symptom → likely cause → fix, grouped by: resolution, propagation/TTL, records, Alias/CNAME, SSL/ACM, routing/failover, email, and health checks. Plus the diagnostic command toolkit.

---

## The Diagnostic Toolkit (use these first)
```bash
dig example.com A +short          # what IP does it resolve to?
dig example.com NS +short         # which name servers are authoritative?
dig +trace example.com            # full delegation path (root → TLD → authoritative)
dig @8.8.8.8 example.com +short   # bypass local cache; query Google's resolver
dig api.example.com CNAME +short  # see the CNAME chain
nslookup example.com              # Windows-friendly
curl -v https://api.example.com/health   # test the actual endpoint + TLS
whois example.com                 # registrar, expiry, name servers
```
💡 Always test against a **public resolver** (`@8.8.8.8` / `@1.1.1.1`) to rule out local caching.

---

## A. Domain Doesn't Resolve At All

```
Check order:
1. Is the domain registered & not expired?            whois example.com
2. Do the registrar's NS match the hosted zone's NS?  dig example.com NS  vs  hosted zone
3. Does the hosted zone have the record?              list-resource-record-sets
4. Are you looking at a stale cache?                   dig @8.8.8.8 (fresh resolver)
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `NXDOMAIN` everywhere | Domain unregistered/expired, or no record | Register/renew; add the record |
| Resolves to old/none after moving to R53 | Registrar NS not updated to Route 53's 4 NS | Set registrar NS to the hosted zone's NS |
| Works on some networks, not others | Propagation/cache | Wait for TTL; test `@8.8.8.8` |
| Two hosted zones for same domain | Duplicate zone; registrar points to the other | Use one zone; point NS to it |
| Recreated hosted zone, now broken | New zone = new NS records | Update registrar NS to the new zone's NS |

⚠️ **#1 real-world issue:** the hosted zone's **NS records don't match the registrar**. They must be identical.

---

## B. Changes Not Taking Effect (Propagation / TTL)

| Symptom | Cause | Fix |
|---------|-------|-----|
| Old value still served after edit | Resolvers cached it for the TTL | Wait out the TTL; lower TTL **before** future changes |
| Some users updated, others not | Different caches expire at different times | Be patient; verify with `dig @8.8.8.8` |
| Need a fast cutover | High TTL set | Lower TTL (e.g., 60s) ahead of time, change, then raise |

💡 Route 53 itself updates in **seconds**; what you're waiting on is **downstream resolver caches** (governed by the record's TTL).

---

## C. Record Problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can't create CNAME at apex | DNS forbids CNAME at zone apex | Use an **Alias** record instead |
| CNAME + other record same name | Not allowed with CNAME | Remove conflicting record or use Alias |
| Wrong IP returned | Stale/incorrect A record | Fix the A value; check TTL |
| Multiple A values, inconsistent | Round-robin behavior | Expected; use a load balancer/policy for control |
| Trailing-dot confusion | FQDN formatting | Route 53 handles it; be consistent |

---

## D. Alias / CNAME Confusion

| Symptom | Cause | Fix |
|---------|-------|-----|
| Apex won't point to ALB/CloudFront | Tried a CNAME at apex | Use **Alias** (apex-capable) |
| Alias dropdown empty / wrong target | Resource not in expected scope/Region | Ensure the AWS resource exists; pick correct type |
| Extra DNS charges | Using CNAME to AWS resources | Switch to **Alias** (free for AWS targets) |
| Alias not failing over | EvaluateTargetHealth not set | Set `EvaluateTargetHealth=true` |

---

## E. SSL / HTTPS / ACM Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Cert stuck "Pending validation" | Validation CNAME not added | Add ACM's CNAME(s) to the hosted zone (one-click in ACM) |
| CloudFront won't accept cert | Cert not in **us-east-1** | Request/import the cert in us-east-1 for CloudFront |
| ALB won't accept cert | Cert not in the ALB's Region | Request the cert in the ALB's Region |
| Cert expired unexpectedly | Validation CNAME deleted (auto-renew broke) | Re-add validation records; reissue |
| `NET::ERR_CERT_COMMON_NAME_INVALID` | Domain not on the cert | Reissue covering the exact name (or wildcard) |
| HTTPS works on www, not apex | Apex not aliased / not on cert | Alias apex to CloudFront/ALB; include apex in cert |

🔒 ACM certs are free + auto-renew **only** while their DNS validation records remain. Don't delete them.

---

## F. Routing Policy / Failover Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Weighted split not working | Missing/duplicate `SetIdentifier` | Each record needs a unique SetIdentifier |
| Failover never switches | No/failing health check on primary | Attach a working health check to the PRIMARY record |
| Failover too slow for clients | High TTL caches the old answer | Lower the record TTL (e.g., 60s) |
| Latency routing picks "wrong" Region | Based on network latency, not geography | Expected; use geolocation if you need country-based |
| Geolocation gaps (no match) | No default location record | Add a default ("*") geolocation record |
| Multivalue returns unhealthy IPs | No health checks attached | Attach health checks to each record |

---

## G. Email (MX/TXT) Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Email not arriving | Missing/incorrect MX | Add MX with correct host + priority |
| Mail flagged as spam | No SPF/DKIM/DMARC | Add TXT SPF, DKIM (CNAME/TXT), DMARC TXT |
| SPF "too many lookups" | Multiple includes | Consolidate SPF; stay ≤10 DNS lookups |
| Verification failing | TXT value/quoting wrong | Match provider's exact string; mind quotes |
| DKIM not validating | Wrong selector record | Add the provider's `selector._domainkey` record |

---

## H. Health Check Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Endpoint healthy but R53 says unhealthy | Security group/firewall blocks R53 checkers | Allow Route 53 health-checker IP ranges; or use a CloudWatch-alarm health check |
| Private resource can't be checked | R53 checkers are public | Use a **CloudWatch alarm** health check |
| Flapping health status | Threshold too low / endpoint slow | Raise failure threshold; fix endpoint latency |
| `/health` returns 200 but app broken | Shallow check | Make `/health` verify real dependencies (DB, etc.) |
| HTTPS health check fails | SNI/cert/path issue | Enable SNI; verify the path returns 2xx/3xx |

---

## General Diagnostic Order
```
1. Is it registered & not expired?           whois
2. Do registrar NS == hosted zone NS?        dig NS  vs zone
3. Does the record exist & is it correct?     list-resource-record-sets
4. Cache vs reality?                          dig @8.8.8.8 +short  (fresh resolver)
5. Endpoint actually up + TLS valid?          curl -v https://...
6. Routing/health logic correct?              check SetIdentifier / health check / TTL
```

## Quick Reference
```
Doesn't resolve   → registration + NS match + record exists
Old value sticks  → TTL/cache; lower TTL before changes; test @8.8.8.8
Apex → AWS        → use Alias (not CNAME)
Cert pending      → add ACM validation CNAME; right Region (us-east-1 for CloudFront)
No failover       → health check on PRIMARY + low TTL
Email/spam        → MX + SPF/DKIM/DMARC (TXT)
False unhealthy   → allow checker IPs or use CloudWatch-alarm health check
```

➡️ Next: [05-100-interview-questions.md](05-100-interview-questions.md)

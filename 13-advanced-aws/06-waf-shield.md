# Module 6 — WAF & Shield: Edge Security

> Protect applications from web attacks (WAF) and DDoS (Shield) at the network and application edge.

---

## Part A — AWS WAF (Web Application Firewall)

### 1. What WAF does
WAF inspects **HTTP/HTTPS requests** and allows, blocks, or counts based on **rules**. It sits at:
- **CloudFront** (global, closest to users) ← preferred for public apps
- **ALB** (regional)
- **API Gateway** / **AppSync** / **Cognito**

```
   User ──► CloudFront ──[WAF Web ACL]──► Origin
                            Block: SQL injection, XSS, bad bots, rate limit, IP block
                            Allow: everything else
```

### 2. Web ACL structure
```
   Web ACL
     ├── Rule 1: AWS-AWSManagedRulesCommonRuleSet     (OWASP top 10)      Priority 10
     ├── Rule 2: AWS-AWSManagedRulesSQLiRuleSet       (SQL injection)     Priority 20
     ├── Rule 3: AWS-AWSManagedRulesBotControlRuleSet (bot detection)     Priority 30
     ├── Rule 4: Custom: RateLimit 2000/5min per IP   (brute-force)       Priority 40
     ├── Rule 5: Custom: Block IP set (known bad IPs)                     Priority 50
     └── Default action: Allow
```

### 3. Managed rule groups
AWS provides pre-built rule groups:
| Group | Protects against |
|---|---|
| `AWSManagedRulesCommonRuleSet` | OWASP Top 10 (SQLi, XSS, bad input) |
| `AWSManagedRulesSQLiRuleSet` | SQL injection specifically |
| `AWSManagedRulesKnownBadInputsRuleSet` | Log4j, known exploit patterns |
| `AWSManagedRulesBotControlRuleSet` | Scrapers, crawlers, bots |
| `AWSManagedRulesAmazonIpReputationList` | Known AWS threat IPs |
| Marketplace rules | Imperva, F5, Fortinet (paid) |

### 4. Rate limiting (the most common custom rule)
```json
{
  "Name": "RateLimitPerIP",
  "Priority": 40,
  "Action": { "Block": {} },
  "Statement": {
    "RateBasedStatement": {
      "Limit": 2000,
      "AggregateKeyType": "IP",
      "EvaluationWindowSec": 300
    }
  }
}
```
💡 Rate limit on: `/api/login` (lower limit, e.g. 50/5min) separately from general traffic to stop credential stuffing.

### 5. Custom rules
- **IP sets** — block/allow specific CIDRs.
- **Geo match** — block countries you don't serve.
- **String match / regex** — block specific user-agents, paths, headers.
- **Label matching** — chain rules: earlier rule labels a request, later rule acts on the label.

### 6. WAF logging & monitoring
- Enable WAF logs → **Kinesis Firehose** → S3 → Athena for analysis.
- **CloudWatch metrics** per rule: `BlockedRequests`, `AllowedRequests`, `CountedRequests`.
- Set alarms on `BlockedRequests` spikes (attack in progress).

---

## Part B — AWS Shield

### 7. Shield Standard (free, automatic)
- **Always on** for all AWS customers at no extra cost.
- Protects against **Layer 3/4 DDoS**: SYN floods, UDP reflection, volumetric attacks.
- Works on **EC2, ELB, CloudFront, Route 53, Global Accelerator**.

### 8. Shield Advanced ($3,000/month)
Additional protections:
- **Layer 7 DDoS** protection (HTTP floods) via WAF integration.
- **Cost protection** — AWS credits DDoS-related scaling costs.
- **DDoS Response Team (SRT)** — AWS engineers help during attacks.
- **Proactive engagement** — SRT contacts you when a large attack is detected.
- **Detailed attack diagnostics** in the console.
- **Health-based detection** using Route 53 health checks.

```
   Shield Standard: Layer 3/4 protection, automatic, free
   Shield Advanced: + Layer 7, + SRT, + cost protection, + enhanced visibility
```

### 9. When to use Shield Advanced
- You handle significant traffic that's a DDoS target (finance, gaming, e-commerce, government).
- You run CloudFront + Route 53 at scale.
- Regulatory requirements for DDoS protection SLAs.
- You want SRT support during incidents.

### 10. WAF + Shield Advanced together
```
   DDoS (L3/4)  ──► Shield Advanced blocks volumetric attack automatically
   HTTP flood    ──► WAF rate-based rules + Shield Advanced detection
   SQLi/XSS      ──► WAF managed rules (SQLi, CommonRuleSet)
   Bot traffic   ──► WAF Bot Control managed rule group
```

---

## Part C — Production patterns

### 11. Defence-in-depth at edge
```
   Route 53 (geo-routing, health checks) ─► Shield covers here
   CloudFront (global CDN) ─────────────► WAF Web ACL attached
   ALB (regional) ──────────────────────► WAF Web ACL (regional, for backup)
   App (ECS/EC2) ──────────────────────► Security group, NACLs
```

### 12. WAF for SaaS / multi-tenant
- Add a **tenant ID header** at ALB; WAF rules can validate it.
- Rate limit per **tenant** using a custom header as aggregate key.
- Geo-restrict per tenant (enterprise customers may require data residency).

### 13. Common WAF mistakes ⚠️
- Attaching a WAF to CloudFront requires the Web ACL be in **us-east-1** (global scope).
- Managed rule groups run in **Count mode first** before blocking — validate no false positives.
- WAF costs per request at high traffic — budget for it.
- Logging to Firehose adds latency cost — aggregate and alert asynchronously.

---

## ✅ WAF + Shield checklist
- [ ] WAF Web ACL on CloudFront (and ALB as backup)
- [ ] Managed rule groups: CommonRuleSet + SQLi + KnownBadInputs at minimum
- [ ] Rate limit on login/API endpoints
- [ ] IP reputation list rule group
- [ ] WAF logs → S3 + alarm on spike
- [ ] Shield Advanced if: large-scale public app / regulated / DDoS history
- [ ] Tested in Count mode before switching to Block

➡️ Next: [Module 7 — Organizations & Multi-Account Strategy](07-organizations-multi-account.md)

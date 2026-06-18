# Project — Resilient DNS: Failover + Latency Routing

> Capstone: put a real domain in front of your app with **automatic failover** (active-passive DR) and, optionally, **latency-based** global routing — all driven by Route 53 health checks.

**You'll build:**
```
                         Route 53 hosted zone (example.com)
                                     │
            ┌──────────── FAILOVER routing + health checks ───────────┐
            │ PRIMARY (healthy)                    SECONDARY (standby) │
            ▼                                              ▼
   ALIAS → ALB / app (Region A)              ALIAS → static "maintenance"
   health check: /api/health                or ALB in Region B
```

**Prerequisites:** a registered domain (or register one in the lab), a deployable app behind an ALB/CloudFront (the [Phase 07 web tier](../../07-elb-autoscaling/project/README.md) is ideal), AWS CLI v2. Read [01](../01-route53-core-concepts.md) + [02 Architectures](../02-architectures.md) first.

---

## Part 1 — Domain on your app (apex + www)
1. **Hosted zone** for `example.com`; point the registrar's **NS** at Route 53.
2. **ALIAS A** record at the apex → your ALB/CloudFront (CNAME can't sit at the apex).
3. `www` → apex (ALIAS or CNAME). Add an **ACM** cert for HTTPS on the ALB.
✅ `https://example.com` and `https://www.example.com` both resolve and serve.

## Part 2 — Failover routing (active-passive DR)
1. Create a **health check** on the primary (`HTTPS /api/health`, 200).
2. Primary record: **Failover = Primary**, ALIAS → primary ALB, associate the health check (or "evaluate target health").
3. Secondary record: **Failover = Secondary**, ALIAS → a standby (an S3/CloudFront maintenance page, or a second-Region ALB).
✅ **Break the primary** (stop the app / fail the health check) → within the health-check interval, Route 53 serves the **secondary**. Restore → traffic returns to primary.

```bash
aws route53 create-health-check --caller-reference $(date +%s) \
  --health-check-config Type=HTTPS,FullyQualifiedDomainName=app.example.com,Port=443,ResourcePath=/api/health,RequestInterval=10,FailureThreshold=2
# then create PRIMARY/SECONDARY record sets with Failover + HealthCheckId via change-resource-record-sets
```

## Part 3 (stretch) — Latency / geolocation routing
- Deploy the app in **two Regions**; create **latency** record sets so each user hits the closest Region.
- Or **geolocation** routing to serve region-specific content/compliance.
✅ Resolving from different locations returns different Regional endpoints.

## Acceptance checklist ✅
- [ ] Apex + www both load over HTTPS.
- [ ] Failing the primary health check fails traffic over to the secondary automatically.
- [ ] Restoring the primary returns traffic to it.
- [ ] (Stretch) latency routing sends users to the nearest Region.
- [ ] TTLs are sensible (lowered before the cutover test).

## Cleanup 💰
Delete the health checks and record sets; delete the hosted zone if you don't need it (a hosted zone bills ~$0.50/month). Keep the domain registration if you want it.

---
*Back to [Route 53 README](../README.md).*

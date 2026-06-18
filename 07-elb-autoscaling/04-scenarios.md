# Module 4 — 50 Production Scenarios

> Realistic situations an engineer faces with ELB. Read the scenario, **decide your answer before reading the solution**. Each solution gives the *why*, not just the *what*. Grouped by theme.

**Legend:** 🎯 = the core lesson.

---

## A. Choosing & sizing the load balancer (1–8)

**1. A REST API needs path-based routing (`/api/*`, `/admin/*`).** Which LB?
→ **ALB.** Only L7 understands paths. NLB routes by port only. 🎯 Content-based routing = ALB.

**2. A multiplayer game uses UDP. Which LB?**
→ **NLB** (supports UDP). ALB is HTTP-only. 🎯 Non-HTTP protocol = NLB.

**3. A partner will only allow-list 3 fixed IP addresses to reach you, but you need ALB's L7 routing.**
→ **NLB with Elastic IPs in front of the ALB** (`target-type: alb`). NLB gives static IPs; ALB gives routing. 🎯 Static IP + L7 = NLB→ALB chain.

**4. You need to handle 5 million requests/sec with sub-millisecond added latency.**
→ **NLB.** Built for extreme throughput/low latency with no pre-warming. 🎯 Extreme scale/latency = NLB.

**5. Your backend must see the real client IP for geo-logic, and you're on HTTP.**
→ Either: **ALB + read `X-Forwarded-For`** (app change), or **NLB** which preserves source IP natively. Pick ALB if you want L7 features; NLB if you can't change the app. 🎯 ALB hides the IP behind XFF.

**6. Someone proposes a new system on Classic Load Balancer.**
→ Push back. **CLB is legacy.** Use ALB (HTTP) or NLB (TCP/UDP). 🎯 Don't build new on CLB.

**7. A microservices team wants each service to scale and deploy independently but share one entry point.**
→ **One ALB, one target group + ASG per service, path/host rules.** 🎯 ALB rules fan out to per-service target groups.

**8. You need to insert a third-party firewall appliance inline for all traffic.**
→ **Gateway Load Balancer (GWLB)** + GWLB endpoints. 🎯 Inline security appliances = GWLB.

---

## B. High availability (9–16)

**9. The ALB was created with subnets in only one AZ. Risk?**
→ **No HA** — that AZ's failure takes the LB down. Add a subnet from a second AZ. 🎯 ALB needs ≥2 AZ subnets.

**10. You have 6 instances but all in AZ-a.** Is this HA?
→ **No.** AZ-a failure = total outage. Spread across ≥2 AZs. 🎯 Targets must span AZs, not just the LB.

**11. An entire AZ goes down. What should happen automatically?**
→ ALB health checks fail for that AZ's targets → traffic shifts to the healthy AZ; the ASG launches replacements in surviving AZs. **Zero manual action** if configured right. 🎯 Health checks + ASG = auto AZ failover.

**12. During AZ-a outage, the surviving AZ-b instances are overwhelmed.**
→ You lacked **N+1 capacity**. Provision so one AZ's instances can absorb the full load (or let the ASG scale out fast with low cooldown). 🎯 Plan capacity for AZ loss.

**13. Load is uneven: AZ-a has 2 targets getting hammered, AZ-b has 8 idle (NLB).**
→ Enable **cross-zone load balancing** (off by default on NLB), or balance target counts per AZ. Note the inter-AZ data cost. 🎯 Cross-zone evens out unequal AZ counts.

**14. You want the LB itself to be redundant. Do you build that?**
→ **No** — AWS runs redundant LB nodes per AZ automatically. You only enable ≥2 subnets. 🎯 The LB's own HA is managed.

**15. RDS is single-AZ behind your HA web tier.** Problem?
→ The DB is now the SPOF. Use **RDS Multi-AZ.** HA is only as strong as the weakest tier. 🎯 Make every tier multi-AZ.

**16. Sessions are stored in instance memory; when an instance dies users get logged out.**
→ Externalize sessions to **ElastiCache/Redis or DynamoDB** so any instance serves any user. 🎯 Stateless instances = real HA.

---

## C. Health checks (17–26)

**17. All targets show `unhealthy` immediately after setup; app works on direct curl.**
→ Likely the **app SG doesn't allow the ALB SG** on the health-check port, or wrong path/port. Check SG + `describe-target-health` reason. 🎯 SG must allow LB→target on the HC port.

**18. Health check reason is `Target.ResponseCodeMismatch`.**
→ The path returns a code outside the success matcher (often a **301 redirect** or 403). Fix the path or widen `--matcher`. 🎯 Match the codes your HC path actually returns.

**19. `Target.Timeout` on health checks.**
→ Target too slow to respond within the timeout, app not listening on the HC port, or SG/NACL blocking. Increase timeout *only* after ruling out connectivity. 🎯 Timeout = network or slow app.

**20. Healthy instances keep flapping healthy↔unhealthy.**
→ HC too aggressive (interval/timeout too low) for GC pauses/cold paths, or `/healthz` does heavy work. Loosen thresholds and make the endpoint lightweight. 🎯 Tune HC to the app's real behavior.

**21. Your `/healthz` queries every downstream service. One dependency slows → the WHOLE fleet goes unhealthy → outage.**
→ **Shallow health checks.** Check only what *this instance* needs to serve. Don't cascade a dependency outage into a full eviction. 🎯 Keep health checks shallow.

**22. New instances get killed by the ASG seconds after launch, in a loop.**
→ **Health-check grace period** too short — they're evaluated before boot finishes. Raise it to real startup time. 🎯 Grace period ≥ boot+warmup.

**23. You want the ASG to replace instances the LB considers unhealthy, not just hardware failures.**
→ Set ASG **`--health-check-type ELB`** (default is `EC2`). 🎯 ELB health type ties ASG replacement to LB health.

**24. Deploy pushes bad code; all instances pass EC2 checks but return 500. Site is down.**
→ A health check that hits a real route (returning 500) + `health-check-type ELB` would have evicted them; pair with blue/green so the bad version never takes 100%. 🎯 Health checks should reflect app correctness.

**25. You want a near-instant detection of a dead instance.**
→ Lower interval (e.g. 10s) + unhealthy threshold 2 = ~20s detection. Balance against false positives. 🎯 Detection time ≈ interval × unhealthy-threshold.

**26. Health check passes but real users get errors.**
→ The HC path is too trivial (static file) and doesn't exercise the failing code path. Make it represent real serving capability. 🎯 A healthy check should mean "can serve real traffic."

---

## D. SSL/TLS (27–34)

**27. Where should TLS terminate for a standard web app?**
→ At the **ALB** (TLS termination), backends speak HTTP in private subnets. Simplest + ACM manages renewals. 🎯 Terminate at the LB.

**28. Compliance requires encryption even inside the VPC.**
→ **End-to-end / re-encryption:** ALB terminates client TLS, then re-encrypts to HTTPS backends. 🎯 Re-encrypt for in-VPC encryption requirements.

**29. You must NOT let the LB see plaintext at all.**
→ **NLB TLS passthrough** (TCP) — backend holds the cert and terminates. 🎯 Passthrough keeps the LB blind to plaintext.

**30. Cert renewal keeps causing outages every year.**
→ Use **ACM** — free, **auto-renewing** certs on ALB/NLB. No more manual renewals. 🎯 ACM kills renewal toil.

**31. You host `app.com`, `admin.com`, `api.com` on one ALB and need a cert each.**
→ One HTTPS listener + **SNI** (multiple certificates). ALB serves the right cert by hostname. 🎯 SNI = many certs, one listener.

**32. Security scan flags TLS 1.0 enabled on your ALB.**
→ Switch to a modern **SSL security policy** (`ELBSecurityPolicy-TLS13-1-2-2021-06`) that disables TLS 1.0/1.1. 🎯 Pick a strong SSL policy.

**33. You attached the ACM cert but the ALB says it can't find it.**
→ The cert must be in the **same region** as the ALB (only CloudFront uses `us-east-1`). Request/import it in the LB's region. 🎯 Cert region must match the LB.

**34. Users on HTTP get no encryption; you want to force HTTPS.**
→ HTTP:80 listener with a **301 redirect to HTTPS:443**. 🎯 Redirect HTTP→HTTPS at the listener.

---

## E. Sticky sessions & state (35–40)

**35. A legacy app stores cart state in server memory; users' carts vanish randomly.**
→ Enable **ALB cookie stickiness** as a stopgap, but the real fix is **externalizing sessions** (Redis). 🎯 Stickiness is a crutch; externalize state.

**36. After enabling stickiness, one instance is hot and others idle.**
→ Expected — stickiness causes uneven load. Reduce cookie duration or remove stickiness by going stateless. 🎯 Stickiness ⇒ uneven load.

**37. Scale-in removes a sticky target; those users lose their session.**
→ Inherent to stickiness. Stateless + shared session store avoids it entirely. 🎯 Stickiness breaks graceful scaling.

**38. You need stickiness tied to your own login cookie's lifecycle, not a fixed timer.**
→ **Application-based stickiness** (ALB uses your app cookie). 🎯 App-based stickiness follows your cookie.

**39. NLB (L4) — can you do cookie stickiness?**
→ No cookies at L4. NLB offers **source-IP (flow) stickiness**. 🎯 NLB stickiness = source IP.

**40. WebSocket connections must stay on one backend.**
→ A WebSocket holds a single long-lived connection to one target naturally; ensure **deregistration delay** is long enough to drain it on scale-in. Stickiness helps for reconnects. 🎯 Tune draining for long-lived connections.

---

## F. Scaling, deploys & draining (41–46)

**41. Deploys cut off in-flight requests when old instances are removed.**
→ Increase **deregistration delay** (connection draining) to your longest request. 🎯 Drain before removing targets.

**42. Choose a scaling signal for a request-driven web app.**
→ Target-track on **`ALBRequestCountPerTarget`** — scales on actual traffic, better than CPU for I/O-bound apps. 🎯 Scale on requests-per-target for web.

**43. Newly scaled-in instances get full traffic instantly and error while caches are cold.**
→ Enable **slow start** on the target group to ramp traffic gradually. 🎯 Slow start warms new targets.

**44. You want zero-downtime, instantly-reversible releases.**
→ **Blue/Green** via two target groups + weighted forward (or CodeDeploy). Flip 100% blue→green; roll back by flipping back. 🎯 Blue/green = instant rollback.

**45. You want to test a new version on 5% of users first.**
→ **Canary** with weighted target groups (95/5), watch metrics, then ramp. 🎯 Canary = weighted target groups.

**46. ASG scales out but new instances never get traffic.**
→ The ASG isn't attached to the **target group** (or no scaling policy / wrong subnets). Attach `--target-group-arns`. 🎯 ASG must reference the target group.

---

## G. Security & networking (47–50)

**47. App instances have public IPs and `0.0.0.0/0:80` open "so the ALB can reach them."**
→ Wrong + insecure. Put instances in **private subnets**, no public IP, and allow port 80 **only from the ALB's SG**. 🎯 SG-references-SG; private subnets.

**48. You need L7 WAF protection (SQLi/XSS/rate limiting).**
→ Attach **AWS WAF** to the **ALB** (WAF doesn't attach to NLB). 🎯 WAF = ALB (or CloudFront).

**49. Behind an NLB, target traffic is mysteriously blocked even though the LB SG allows it.**
→ NLB **preserves the client source IP**, so the **target SG must allow the client CIDRs**, not the LB SG. 🎯 NLB source-IP changes the SG math.

**50. You want service-to-service traffic load-balanced but never exposed to the internet.**
→ Use an **internal** load balancer (`--scheme internal`) — private IPs only. 🎯 Internal LB for private tiers.

---

## ✅ How to use this module
- First pass: cover the solution, answer aloud, score yourself.
- Re-test the ones you missed after a day.
- For interviews, practice saying the 🎯 line — it's the reusable principle behind the specific answer.

➡️ When something breaks for real, go to [05-troubleshooting.md](05-troubleshooting.md).

# Module 8 — 100 ELB & Auto Scaling Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, technically correct.

---

## Load balancer fundamentals & types (1–20)
**1. What is Elastic Load Balancing?** A managed service that distributes incoming traffic across multiple targets (EC2, IPs, Lambda, containers) in multiple AZs, giving you one stable endpoint with health-aware routing.

**2. ALB vs NLB in one line?** ALB = Layer 7 (HTTP/HTTPS) with content-based routing; NLB = Layer 4 (TCP/UDP/TLS) for extreme performance and static IPs.

**3. When do you pick NLB over ALB?** When you need static IPs, non-HTTP protocols (TCP/UDP), source-IP preservation, TLS passthrough, or millions of requests/sec at ultra-low latency.

**4. What is a Gateway Load Balancer?** A Layer 3 LB that transparently inserts third-party virtual appliances (firewalls, IDS/IPS) inline using GENEVE encapsulation and GWLB endpoints.

**5. Is Classic Load Balancer still recommended?** No — it's legacy. Build new on ALB (HTTP) or NLB (TCP/UDP).

**6. Does an ALB give you a static IP?** No — it provides a DNS name whose IPs change. Use an NLB (Elastic IP per AZ) if you need fixed IPs.

**7. How does ALB expose the client IP to backends?** Via the `X-Forwarded-For` header (TLS is terminated at the LB, so the app reads the header).

**8. How does NLB handle the client IP?** It preserves the original source IP natively to the targets.

**9. Why must an ALB span at least two AZs?** For high availability — if one AZ fails, the LB nodes in the other AZ keep serving.

**10. What's an LCU / NLCU?** The usage-based billing unit for ALB/NLB — you pay an hourly charge plus capacity units based on connections, bandwidth, and rule evaluations.

**11. Can an ALB target a Lambda function?** Yes — target type `lambda`; the ALB invokes the function per request, useful for lightweight HTTP backends.

**12. Can an NLB forward to an ALB?** Yes — `target-type: alb`, giving you NLB static IPs in front of ALB L7 routing.

**13. Does NLB have a security group?** Historically no (it was pass-through); modern NLBs do support security groups. ALBs always have one.

**14. What protocols does NLB support?** TCP, UDP, TLS, and TCP_UDP.

**15. What is connection multiplexing on ALB?** The ALB keeps a pool of backend connections and reuses them across client requests for efficiency.

**16. Does ALB support WebSockets and HTTP/2?** Yes, natively; gRPC too (HTTP/2 target group).

**17. What's the difference between internal and internet-facing LBs?** Internet-facing has public IPs in public subnets; internal has private IPs for VPC-internal traffic (e.g., between tiers).

**18. Can a load balancer span multiple Regions?** No — ELB is regional. Use Route 53 latency/failover routing or Global Accelerator for multi-Region.

**19. What is AWS Global Accelerator vs NLB?** Global Accelerator provides 2 static anycast IPs at the edge and routes to the optimal Region's endpoints; NLB is a single-Region LB.

**20. Why one DNS name instead of instance IPs?** It decouples clients from changing/scaling backends and enables health-based routing and HA.

## Listeners, rules & routing (21–38)
**21. What is a listener?** A process that checks for connections on a configured port and protocol (e.g., HTTPS:443) and forwards according to rules.

**22. What can ALB rules match on?** Path, host header, HTTP method, query string, source IP, and HTTP headers.

**23. How do you redirect HTTP to HTTPS?** Add a listener on :80 with a redirect action to :443 (HTTPS).

**24. How are rule priorities evaluated?** In ascending priority order; the first match wins, and the default action applies if nothing matches.

**25. What is host-based routing?** Routing by the `Host` header so `app.example.com` and `api.example.com` hit different target groups on one ALB.

**26. What is path-based routing?** Routing by URL path, e.g., `/api/*` → API target group, `/admin/*` → admin target group.

**27. What is a fixed-response action?** The ALB returns a static status code/body directly (e.g., a maintenance page) without hitting a target.

**28. How do weighted target groups help deployments?** They split traffic by percentage across versions — the basis for blue/green and canary on a single ALB.

**29. How does NLB decide where to send a packet?** By a flow hash (protocol, source/dest IP, source/dest port) — it routes by port, not content.

**30. Can you authenticate users at the ALB?** Yes — built-in OIDC/Cognito authentication actions on the listener before forwarding.

**31. What is mTLS on ALB?** Mutual TLS, where the ALB validates the client's certificate, used for strong machine-to-machine auth.

**32. Can one ALB host many apps?** Yes — many listeners/rules and target groups, separated by host/path; a common cost-saving pattern.

**33. What's the max number of rules per ALB listener?** It's a soft quota (default 100), adjustable via Service Quotas.

**34. How do you do A/B testing with ALB?** Weighted target groups or header/query-based rules to route a slice of users to a variant.

**35. What does the default action do?** Handles any request not matched by a more specific rule.

**36. Can ALB route gRPC?** Yes, with an HTTP/2 (gRPC) target group and protocol version gRPC.

**37. How would you serve a maintenance page during a deploy?** Temporarily point the default action to a fixed-response or a maintenance target group.

**38. What's a common reason a rule never matches?** Its priority is higher (numerically) than a broader rule that matches first, or the condition is wrong (host vs path).

## Target groups, targets & health checks (39–58)
**39. What is a target group?** A logical pool of backends plus the health-check configuration that guards them; listeners forward to target groups.

**40. Where does the health check live?** On the target group, not the listener.

**41. Target types for an ALB?** `instance`, `ip`, and `lambda`.

**42. When must you use target type `ip`?** For on-prem/peered targets, or container setups (e.g., some Fargate/awsvpc cases).

**43. What is a health check?** A periodic probe (HTTP/HTTPS/TCP) to a target; only healthy targets receive traffic.

**44. Healthy vs unhealthy threshold?** Consecutive successes needed to mark healthy vs consecutive failures to mark unhealthy.

**45. What's the matcher?** The acceptable HTTP status range (e.g., 200-299) that counts as a passing health check.

**46. Good practice for a health-check endpoint?** A lightweight `/healthz` that checks the app is up without hammering the database on every probe.

**47. What does deregistration delay (connection draining) do?** Lets in-flight requests finish before a target is removed (default ~300s).

**48. What is slow start?** Gradually ramps traffic to newly healthy targets so they aren't overwhelmed at once.

**49. Who replaces an unhealthy instance?** The Auto Scaling Group — but only if its health-check type is set to ELB.

**50. ALB returns 502 — meaning?** Bad gateway: the target returned an invalid/empty response or crashed.

**51. ALB returns 503 — meaning?** Service unavailable: no healthy targets registered in the target group.

**52. ALB returns 504 — meaning?** Gateway timeout: the target didn't respond within the idle/response timeout.

**53. Can a target be in multiple target groups?** Yes.

**54. How does cross-zone load balancing affect distribution?** On = even across all targets in all AZs; off = even per-AZ first, then within that AZ.

**55. Cross-zone defaults?** On (free) for ALB; off for NLB (and may incur inter-AZ data charges when enabled).

**56. Why might all targets be unhealthy at launch?** Security group blocks the health-check port, wrong path/port, or the app isn't listening yet.

**57. How do you reduce false unhealthy marks during deploys?** Tune interval/threshold, use slow start, and set a sensible health-check grace period on the ASG.

**58. What is the idle timeout?** How long the ALB keeps an idle connection open (default 60s); raise it for long-polling/streaming.

## TLS/SSL, ACM & certificates (59–70)
**59. What is TLS termination?** The LB decrypts HTTPS and forwards plain HTTP to backends, offloading crypto from your servers.

**60. What is end-to-end (re-)encryption?** The LB terminates TLS then opens a new TLS connection to the target (target group protocol HTTPS).

**61. What is ACM?** AWS Certificate Manager — free, auto-renewing public TLS certificates for ALB/NLB/CloudFront/API Gateway.

**62. Can you put an ACM public cert on a raw EC2?** No — ACM public certs can't be exported; use Let's Encrypt/Certbot on the instance instead.

**63. What is SNI?** Server Name Indication — lets one HTTPS listener serve multiple domains/certs by reading the requested hostname during the handshake.

**64. How is an ACM cert validated?** Via DNS (recommended, enables auto-renewal) or email.

**65. Why did my ACM cert fail to auto-renew?** Usually the DNS validation CNAME was removed, so ACM can't re-validate domain ownership.

**66. What is a security policy on a listener?** The set of allowed TLS protocol versions and cipher suites.

**67. Can NLB do TLS passthrough?** Yes — a TCP listener forwards encrypted traffic untouched so the target terminates TLS.

**68. Where do you attach the certificate?** To the HTTPS/TLS listener.

**69. How do you support old + new domains on one LB?** Add multiple certificates to the listener; SNI selects the right one.

**70. Free cert + auto-renew + ALB = which service?** ACM.

## Stickiness, draining & cross-zone (71–78)
**71. What are sticky sessions?** Pinning a client to the same target, via an ALB cookie (`AWSALB`/app cookie) or NLB source-IP flow hash.

**72. Downside of stickiness?** Uneven load and a worse failure blast radius; prefer stateless apps with shared session stores (ElastiCache).

**73. Application-controlled stickiness?** The app issues a cookie the ALB honors, giving the app control over session lifetime.

**74. How long can ALB stickiness last?** Configurable duration per target group (seconds up to 7 days).

**75. Why prefer stateless servers?** They scale and self-heal cleanly — any instance can serve any request; store sessions in Redis/DynamoDB.

**76. What does connection draining prevent?** Dropping active requests when a target is deregistered or replaced.

**77. NLB stickiness basis?** Source IP / 5-tuple flow, not cookies.

**78. When is cross-zone worth the inter-AZ cost on NLB?** When uneven per-AZ target counts would otherwise cause imbalance; weigh balance vs data-transfer cost.

## EC2 Auto Scaling (79–94)
**79. What is an Auto Scaling Group?** A controller that maintains a desired number of healthy EC2 instances across AZs, replacing failures and scaling on demand.

**80. Launch Template vs Launch Configuration?** Templates are versioned and support mixed instances/Spot — always prefer them; configurations are legacy.

**81. Explain min/desired/max.** Min = floor, max = ceiling, desired = the current target the ASG maintains; policies move desired between min and max.

**82. What is target-tracking scaling?** You set a metric target (e.g., CPU 50%) and the ASG adds/removes instances to hold it — the simplest, recommended policy.

**83. Step vs simple scaling?** Step adjusts by amounts tied to alarm magnitude with no blocking cooldown; simple does one change then waits (legacy).

**84. What is scheduled scaling?** Capacity changes at known times (e.g., scale to 10 every weekday 9am).

**85. What is predictive scaling?** ML forecasts cyclical demand and pre-provisions capacity ahead of it.

**86. How does an ASG self-heal?** With ELB health-check type, it terminates targets failing the LB health check and launches replacements.

**87. What's the health-check grace period?** Time after launch before health checks count, so instances can boot/start the app without being killed.

**88. How do you roll out a new AMI with no downtime?** Instance Refresh with a min-healthy-percentage and instance warm-up (rolling replacement).

**89. What are lifecycle hooks?** Pauses at launch/terminate so you can run setup (warm caches, register) or cleanup (drain, flush logs) before serving/terminating.

**90. What are warm pools?** Pre-initialized stopped instances kept ready for near-instant scale-out of slow-booting apps.

**91. What is a mixed-instances policy?** Blending On-Demand and Spot across multiple instance types/AZs for cost savings on fault-tolerant tiers.

**92. How do you avoid scaling thrash?** Cooldowns / instance warm-up and target-tracking, so new capacity is counted before further actions.

**93. Good metric to scale a worker tier?** A custom metric like SQS `ApproximateNumberOfMessages` (queue depth), not just CPU.

**94. What is scale-in protection?** Prevents a specific instance from being chosen for termination during scale-in.

## Architecture, HA, cost & troubleshooting (95–100)
**95. Describe a self-healing, HA web tier.** ALB across ≥2 AZs → target group with `/healthz` → ASG (min 2, multi-AZ, target-tracking, ELB health checks) → RDS Multi-AZ.

**96. How does Route 53 connect users to an ALB?** An ALIAS A/AAAA record at the apex pointing to the ALB (no cost, supports zone apex unlike CNAME).

**97. How do you cut ELB cost in labs?** Delete the load balancer when done — the hourly charge accrues 24/7 regardless of traffic.

**98. Users see intermittent errors; metrics show one bad target. Diagnose.** Health checks are off or too lax; enable ELB health checks and tighten thresholds so the bad target is removed/replaced.

**99. ASG launches then terminates instances in a loop. Cause?** Health-check grace period too short or the app fails its health check on boot.

**100. How would you achieve zero-downtime blue/green on AWS?** Two target groups behind the ALB (or CodeDeploy), shift traffic via weighted/listener swap, validate, then cut over or roll back instantly.

---
*Back to [ELB & Auto Scaling README](README.md). Practice more: [07 — MCQs](07-100-mcqs.md) · [04 — Scenarios](04-scenarios.md).*

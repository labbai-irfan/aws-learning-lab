# Module 5 — 100 Route 53 Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, technically correct.

---

## DNS Basics (1–18)
**1. What is DNS?** The Domain Name System — the internet's directory that translates human-readable names (example.com) into IP addresses.

**2. What is Route 53?** AWS's highly available, scalable DNS web service, domain registrar, and health-checking service — with a 100% availability SLA.

**3. Why is it called "53"?** DNS runs on port 53.

**4. Walk through a DNS lookup.** Browser asks a resolver → resolver queries a root server → the .com TLD servers → the domain's authoritative name servers (Route 53) → gets the IP → caches it per TTL → returns to the browser.

**5. What is an authoritative name server?** The server that holds the real, definitive records for a zone — for Route 53 domains, that's the hosted zone's name servers.

**6. What is a recursive resolver?** The server (ISP/8.8.8.8) that performs lookups on the client's behalf and caches results.

**7. What is TTL?** Time To Live — how long a record may be cached by resolvers before they re-query.

**8. Why lower TTL before a change?** So caches expire quickly and your change takes effect fast (a fast cutover); raise it afterward for efficiency.

**9. What is the zone apex?** The bare/root domain (example.com) with no subdomain prefix.

**10. What is an FQDN?** Fully Qualified Domain Name — the complete name including the trailing dot (www.example.com.).

**11. What is a TLD?** Top-Level Domain — the last label like .com, .org, .io, .in.

**12. What's the difference between a domain and a subdomain?** A domain is example.com; subdomains are prefixes like app.example.com.

**13. Is Route 53 authoritative or recursive?** Authoritative — it holds the answers for hosted domains (it's not a public recursive resolver, though Route 53 Resolver handles VPC DNS).

**14. How fast do Route 53 changes apply?** Route 53 propagates to its name servers within seconds; the delay users see is downstream resolver caching (TTL).

**15. What record types does Route 53 support?** A, AAAA, CNAME, Alias, MX, TXT, NS, SOA, SRV, PTR, CAA, NAPTR, DS, and more.

**16. What is reverse DNS?** Resolving an IP back to a name via PTR records (often managed by the IP owner).

**17. What does the dig command do?** Performs DNS lookups; `dig +trace` walks the full delegation chain; `dig @8.8.8.8` queries a specific resolver.

**18. Why test against 8.8.8.8?** To bypass local caches and see what a fresh public resolver returns.

---

## Domain Registration & Hosted Zones (19–34)
**19. Can Route 53 register domains?** Yes — it's a registrar and a DNS host; you can do both or just host DNS.

**20. Difference between a registrar and a DNS host?** The registrar is who you bought the name from; the DNS host runs the name servers that answer queries. They can be different providers.

**21. What is a hosted zone?** The container of all DNS records for a domain (and subdomains).

**22. Public vs private hosted zone?** Public resolves from the internet; private resolves only inside associated VPCs (internal names).

**23. What records are auto-created in a zone?** NS (the 4 authoritative name servers) and SOA (zone metadata).

**24. What is an SOA record?** Start of Authority — holds the primary NS, admin contact, serial, and timing/TTL parameters for the zone.

**25. What happens when you register a domain in Route 53?** It auto-creates a hosted zone and sets the domain's NS to that zone's name servers.

**26. How do you move an existing domain's DNS to Route 53?** Create a hosted zone, then update the registrar's NS records to Route 53's four NS.

**27. Why must registrar NS match the hosted zone NS?** Because the registrar tells the world which servers are authoritative; a mismatch breaks resolution.

**28. What happens if you delete and recreate a hosted zone?** It gets new NS records, so you must update the registrar again.

**29. How much does a hosted zone cost?** Roughly $0.50/month plus per-query charges.

**30. Can one domain have multiple hosted zones?** You should use one authoritative zone; duplicates cause confusion. Subdomains can be delegated to their own zones.

**31. What is domain delegation?** Pointing a (sub)domain's NS to another set of name servers responsible for it.

**32. How do you protect a domain from accidental loss?** Enable auto-renew, keep contact info current, and use registrar lock + privacy protection.

**33. What is WHOIS privacy?** Masking your personal contact details in the public WHOIS database.

**34. Can private hosted zones overlap with public ones?** Yes — split-horizon DNS: the same name resolves differently inside the VPC vs the internet.

---

## A, CNAME, Alias (35–54)
**35. What is an A record?** Maps a name to an IPv4 address.

**36. What is an AAAA record?** Maps a name to an IPv6 address.

**37. What is a CNAME?** Maps a name to another name (canonical name), triggering a further lookup.

**38. Why can't a CNAME be at the zone apex?** DNS rules forbid a CNAME coexisting with the apex's required NS/SOA records.

**39. What is an Alias record?** A Route 53 extension that behaves like A/AAAA but points to AWS resources by hostname, resolving directly to their IPs.

**40. Alias vs CNAME — key differences?** Alias works at the apex, is free for AWS targets, auto-updates with the target's IPs, and is AWS-specific; CNAME is standard DNS, can't be at apex, and is billed like a normal query.

**41. What can an Alias target?** CloudFront, ALB/NLB/Classic ELB, S3 static website, API Gateway, VPC endpoints, Elastic Beanstalk, Global Accelerator, and other Route 53 records in the same zone.

**42. When must you use an Alias?** When pointing the apex domain at an AWS resource (CloudFront/ALB/S3), since CNAME is illegal there.

**43. When is a CNAME appropriate?** For subdomains pointing to external/non-AWS hostnames (e.g., a SaaS or vendor host).

**44. Is Alias cheaper than CNAME?** Yes — Alias queries to AWS resources are free.

**45. Can A records hold multiple IPs?** Yes; Route 53 returns them (basic round-robin), but a load balancer/policy gives real control.

**46. How do you point apex + www to CloudFront?** Alias both example.com and www.example.com to the distribution (or alias www to the apex).

**47. What is EvaluateTargetHealth on an Alias?** It makes the Alias consider the target's health (e.g., ALB) so DNS can fail over.

**48. Why is Alias better for ALB than a hard-coded IP?** ALB IPs change; Alias tracks them automatically, while a static A record would break.

**49. Can you Alias to a resource in another account?** Generally the target must be referenceable; cross-account often uses the resource's DNS name via CNAME or shared setups — Alias is intended for resources you can select.

**50. What's the lookup cost of a CNAME chain?** Each hop is an extra resolution; deep chains add latency.

**51. Can a name have both a CNAME and an MX?** No — a CNAME can't coexist with other record types at the same name.

**52. How do you map an apex to an S3 static site?** Alias the apex to the S3 website endpoint (or, better, to a CloudFront distribution for HTTPS).

**53. Does Alias support AAAA?** Yes — you create Alias A (IPv4) and Alias AAAA (IPv6) to the same target.

**54. What's a common Alias mistake?** Trying to CNAME the apex, or forgetting EvaluateTargetHealth for failover.

---

## MX & TXT (55–66)
**55. What is an MX record?** It directs email for a domain to mail servers, each with a priority.

**56. How does MX priority work?** Lower number = higher priority; mail tries the lowest first, then higher numbers as backups.

**57. Where are MX records usually set?** At the zone apex so user@example.com routes correctly.

**58. Do MX records point to IPs?** No — to hostnames (which then resolve via A records).

**59. What is a TXT record?** A free-text record used for verification and email-security policies.

**60. What is SPF?** A TXT policy listing which servers may send mail for your domain (anti-spoofing).

**61. What is DKIM?** A signature mechanism proving email authenticity, published via DNS (often a CNAME/TXT on a selector subdomain).

**62. What is DMARC?** A TXT policy (on _dmarc) telling receivers how to handle mail failing SPF/DKIM and where to send reports.

**63. How do you verify domain ownership for a service?** Add the provided TXT (or CNAME) record to your zone; the service checks it.

**64. Can a name have multiple TXT records?** Yes; each string is limited to 255 chars (longer values are chunked).

**65. Common email deliverability setup?** MX + SPF (TXT) + DKIM + DMARC, all in the hosted zone.

**66. Why might email go to spam despite correct MX?** Missing SPF/DKIM/DMARC, poor sender reputation, or misconfigured records.

---

## Routing Policies (67–82)
**67. Name the Route 53 routing policies.** Simple, Weighted, Latency-based, Failover, Geolocation, Geoproximity, and Multivalue answer.

**68. What is simple routing?** One record returning its value(s) with no special logic.

**69. What is weighted routing?** Splits traffic across records by assigned weights — great for canary/A-B and gradual rollouts.

**70. What is latency-based routing?** Returns the Region that gives the user the lowest network latency — best for multi-Region performance.

**71. What is failover routing?** Active-passive: routes to a primary while healthy, else to a secondary.

**72. What is geolocation routing?** Routes based on the user's geographic location (continent/country/state) — for localization, compliance, or geo-blocking.

**73. What is geoproximity routing?** Routes based on geographic distance with an adjustable bias to shift traffic between locations (via Traffic Flow).

**74. What is multivalue answer routing?** Returns up to 8 healthy records so clients can pick — simple health-aware distribution (not a real load balancer).

**75. Latency vs geolocation — difference?** Latency is based on measured network performance; geolocation is based on where the user is, regardless of latency.

**76. How do you do a canary release with DNS?** Weighted routing — send a small percentage (e.g., 10%) to the new version.

**77. Why do policy records need a SetIdentifier?** To uniquely distinguish multiple records sharing the same name/type.

**78. Can you combine policies?** Yes — Traffic Flow lets you nest policies (e.g., geolocation → then latency → then weighted).

**79. Which policy for active-active multi-Region?** Latency-based or weighted with health checks (all Regions serve).

**80. Which policy for active-passive DR?** Failover.

**81. How do you geo-block a country?** Geolocation routing returning a block page (or no answer) for that location, with a default for others.

**82. What's a default record in geolocation?** A catch-all ("*") for users whose location doesn't match a specific rule.

---

## Health Checks & Failover (83–92)
**83. What is a Route 53 health check?** A monitor that probes an endpoint (or aggregates checks/alarms) to determine health and drive routing decisions.

**84. What types of health checks exist?** Endpoint (HTTP/HTTPS/TCP), calculated (combine other checks), and CloudWatch-alarm-based.

**85. How does an endpoint health check work?** Global checkers probe a host/port/path at intervals; after a failure threshold of consecutive failures, it's marked unhealthy.

**86. How do you health-check a private resource?** Use a CloudWatch-alarm health check, since Route 53's public checkers can't reach private IPs.

**87. How do health checks enable failover?** The primary record's health check failing causes Route 53 to return the secondary record.

**88. How do you speed up client failover?** Lower the record TTL so clients re-resolve sooner.

**89. What's a good health check endpoint?** A lightweight /health path that verifies key dependencies (and returns 200 when truly healthy).

**90. Can health checks send alerts?** Yes — via CloudWatch/SNS when an endpoint becomes unhealthy.

**91. What is a calculated health check?** One whose status is derived from multiple child checks (e.g., healthy if at least 2 of 3 pass).

**92. Failover routing vs latency routing for resilience?** Failover = active-passive (one serves at a time); latency = active-active across Regions by performance.

---

## SSL, Architecture & Operations (93–100)
**93. How do you add HTTPS to a Route 53 domain?** Use a free ACM certificate validated via DNS, attached to CloudFront/ALB/API Gateway.

**94. Where must an ACM cert live for CloudFront?** In us-east-1 (N. Virginia), regardless of where your other resources are.

**95. Where must an ACM cert live for an ALB?** In the same Region as the ALB.

**96. How does ACM DNS validation work?** ACM provides CNAME records; you add them to the hosted zone; ACM verifies control and auto-renews while they remain.

**97. How do you put a React app on a custom domain with HTTPS?** Host the build on S3 behind CloudFront (OAC, private bucket), ACM cert in us-east-1, then Alias the apex/www to CloudFront.

**98. How do you put a Node API on api.example.com with HTTPS?** Deploy behind an ALB with an HTTPS listener using an ACM cert in the ALB's Region, then Alias api.example.com to the ALB with EvaluateTargetHealth.

**99. How do you achieve DNS-level disaster recovery?** Failover routing with health checks to a standby Region (or a static S3 fallback), with low TTLs.

**100. Walk through end-to-end resolution + delivery for https://app.example.com.** Resolver finds Route 53 as authoritative (via registrar NS) → Route 53 returns the Alias target (CloudFront) per the routing policy/health → browser connects to CloudFront → TLS handshake with the ACM cert → CloudFront serves cached content from S3 (OAC) → for /api, api.example.com aliases to the ALB → ALB terminates TLS and routes to a healthy EC2 target → response returns to the user.

➡️ Next: [06-50-scenario-questions.md](06-50-scenario-questions.md)

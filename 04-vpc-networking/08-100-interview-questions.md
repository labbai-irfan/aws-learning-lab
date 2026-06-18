# Module 5 — 100 VPC Interview Questions (with answers)

Grouped by topic, roughly easy → hard. Each has a concise model answer. Cover the **bold** keyword and you'll satisfy most interviewers.

**Sections:** [VPC & CIDR](#vpc--cidr-q1-15) · [Subnets](#subnets-q16-27) · [Route Tables](#route-tables-q28-35) · [IGW & NAT](#internet-gateway--nat-q36-50) · [NACL vs SG](#nacl--security-groups-q51-66) · [Peering & TGW](#vpc-peering--transit-gateway-q67-80) · [Endpoints](#vpc-endpoints-q81-88) · [Architecture & Scenarios](#architecture--scenarios-q89-100)

---

## VPC & CIDR (Q1–15)

**Q1. What is a VPC?**
A logically **isolated virtual network** inside an AWS Region where you launch resources with full control over IP ranges, subnets, routing, and gateways. It spans all AZs in one Region and is private by default.

**Q2. Is a VPC regional or global?**
**Regional.** It automatically spans all Availability Zones in its Region but cannot cross Region boundaries. Subnets, by contrast, are AZ-scoped.

**Q3. What is the default VPC?**
An AWS-created VPC (`172.31.0.0/16`) per Region with one public subnet per AZ, an IGW, and routes pre-wired so instances get public IPs out of the box. Convenient, but not recommended for production.

**Q4. What is CIDR notation?**
**Classless Inter-Domain Routing** — `IP/prefix` (e.g. `10.0.0.0/16`). The prefix says how many leading bits are the fixed network portion; the rest are host addresses.

**Q5. How many IPs in a /16, /24, /28?**
`/16` = 65,536; `/24` = 256; `/28` = 16. Each +1 to the prefix halves the range.

**Q6. How many usable IPs in a /24 subnet in AWS?**
**251.** AWS reserves **5** per subnet: network, VPC router, DNS, future use, and broadcast.

**Q7. Which IP ranges should a VPC use?**
**RFC 1918 private ranges:** `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`. Avoid ranges that overlap anything you may peer with later.

**Q8. Min and max VPC CIDR size?**
Between **/16 (largest)** and **/28 (smallest)**.

**Q9. Can you change a VPC's CIDR after creation?**
You can't shrink/replace the primary, but you can **add secondary CIDR blocks** to expand.

**Q10. Why must CIDRs not overlap across VPCs?**
Overlapping ranges make **routing ambiguous**, so **peering and Transit Gateway connections fail**. Plan a non-overlapping IP scheme up front (e.g. with AWS IPAM).

**Q11. How many VPCs can you have per Region?**
**5 by default** (soft limit, increasable via a service quota request).

**Q12. What's the difference between IPv4 and IPv6 in a VPC?**
IPv4 is required and private by default (uses NAT for egress). IPv6 addresses are **globally unique and public**, so there's no NAT — you use an **egress-only internet gateway** for outbound-only IPv6.

**Q13. What is an egress-only internet gateway?**
The IPv6 equivalent of a NAT Gateway: allows **outbound-only** IPv6 traffic from private instances while blocking inbound. (NAT is for IPv4 only.)

**Q14. What are the components you can put in a VPC?**
Subnets, route tables, internet/NAT/transit gateways, NACLs, security groups, ENIs, VPC endpoints, peering connections, and resources like EC2/RDS/ELB.

**Q15. What does `enableDnsHostnames` do?**
Lets instances with public IPs receive **public DNS names** and enables DNS resolution of those names. Required for things like public RDS endpoints to resolve correctly.

---

## Subnets (Q16–27)

**Q16. What is a subnet?**
A subdivision of a VPC's CIDR that lives in **exactly one Availability Zone** and where you actually place resources.

**Q17. Can a subnet span multiple AZs?**
**No.** One subnet = one AZ. For multi-AZ HA you create one subnet per AZ.

**Q18. What makes a subnet "public"?**
Its associated **route table has `0.0.0.0/0 → Internet Gateway`** (and resources have public IPs). Nothing on the subnet object itself marks it public.

**Q19. What makes a subnet "private"?**
**No route to an IGW.** It may reach out via a NAT Gateway, or have only the `local` route (fully isolated).

**Q20. Why split a /16 VPC into multiple subnets?**
For **AZ-level HA**, **tier isolation** (web/app/data), and to apply **different routing/NACLs** per tier.

**Q21. How do you achieve high availability with subnets?**
Deploy resources across **subnets in 2+ AZs**, mirror the public/private layout per AZ, and use multi-AZ services (ALB, ASG, Multi-AZ RDS).

**Q22. What is a subnet's route table by default?**
The VPC's **main route table**, unless you explicitly associate a custom one.

**Q23. How many IPs does AWS reserve and which ones?**
5: `.0` network, `.1` VPC router, `.2` DNS, `.3` reserved/future, and the last `.255` broadcast (broadcast isn't used but is reserved).

**Q24. Smallest subnet you can create?**
**/28** (16 IPs, 11 usable).

**Q25. Where should databases go?**
In a **private/isolated subnet** with no internet route, reachable only from the app tier via security groups.

**Q26. Can you move a subnet to another AZ?**
**No** — recreate it in the new AZ. Subnet AZ is fixed at creation.

**Q27. What is subnet auto-assign public IP?**
A subnet attribute (`mapPublicIpOnLaunch`) that automatically gives instances launched there a public IP — typically enabled only on public subnets.

---

## Route Tables (Q28–35)

**Q28. What is a route table?**
A set of rules (`destination → target`) that determine the **next hop** for traffic leaving a subnet.

**Q29. What is the `local` route?**
The automatically-created, **non-deletable** route for the VPC's CIDR that lets all subnets in the VPC communicate. It always exists.

**Q30. How does AWS choose between multiple matching routes?**
**Longest-prefix match** — the most specific (longest prefix) route wins. `local` always wins for in-VPC traffic.

**Q31. Main route table vs custom route table?**
The **main** is the default for unassociated subnets; **custom** route tables are explicitly associated to specific subnets for tailored routing.

**Q32. Can one subnet have two route tables?**
**No** — a subnet associates with exactly one route table. One route table can serve many subnets.

**Q33. How do you make a subnet public via routing?**
Add `0.0.0.0/0 → igw-xxxx` to its route table.

**Q34. What is a blackhole route?**
A route whose target is invalid/deleted (e.g. a detached NAT/IGW); traffic matching it is **dropped**. Shows as `blackhole` state.

**Q35. What targets can a route point to?**
`local`, internet gateway, NAT gateway, egress-only IGW, peering connection, transit gateway, VPC endpoint (prefix list), virtual private gateway, or a network interface.

---

## Internet Gateway & NAT (Q36–50)

**Q36. What is an Internet Gateway?**
A horizontally-scaled, redundant, AWS-managed **two-way door** between a VPC and the internet; also performs NAT for instances that have public IPs.

**Q37. How many IGWs per VPC?**
**One**, attached to the VPC. It's free; you pay for data transfer.

**Q38. What three things make an instance internet-reachable?**
(1) IGW attached to the VPC, (2) route `0.0.0.0/0 → IGW`, (3) the instance has a **public or Elastic IP**.

**Q39. What is a NAT Gateway?**
A managed service in a public subnet that lets **private** instances make **outbound** internet connections while blocking inbound — via source NAT using its Elastic IP.

**Q40. NAT Gateway vs NAT Instance?**
NAT Gateway is AWS-managed, auto-scaling, HA-in-AZ, up to 100 Gbps, no SG. NAT Instance is a self-managed EC2 you patch/scale, cheaper but a SPOF you must engineer around. Prefer the gateway.

**Q41. Why can't the internet initiate a connection to a NAT Gateway?**
NAT does **source NAT** and only tracks **outbound-initiated** sessions, allowing matching replies back. There's no port mapping for inbound-initiated connections, so they're dropped.

**Q42. How do you make NAT highly available?**
Deploy **one NAT Gateway per AZ** and route each AZ's private subnet to its **local** NAT. A single NAT is an AZ-level SPOF and incurs cross-AZ data charges.

**Q43. Does a NAT Gateway need an Elastic IP?**
**Yes** (public NAT) — it uses the EIP as the source address for outbound traffic. (A private NAT gateway, for VPC-to-VPC, uses a private IP.)

**Q44. Does a NAT Gateway have a security group?**
**No.** It's controlled by the **NACL** of its subnet, not a security group.

**Q45. Main NAT cost drivers?**
**Per-hour** charge plus **per-GB** data processing. Mitigate with gateway endpoints (S3/DynamoDB) and centralized egress.

**Q46. Can a public subnet instance reach the internet without NAT?**
**Yes** — if it has a public IP and a route to the IGW. NAT is only for **private** subnets.

**Q47. What's an Elastic IP?**
A static, public IPv4 you allocate to your account and can remap between resources. ⚠️ Idle (unattached) EIPs incur charges.

**Q48. A private instance is routed to the IGW (not NAT) — what happens?**
Outbound traffic **blackholes** — without a public IP the IGW can't translate it. Fix: route `0.0.0.0/0` to the **NAT Gateway**.

**Q49. Can a NAT Gateway span AZs?**
**No** — it lives in one AZ/subnet. That's why you deploy one per AZ for resilience.

**Q50. How do private instances get OS updates if they're private?**
Through a **NAT Gateway** (outbound), or via **VPC endpoints** to package mirrors / S3-hosted repos for a fully private path.

---

## NACL & Security Groups (Q51–66)

**Q51. Security Group vs NACL — the core difference?**
SG is **stateful, instance-level, allow-only**. NACL is **stateless, subnet-level, allow + deny, numbered rules**.

**Q52. What does "stateful" mean for a security group?**
If you allow an inbound request, the **response is automatically allowed out** (and vice-versa). You don't write return rules.

**Q53. What does "stateless" mean for a NACL?**
Return traffic is **not** automatic — you must explicitly allow the reply direction, typically **ephemeral ports 1024–65535**.

**Q54. Can a security group have deny rules?**
**No** — SGs are allow-only. To block specific traffic use a **NACL** (which has explicit deny) or simply don't allow it.

**Q55. How are NACL rules evaluated?**
By **rule number, lowest first**; the first match wins, ending with an implicit `* DENY`.

**Q56. How are security group rules evaluated?**
All rules are evaluated together (effectively OR'd); if **any** rule allows the traffic, it's permitted. Order doesn't matter.

**Q57. What is security group referencing/chaining?**
Allowing traffic from **another SG's ID** instead of a CIDR (e.g. DB SG allows the app SG). Rules auto-adjust as instances scale — no hard-coded IPs.

**Q58. Default security group behavior?**
Denies all **inbound**, allows all **outbound**; instances in the same default SG can talk to each other.

**Q59. Default NACL behavior?**
The **default** NACL **allows all** inbound and outbound. A **custom** NACL **denies all** until you add rules.

**Q60. Can security groups span VPCs?**
No — an SG belongs to one VPC. Across peering you reference by **CIDR** (cross-VPC SG referencing only works within the same Region peering with referencing enabled).

**Q61. Where is the #1 NACL mistake?**
Forgetting the **return/ephemeral-port rule** in the opposite direction — the connection succeeds one way and the reply is dropped.

**Q62. How many SGs can an instance have, and rules per SG?**
Up to **5 SGs per ENI** (raisable) and SGs combine additively. Rule counts are subject to quotas.

**Q63. When would you use a NACL over a security group?**
As a **coarse, subnet-wide backstop** — e.g. **deny a known-bad IP/CIDR** for an entire subnet, which SGs can't do (no deny).

**Q64. If an SG allows traffic but a NACL denies it, what happens?**
**Blocked.** Both must allow — they're evaluated together; NACL (subnet) and SG (instance) are independent layers.

**Q65. Do security groups apply to ENIs or instances?**
To **ENIs** (network interfaces). An instance gets the SGs of its attached ENI(s).

**Q66. Does `ping` test SG/NACL the same as a web request?**
No — `ping` is **ICMP**; web is **TCP**. You must allow **ICMP** explicitly. A blocked ping doesn't mean your TCP app is blocked.

---

## VPC Peering & Transit Gateway (Q67–80)

**Q67. What is VPC peering?**
A **private 1:1 connection** between two VPCs so they communicate using private IPs over the AWS backbone (no internet/IGW/NAT).

**Q68. Is VPC peering transitive?**
**No.** If A↔B and B↔C are peered, A still **cannot** reach C. You need a direct A↔C peering (or a Transit Gateway).

**Q69. What must you configure for peering to work?**
Accept the peering, add **routes on both VPCs**, and ensure **SGs/NACLs** allow the peer's CIDR. CIDRs must not overlap.

**Q70. Can peering be cross-Region / cross-account?**
**Yes** to both. Cross-Region peering encrypts traffic over the AWS backbone.

**Q71. Why does peering not scale to many VPCs?**
It forms a **full mesh** — N VPCs need N·(N-1)/2 connections, each with routes to maintain. Use a **Transit Gateway** instead.

**Q72. What is a Transit Gateway?**
A **regional cloud router** connecting many VPCs, VPNs, and Direct Connect in a **hub-and-spoke** topology with transitive routing.

**Q73. Transit Gateway vs VPC peering?**
Peering is 1:1, non-transitive, cheaper, good for a few VPCs. TGW is a managed hub, **transitive**, scales to thousands of attachments, segments traffic via route tables — but costs per-attachment + per-GB.

**Q74. How does a TGW provide isolation between environments?**
Via **TGW route tables / associations** — e.g. associate Dev and Prod with route tables that don't propagate to each other, so Dev can't reach Prod.

**Q75. How do you connect on-premises to a VPC?**
**Site-to-Site VPN** (encrypted over internet) or **Direct Connect** (private dedicated link), often terminated on a **Transit Gateway** or virtual private gateway.

**Q76. Direct Connect vs VPN?**
Direct Connect = private, consistent low latency, high bandwidth, dedicated (no internet). VPN = encrypted over the public internet, cheaper, quick to set up; often used as DX backup.

**Q77. Can a Transit Gateway connect across Regions?**
**Yes**, via **inter-Region TGW peering**.

**Q78. How is a TGW shared across accounts?**
Via **AWS Resource Access Manager (RAM)** in an AWS Organization.

**Q79. What is centralized egress and why use it?**
Routing all VPCs' outbound internet through **one Egress VPC's NAT** via the TGW — cheaper than per-VPC NAT and gives a single audit/inspection point.

**Q80. What's a Transit Gateway attachment?**
The connection between the TGW and a resource — a VPC, VPN, Direct Connect gateway, or peering. You're billed per attachment-hour.

---

## VPC Endpoints (Q81–88)

**Q81. What is a VPC endpoint?**
A **private entry point** to reach AWS services (or partner/SaaS via PrivateLink) **without** traversing the internet, IGW, or NAT.

**Q82. Gateway endpoint vs interface endpoint?**
**Gateway** (S3, DynamoDB only) = a **route-table prefix-list** entry, **free**. **Interface** (most services) = an **ENI with a private IP** controlled by an SG, **billed** per-hour/per-GB.

**Q83. Which services use gateway endpoints?**
Only **S3** and **DynamoDB**.

**Q84. Why use a VPC endpoint instead of NAT for S3?**
It's **private** (never leaves AWS), **more secure**, and the gateway endpoint is **free**, removing S3 traffic from NAT data charges.

**Q85. What is AWS PrivateLink?**
The technology behind **interface endpoints** — exposes a service via an ENI/private IP in your VPC, including your own services to other VPCs/accounts without peering.

**Q86. How do you restrict what an endpoint can access?**
**Endpoint policies** (resource policy on the endpoint) for gateway/interface, plus **security groups** on interface endpoints.

**Q87. What does "private DNS" on an interface endpoint do?**
Makes the standard public service hostname (e.g. `secretsmanager.region.amazonaws.com`) resolve to the **private endpoint IP**, so apps need no code change.

**Q88. Endpoint vs peering vs TGW — when each?**
Endpoint = reach **AWS services** privately. Peering = connect **two VPCs**. TGW = connect **many VPCs/on-prem** at scale.

---

## Architecture & Scenarios (Q89–100)

**Q89. Design a basic 3-tier VPC.**
Public subnet (ALB + NAT) → private app subnet (ASG, route to NAT) → isolated DB subnet (RDS, local route only), with SG chaining web→app→db, across 2 AZs.

**Q90. How do you make the whole stack highly available?**
2+ AZs, mirrored subnets, ALB across AZs, **Auto Scaling Group** spanning AZs, **Multi-AZ RDS**, and **one NAT per AZ**.

**Q91. How do you let app servers patch without exposing them?**
Private subnets + **NAT Gateway** for outbound, or fully private via **VPC endpoints**; manage them with **SSM Session Manager** (no SSH/bastion).

**Q92. How would you connect 20 VPCs across 4 accounts?**
**Transit Gateway** shared via **RAM**, with TGW route tables for segmentation — not a peering mesh.

**Q93. How do you give a private subnet access to S3 cheaply and securely?**
Add a **free S3 gateway endpoint** and route the subnet's prefix-list to it — no NAT, fully private.

**Q94. A new VPC must talk to an existing one but CIDRs overlap. Options?**
You **can't peer overlapping CIDRs**. Re-IP one VPC, or use a **private NAT gateway / PrivateLink** to expose only specific services without routing the whole range.

**Q95. How do you isolate Dev from Prod but let both reach shared services?**
Separate VPCs on a **TGW**; route tables propagate Dev↔Shared and Prod↔Shared but **not** Dev↔Prod.

**Q96. How do you inspect all inter-VPC traffic?**
Route everything through a **central inspection VPC** (AWS Network Firewall / IDS-IPS) via the TGW, and enable **VPC Flow Logs**.

**Q97. Users report intermittent failures — only sometimes. Where do you look?**
Suspect a **single-AZ resource** (one NAT, non-mirrored subnet) failing for one AZ's traffic, or an unhealthy ALB target in one AZ. Check per-AZ NAT/subnet symmetry and target health.

**Q98. How do you reduce a high VPC bill?**
Add **gateway endpoints** (free) for S3/DynamoDB, **one NAT per AZ** to avoid cross-AZ charges, **centralized egress**, release idle **EIPs**, and interface endpoints for chatty services.

**Q99. How do you audit a VPC for accidental internet exposure?**
**Network Access Analyzer** / **Reachability Analyzer**, review route tables for `0.0.0.0/0 → IGW`, audit SGs for `0.0.0.0/0` inbound, and check public-IP assignment + Flow Logs.

**Q100. Walk me through a packet from a user's browser to a private DB.**
DNS (Route 53) → internet → **IGW** → public subnet **ALB** (SG allows 443 from world) → private **app** (SG allows app port from ALB SG, route to NAT for egress) → isolated **DB** (SG allows DB port from app SG, no internet route). Each hop is filtered by **route table + NACL + SG**, and stateful SGs let the reply return along the same path.

---

## 🎯 How to use this set
- First pass: cover the answer, say it aloud, check the **bold** keywords.
- Build the **stateful vs stateless** (Q51–53) and **public vs private internet flow** (Q36–50) answers until they're reflexive — they're asked in almost every interview.
- Pair with the [labs](06-labs.md) so you can say "I've actually built this," not just recite it.

**Next:** [09-50-scenario-questions.md](09-50-scenario-questions.md).

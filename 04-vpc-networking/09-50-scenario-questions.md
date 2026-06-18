# Module 9 — 50 VPC Scenario Questions

Real-world, "what would you do" problems — the kind asked in **solutions-architect interviews** and faced on the job. Each gives a **scenario**, then a **model answer** with the reasoning. Try to answer before reading.

> These reward *judgment*, not memorization. Say the trade-off out loud.

---

## Connectivity & Routing (1–10)

**1.** *A private EC2 instance can't download OS updates. It has a `0.0.0.0/0` route. What's wrong?*
→ Check the **target**. If it points to the **IGW** (not a NAT) and the instance has no public IP, traffic blackholes. Fix: route `0.0.0.0/0 → NAT Gateway`, and ensure the NAT is in a public subnet with its own IGW route.

**2.** *Two instances in the same VPC, different subnets, can't ping each other.*
→ The `local` route already connects them, so it's a **firewall**: the destination SG must allow ICMP from the source, and both subnets' NACLs must allow ICMP + return. Remember ping is ICMP, not TCP.

**3.** *You need VPC-A to reach VPC-B and VPC-C, and B to reach C.*
→ Peering isn't transitive, so a mesh needs 3 peerings (A-B, A-C, B-C). If this will grow, use a **Transit Gateway** instead of more peerings.

**4.** *After peering two VPCs, instances still can't connect.*
→ Most likely **missing routes on one side** (you need routes in *both* route tables) and/or **SGs not allowing the peer CIDR** (cross-VPC SG references aren't available by default). Also verify non-overlapping CIDRs.

**5.** *An app must reach S3 but the security team forbids any internet path.*
→ Add an **S3 gateway endpoint** (free, private). No IGW or NAT needed; traffic stays on the AWS backbone. Tighten with an endpoint policy.

**6.** *Outbound works from AZ-a private subnet but is slow/expensive from AZ-b.*
→ AZ-b is probably routed to a NAT Gateway in **AZ-a**, incurring cross-AZ data charges and latency. Deploy a **NAT per AZ** and route each subnet to its local NAT.

**7.** *A route table shows a `blackhole` route. Impact?*
→ Its target (NAT/IGW/peering) was deleted, so matching traffic is **dropped**. Recreate the target or remove/repoint the route.

**8.** *You must connect on-prem to AWS with consistent low latency for a database replication link.*
→ **Direct Connect** (private, dedicated, stable latency). Add a **Site-to-Site VPN** as encrypted backup. Terminate both on a Transit Gateway with BGP failover.

**9.** *An instance reaches services by IP but DNS names fail.*
→ Enable **`enableDnsSupport`** and **`enableDnsHostnames`** on the VPC; verify instances use the VPC `.2` resolver and no DHCP option set overrides DNS.

**10.** *You need 30 VPCs across 5 accounts to share central DNS and AD.*
→ **Transit Gateway** shared via **RAM**, plus a **Shared Services VPC** (Route 53 Resolver, AD). Segment with TGW route tables; non-overlapping CIDRs managed via IPAM.

---

## Security (11–22)

**11.** *Audit finds a database in a public subnet with 3306 open to 0.0.0.0/0.*
→ Critical. Move the DB to an **isolated private subnet** (no internet route), restrict its SG to **only the app SG** on 3306, remove the public IP, and rotate credentials assuming exposure.

**12.** *How do you let admins manage private instances without opening SSH?*
→ **SSM Session Manager** + interface endpoints (`ssm`, `ssmmessages`, `ec2messages`). No port 22, no bastion, full IAM audit. Remove all inbound 22 rules.

**13.** *You must block a specific malicious IP range from an entire subnet.*
→ SGs can't deny, so add a **DENY rule in the subnet's NACL** for that CIDR (low rule number so it's evaluated first).

**14.** *A NACL change broke a working app — connections hang.*
→ Classic **stateless** mistake: you allowed one direction but not the **ephemeral return** (1024–65535). Add the matching return rule, or revert to the default NACL and let SGs do the filtering.

**15.** *Design least-privilege firewalling for web→app→db.*
→ **SG chaining**: `sg-web` allows 443 from world; `sg-app` allows app port from `sg-web` only; `sg-db` allows DB port from `sg-app` only. Reference SG-ids, never CIDRs, so it scales.

**16.** *Compliance requires inspecting all traffic between VPCs.*
→ Route inter-VPC traffic through a **central inspection VPC** (AWS Network Firewall / IDS-IPS) via the **Transit Gateway**; enable **Flow Logs** and **GuardDuty**.

**17.** *You suspect data exfiltration from a compromised instance.*
→ Check **VPC Flow Logs** for unusual outbound destinations/ports; restrict **egress** SG rules (default-deny outbound to only required destinations); enable **GuardDuty**; consider domain filtering via Network Firewall.

**18.** *How do you prove no resource is unintentionally internet-reachable?*
→ **Network Access Analyzer** (finds exposed paths) and **Reachability Analyzer** (path between two ENIs); audit route tables for `0.0.0.0/0 → IGW` and SGs for `0.0.0.0/0` inbound.

**19.** *Where should TLS terminate for a public web app, and how to secure app→DB?*
→ Terminate TLS at the **ALB** (ACM cert); re-encrypt or use TLS to the app if required; enforce **SSL on RDS** for app→DB. Encrypt at rest with KMS.

**20.** *A single shared SG is attached to every instance. Risk and fix?*
→ Over-permissive: a breach anywhere reaches everything. Split into **per-tier/per-role SGs** with least-privilege chaining; remove broad allows.

**21.** *Egress to the internet must be denied for a PCI workload except to two partner IPs.*
→ Put the workload in an **isolated subnet** (no NAT route), use **interface endpoints** for needed AWS services, and if partner egress is required, allow it narrowly via a controlled NAT/firewall with **egress SG rules** scoped to those IPs + domain allow-listing in Network Firewall.

**22.** *How do you store and deliver DB credentials to app instances securely?*
→ **Secrets Manager** (or Parameter Store) accessed via an **instance role** and an interface endpoint — never hard-coded env files or AMI-baked secrets.

---

## High Availability & Architecture (23–34)

**23.** *Design a highly available 3-tier web app.*
→ 2+ AZs; public subnets (ALB + one NAT each); private app subnets (Auto Scaling Group across AZs, route to local NAT); isolated DB subnets (**Multi-AZ RDS**); SG chaining; S3 gateway endpoint; SSM for admin.

**24.** *One NAT Gateway serves all AZs. What's the risk?*
→ **Single point of failure** (that AZ dies → all egress dies) plus **cross-AZ charges**. Fix: one NAT per AZ with local routing.

**25.** *RDS failover happened but the app didn't reconnect cleanly.*
→ Ensure the app uses the **RDS endpoint DNS** (not the IP), with connection retry/pooling; Multi-AZ failover repoints DNS to the standby. Verify SGs allow both AZ subnets.

**26.** *Your app spans 2 AZs but users in one AZ see errors during an AZ event.*
→ Likely a **single-AZ dependency** (one NAT, a subnet in only one AZ, or unbalanced targets). Mirror all tiers across AZs and enable cross-zone load balancing.

**27.** *How many subnets for a 3-tier app across 3 AZs?*
→ Typically **9** (web/app/data × 3 AZs), each in its AZ, with public RTs for web and private/isolated RTs for app/data.

**28.** *Design centralized internet egress for 15 VPCs.*
→ A **TGW** with an **Egress VPC** holding the NAT fleet; spoke VPCs default-route to the TGW. Saves running 15 separate NATs and centralizes logging/inspection.

**29.** *Plan CIDRs for an org that will have ~50 VPCs.*
→ Allocate a large non-overlapping block (e.g. `10.0.0.0/8`) and carve predictable per-VPC ranges via **AWS IPAM**, reserving space for on-prem and growth. Never overlap.

**30.** *A team wants Dev to be unable to reach Prod, but both reach Shared Services.*
→ Separate VPCs on a TGW; use **TGW route tables** so Dev and Prod associate/propagate to Shared but not to each other.

**31.** *Choose between VPC peering and Transit Gateway for 3 VPCs.*
→ For just 3, **peering** (no per-attachment/processing fee, simple). If growth to many VPCs or on-prem is expected, start with **TGW**.

**32.** *Migrate from a single overloaded /24 VPC.*
→ Add a **secondary CIDR** for room, create properly sized subnets, and migrate workloads; longer-term, redesign into a well-planned VPC with /16 + tiered /24 subnets.

**33.** *Expose an internal service to a partner account privately.*
→ **PrivateLink**: front the service with an NLB and create an endpoint service; the partner creates an **interface endpoint** — no peering, no CIDR coordination, one-way private access.

**34.** *Active-active across two Regions.*
→ One VPC per Region, **Route 53 latency/failover routing**, cross-Region replication (e.g. RDS read replicas/Aurora Global), and **inter-Region TGW or peering** for control traffic. Keep CIDRs non-overlapping.

---

## Cost (35–42)

**35.** *NAT data charges are huge; most traffic is S3.*
→ Add the **free S3 gateway endpoint** to the private route tables — removes S3 traffic from NAT entirely. Add DynamoDB endpoint too if used.

**36.** *Billing shows big "EC2-Other" charges you can't explain.*
→ That's where **NAT data + cross-AZ/internet transfer** live. Filter Cost Explorer by usage type (`NatGateway`, `DataTransfer`, `Bytes`); add endpoints and per-AZ NAT.

**37.** *Reduce cost of a dev environment's networking.*
→ Single NAT (or a tiny **NAT instance**), shut it down off-hours, no Multi-AZ, gateway endpoints, and turn off high-volume Flow Logs.

**38.** *Many idle Elastic IPs on the account.*
→ Release unattached EIPs (`describe-addresses` where `AssociationId==null`); also minimize public IPv4 since all public IPv4 now bills.

**39.** *Is a Transit Gateway worth it for 2 VPCs?*
→ Usually not — TGW has per-attachment + per-GB fees; **peering** has no attachment fee. TGW pays off at scale or when you need transitivity/segmentation.

**40.** *Container image pulls through NAT are costly.*
→ Add an **ECR interface endpoint** (+ S3 gateway endpoint for layers) so pulls bypass NAT data charges; weigh endpoint hourly cost vs NAT data saved.

**41.** *Cut cross-AZ data transfer for a chatty app↔cache path.*
→ Co-locate the hot path in the **same AZ** where HA allows, or use AZ-aware clients; keep replicas cross-AZ for durability but route reads locally.

**42.** *Flow Logs are inflating CloudWatch costs.*
→ Send Flow Logs to **S3** with **lifecycle expiration**, filter to `REJECT` or sample, and disable on low-value VPCs.

---

## Troubleshooting (43–50)

**43.** *ALB targets are unhealthy. Diagnose.*
→ Check target **SG allows the ALB SG** on the health-check port, the **health path returns 200**, the app **listens** on that port, and ALB AZs/subnets can route to targets. NACLs must allow both ways.

**44.** *SSH works to a bastion but not from bastion to a private host.*
→ Private host SG must allow 22 **from the bastion's SG**; both subnets' NACLs allow 22 + ephemeral; correct key/user. (Better: replace with SSM.)

**45.** *Intermittent failures only for some users.*
→ Suspect a **single-AZ** weakness (one NAT, a missing subnet in an AZ, or one unhealthy target). Check per-AZ symmetry and target health.

**46.** *A new NACL rule didn't take effect as expected.*
→ NACL rules are evaluated by **number ascending**; a lower-numbered conflicting rule (or a low DENY) shadows your new rule. Renumber so order is correct.

**47.** *An SG change "didn't work."*
→ SGs apply almost instantly and have **no deny** — if blocked, the allow simply doesn't match (wrong port/protocol/source) or you edited the wrong SG/ENI. Verify with Flow Logs.

**48.** *Private instance can't reach SSM (Session Manager) — no NAT allowed.*
→ Create **interface endpoints** for `ssm`, `ssmmessages`, `ec2messages` with an SG allowing 443 from the instances, and enable **private DNS** so the agent resolves them.

**49.** *Subnet ran out of IPs unexpectedly.*
→ Remember **5 reserved** per subnet and that ECS/EKS/Lambda ENIs consume IPs fast. Add a **secondary CIDR** with larger subnets, or right-size to /24+.

**50.** *"Why can't service A reach database B?" — fastest path to an answer.*
→ Run **VPC Reachability Analyzer** between the two ENIs; it pinpoints the blocking hop (route, SG, or NACL) so you don't have to check each layer by hand.

---

## 🎯 How to use this set
- Answer aloud first, then compare — interviewers grade your **reasoning and trade-offs**, not just the keyword.
- Map every scenario back to the **6-point checklist** in [05-troubleshooting.md](05-troubleshooting.md).
- Build the [labs](06-labs.md) so you can say "I've done this," and finish the [capstone](project/README.md).

*End of Phase 04 — VPC. Back to the [README](README.md).*

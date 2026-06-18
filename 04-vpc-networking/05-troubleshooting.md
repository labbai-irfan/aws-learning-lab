# Module 4 — VPC Troubleshooting Guide

The symptoms you'll actually hit, with a **diagnosis order** for each. Networking bugs are almost always one of: *wrong route, wrong firewall (SG/NACL), missing public IP, missing gateway, or DNS*. Work the checklist top to bottom.

> 💡 **The universal method:** trace the **packet path** (see [README — Packet Flow](README.md#1-packet-flow--the-lowest-level-where-a-single-packet-is-checked)). At each hop ask: *is there a route to the next hop? does the firewall allow it (both directions)?*

---

## 🔧 The 6-point checklist (run this for ANY connectivity issue)

```
   1. ROUTE      Does the source subnet's route table have a path to the dest?
   2. SG OUT     Does the source's security group allow the egress?
   3. NACL OUT   Does the source subnet's NACL allow egress (+ return ephemeral)?
   4. NACL IN    Does the dest subnet's NACL allow ingress (+ return ephemeral)?
   5. SG IN      Does the dest's security group allow the ingress?
   6. PUBLIC IP  If internet is involved: is there a public/Elastic IP + IGW?
```
**Tool of choice:** **VPC Reachability Analyzer** does steps 1–6 for you between any two ENIs — start there if available.

---

## Symptom 1 — "Can't SSH/RDP to my instance"

**Diagnosis order:**
```
   □ Instance has a PUBLIC IP?        → public subnet + auto-assign or EIP
   □ Subnet route 0.0.0.0/0 → IGW?    → otherwise it's not really public
   □ SG inbound allows 22/3389 from YOUR IP?  (not 0.0.0.0/0 — 🔒)
   □ SG outbound allows the return?   (default SG allows all out — fine)
   □ NACL allows 22 IN and ephemeral 1024-65535 OUT?
   □ OS firewall (ufw/iptables/Windows) not blocking?
   □ Right key pair / username? (ec2-user, ubuntu, admin...)
```
**Most common cause:** SG inbound rule missing, or instance is in a private subnet with no public IP.
💡 Skip SSH entirely with **SSM Session Manager** (no port 22, no bastion).

---

## Symptom 2 — "Instance can't reach the internet (outbound)"

```
   PUBLIC instance:
     □ Has a public IP?              □ Route 0.0.0.0/0 → IGW?
     □ SG outbound allows traffic?   □ NACL allows out + return?

   PRIVATE instance:
     □ Route 0.0.0.0/0 → NAT Gateway? (NOT → IGW — that silently fails w/o public IP)
     □ NAT GW is in a PUBLIC subnet with its own route to IGW?
     □ NAT GW state = available, has an Elastic IP?
     □ NACL on the private subnet allows out + return ephemeral?
```
**Classic trap:** a private instance routed to the **IGW** instead of the **NAT**. With no public IP, the IGW can't translate it → packets blackhole. Fix: point `0.0.0.0/0` at the NAT Gateway.

---

## Symptom 3 — "Two instances in the same VPC can't talk"

```
   □ Same VPC?  → the `local` route already connects all subnets.
   □ Dest SG inbound allows the source (by SG-id or CIDR) on the right port?
   □ Source SG outbound allows it? (default = all out)
   □ NACLs on BOTH subnets allow the traffic + return?
   □ Right private IP / port / protocol (TCP vs UDP vs ICMP)?
```
**Most common cause:** the destination SG doesn't reference the source SG/CIDR. Remember `ping` is **ICMP** — if you only allowed TCP, ping fails but the app may still work (and vice-versa).

---

## Symptom 4 — "Can reach by IP but DNS doesn't resolve"

```
   □ VPC has enableDnsSupport = true?
   □ VPC has enableDnsHostnames = true?  (needed for public DNS names)
   □ Using the AWS DNS at VPC-base+2 (e.g. 10.0.0.2)?
   □ Custom DHCP option set overriding DNS? (check it points somewhere valid)
   □ For private hosted zones: zone associated with this VPC?
```
**Fix:** `aws ec2 modify-vpc-attribute --vpc-id vpc-xxx --enable-dns-hostnames`

---

## Symptom 5 — "VPC peering connection isn't working"

```
   □ Peering status = active (not pending-acceptance)?
   □ ROUTES added on BOTH VPCs' route tables (to each other's CIDR)?
   □ SGs allow the peer's CIDR (you can't reference cross-VPC SGs by default)?
   □ NACLs allow the peer CIDR both ways?
   □ CIDRs DON'T overlap?
   □ Trying to reach a THIRD VPC through the peer? → not transitive, won't work.
```
**Top two causes:** missing route on one side, or expecting transitive routing.

---

## Symptom 6 — "Application Load Balancer shows unhealthy targets"

```
   □ Target SG allows the ALB SG on the health-check port?
   □ Health check path returns 200? (wrong path → 404 → unhealthy)
   □ App actually listening on the target port/protocol?
   □ Targets in subnets the ALB can route to (same VPC, AZs enabled on ALB)?
   □ NACLs allow ALB subnet ↔ target subnet + ephemeral returns?
   □ Security: ALB in PUBLIC subnets, targets in PRIVATE — both with right routes?
```
**Most common cause:** target SG doesn't allow the ALB's SG, or the health-check path/port is wrong.

---

## Symptom 7 — "Surprise NAT Gateway / data-transfer bill" 💰

```
   □ Heavy S3/DynamoDB traffic going through NAT? → add a FREE Gateway Endpoint.
   □ Cross-AZ NAT? (private subnet in AZ-a routing to NAT in AZ-b) → 1 NAT per AZ.
   □ Idle Elastic IPs (not attached)? → release them.
   □ Chatty outbound from many private hosts? → consider interface endpoints
     (ECR, S3, CloudWatch, SSM) to cut NAT data processing charges.
```
**Biggest win:** the **S3 gateway endpoint is free** and often removes the majority of NAT data charges.

---

## Symptom 8 — "Can't reach an AWS service (S3/SSM/etc.) from a private subnet"

```
   □ Have a route to the internet (NAT) OR a VPC Endpoint?
   □ Gateway endpoint (S3/DynamoDB): route table has the prefix-list route?
   □ Interface endpoint: SG on the endpoint ENI allows 443 from your instances?
   □ Private DNS enabled on the interface endpoint? (so the normal service URL resolves to it)
   □ Endpoint policy not denying the action?
```

---

## Symptom 9 — "Ran out of IP addresses in a subnet"

```
   □ Remember AWS reserves 5 IPs per subnet (/24 = 251 usable, not 256).
   □ ENIs from ECS/EKS/Lambda consuming IPs faster than expected?
   □ Subnet too small (/28 = 11 usable)?
   Fix options:
     • Add a SECONDARY CIDR block to the VPC and create bigger subnets.
     • Right-size: use /24 or larger for workloads with many ENIs.
```

---

## Symptom 10 — "SG change didn't take effect" / "NACL blocking despite allow rule"

```
   Security Group:
     □ SG changes are near-instant; if not working, you edited the wrong SG/ENI.
     □ No "deny" exists in SGs — if blocked, the allow simply isn't matching
       (wrong port/protocol/source).

   NACL:
     □ Rules evaluated by NUMBER, lowest first — a low-numbered DENY can
       shadow a higher-numbered ALLOW. Reorder rule numbers.
     □ Forgot the return-direction ephemeral rule (stateless!).
```

---

## 🩺 Diagnostic tools & commands

| Tool | Use it for |
|------|-----------|
| **VPC Reachability Analyzer** | "Why can't A reach B?" — checks the whole path automatically |
| **VPC Flow Logs** | See ACCEPT/REJECT per packet (REJECT = a firewall blocked it) |
| **`describe-route-tables`** | Confirm the next-hop for a destination |
| **`describe-security-groups`** | Inspect allow rules / SG references |
| **`describe-network-acls`** | Check numbered allow/deny + both directions |
| **Network Access Analyzer** | Audit for unintended internet exposure |

**Reading a Flow Log REJECT** (the smoking gun):
```
   2 acct eni-x 10.0.2.10 142.250.1.1 51000 443 6 ... REJECT OK
                 └ source   └ dest      └sport └dport └proto      └ a firewall dropped it
   → REJECT on egress  = your SG-out or NACL-out blocked it
   → REJECT on ingress = the dest SG-in or NACL-in blocked it
```

🛠️ **Enable Flow Logs:**
```bash
aws ec2 create-flow-logs --resource-type VPC --resource-ids vpc-xxxx \
  --traffic-type ALL --log-destination-type cloud-watch-logs \
  --log-group-name /vpc/flowlogs --deliver-logs-permission-arn <role-arn>
```

---

## 🧠 Mental shortcuts

- **Reply fails but request succeeds** → suspect a **stateless NACL** missing the return rule.
- **Works in same subnet, fails across subnets** → suspect **NACL** or **route table**.
- **Outbound fails from private host** → suspect **NAT route / NAT health**.
- **Inbound fails from internet** → suspect **public IP / IGW route / SG inbound**.
- **Only `ping` fails** → it's **ICMP**, not your TCP app — allow ICMP if you need ping.
- **Intermittent / one-AZ failure** → suspect a **single-AZ NAT** or non-mirrored subnets.

**Next:** [06-labs.md](06-labs.md).

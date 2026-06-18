# Module 3 — VPC Cost Optimization

The VPC itself is **free**. Subnets, route tables, internet gateways, security groups, NACLs, and **S3/DynamoDB gateway endpoints** cost nothing. Your VPC bill comes almost entirely from a short list of **data movement** and **managed appliances**. Know them and you control the bill.

> 💰 = cost lever · ⚠️ = common surprise · 💡 = action

---

## 1. What actually costs money in a VPC

```
   FREE (no charge)                       PAID (watch these)
   ──────────────────────────────────     ─────────────────────────────────────
   VPC                                     NAT Gateway     (per-hour + per-GB)
   Subnets, route tables                   Elastic IP      (when idle/unused)
   Internet Gateway                        Interface endpoints (per-AZ-hr + GB)
   Security Groups, NACLs                  Transit Gateway (per-attachment + GB)
   S3 / DynamoDB GATEWAY endpoints         VPN connection  (per-hour + GB)
   Intra-AZ, same-subnet traffic           Cross-AZ data transfer (per-GB both ways)
                                           Cross-Region / internet egress (per-GB)
                                           VPC Flow Logs    (ingestion + storage)
```

**The big four, in order of how often they surprise people:**
1. **NAT Gateway data processing** — every GB through NAT is billed, on top of the hourly charge.
2. **Cross-AZ data transfer** — traffic between AZs is charged **per GB in both directions**.
3. **Idle Elastic IPs** — an EIP not attached to a running resource bills hourly.
4. **Interface endpoints / TGW attachments** — small hourly charges that multiply across many AZs/VPCs.

---

## 2. NAT Gateway — the #1 line item

A NAT Gateway costs roughly **$0.045/hr (~$32/mo) PLUS ~$0.045 per GB processed** (varies by Region). The per-GB charge is what explodes.

```
   Scenario: 50 private instances pulling 2 TB/month of OS updates,
             container images, and S3 reads through ONE NAT GW.

   Hourly:        ~$32/mo
   Data (2 TB):   2048 GB × $0.045  ≈ $92/mo
   ───────────────────────────────────────
   Total per NAT: ~$124/mo   ×  (often 2-3 NATs for HA) = $250-370/mo
```

**How to cut it:**

| 💡 Action | Saving |
|----------|--------|
| Add a **free S3 gateway endpoint** | Removes ALL S3 traffic from NAT data charges |
| Add a **DynamoDB gateway endpoint** | Removes DynamoDB traffic (also free) |
| Add **interface endpoints** for ECR, S3, CloudWatch, SSM | Container pulls + logs bypass NAT |
| **Centralize egress** (enterprise) via a TGW + one Egress VPC | One NAT fleet instead of one-per-VPC |
| Cache packages internally / use a pull-through cache | Fewer external fetches |
| For dev/test: a **single NAT** or a **NAT instance** (t4g.nano) | Accept lower HA for big savings |

⚠️ **The classic trap:** terabytes of S3 reads routed through NAT when a **free** gateway endpoint would have carried them privately at zero data cost. **Always add the S3 gateway endpoint** — it pays for itself instantly.

---

## 3. Cross-AZ data transfer — the silent tax

Traffic that crosses an Availability Zone boundary is billed **~$0.01/GB each way**. It hides inside "normal" architecture.

```
   ⚠️ Hidden cross-AZ charges:
     • Private subnet in AZ-a routed to a NAT Gateway in AZ-b
           → every outbound byte crosses an AZ AND pays NAT data
     • App in AZ-a talking to RDS primary in AZ-b
     • Load balancer in AZ-a forwarding to a target in AZ-b
```

**How to cut it:**
- ✅ Deploy **one NAT Gateway per AZ** and route each AZ's private subnet to its **local** NAT (saves the cross-AZ hop *and* improves HA — the rare win-win).
- ✅ Keep chatty tiers **AZ-aligned** where safe; enable **cross-zone load balancing** awareness.
- ✅ Use **gateway endpoints** (traffic to S3/DynamoDB stays in-Region, no AZ charge).
- ✅ Prefer **same-AZ** placement for high-throughput app↔cache paths (balance against HA needs).

💡 Same-subnet and same-AZ traffic using **private IPs** is **free** — design hot paths to stay there.

---

## 4. Elastic IPs — pay for what you don't use

```
   Attached to a running instance / active NAT GW   →  FREE (one per resource)
   Allocated but NOT attached (or attached to a stopped instance) → BILLED hourly
```
💡 **Action:** run a monthly sweep for orphaned EIPs:
```bash
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output table
# then release the ones you don't need:
aws ec2 release-address --allocation-id eipalloc-xxxx
```
⚠️ Note: AWS now charges for **all** public IPv4 addresses (even in-use). Audit whether instances need public IPs at all — most should be **private + NAT/endpoints**.

---

## 5. VPC Endpoints — when they save vs. cost

```
   GATEWAY endpoint (S3, DynamoDB):  FREE  →  ALWAYS add these. Pure savings.

   INTERFACE endpoint (PrivateLink): ~$0.01/hr per AZ + ~$0.01/GB
       Cost example: 1 endpoint × 3 AZs × 730 hr ≈ $22/mo before data
       → Worth it when it removes MORE in NAT data charges than it costs,
         or when you need a fully private path (no internet at all).
```
💡 **Decision rule:** if the service is **S3 or DynamoDB → gateway endpoint, always**. For others, add an interface endpoint when the **NAT data you'd avoid** exceeds the endpoint's hourly cost, or when **compliance** requires no internet path.

---

## 6. Transit Gateway costs

```
   Per ATTACHMENT-hour : ~$0.05/hr each (~$36/mo per VPC attached)
   Per GB processed    : ~$0.02/GB
```
- 💡 For **2–3 VPCs**, plain **VPC peering** has **no per-hour attachment fee** and no per-GB processing on the peering itself (you still pay cross-AZ/Region data) — often cheaper than a TGW.
- 💡 TGW wins at **scale** (many VPCs, on-prem, segmentation) where it replaces an unmanageable peering mesh and enables **centralized egress** that saves more than it costs.

---

## 7. VPN & Direct Connect

```
   Site-to-Site VPN : ~$0.05/hr per connection + data egress
   Direct Connect   : port-hour fee + (much lower) DX data transfer rates
```
💡 At sustained high bandwidth, **Direct Connect's** lower per-GB rate beats VPN/internet egress despite the port fee. Use VPN as the cheaper backup path.

---

## 8. VPC Flow Logs

Flow Logs are great for security/debugging but you pay **CloudWatch/S3 ingestion + storage**.
- 💡 Send high-volume logs to **S3** (cheaper than CloudWatch Logs) and apply **lifecycle expiration**.
- 💡 Filter to `REJECT` only, or sample, if you just need security signal rather than full accounting.
- 💡 Turn logs off on low-value dev VPCs.

---

## 9. A cost-optimized reference layout

```
   ┌──────────────── VPC (free) ────────────────────────────────┐
   │  Public subnet:  ONE NAT GW per AZ (not a shared cross-AZ)  │
   │  Private app:    routes to LOCAL-AZ NAT + gateway endpoints │
   │  Isolated DB:    no internet route at all                   │
   │                                                             │
   │  [ S3 Gateway Endpoint ]  ← FREE, kills S3 NAT data         │
   │  [ DynamoDB Gateway Endpoint ] ← FREE                       │
   │  [ Interface EPs: ECR, SSM, Logs ] ← only if they beat NAT  │
   │  No public IPs on app/DB instances                          │
   │  Flow Logs → S3 with 30-day lifecycle                       │
   └─────────────────────────────────────────────────────────────┘
```

---

## 10. Monthly cost-hygiene checklist

```
   □ Released all unattached Elastic IPs?
   □ S3 + DynamoDB gateway endpoints present on every private route table?
   □ One NAT per AZ (no cross-AZ NAT routing)?
   □ Any instance with a public IP that could be private + NAT/endpoint?
   □ TGW attachments / interface endpoints still in use (delete dead ones)?
   □ Flow Logs going to S3 with lifecycle expiry, not unbounded CloudWatch?
   □ Reviewed Cost Explorer filtered to "EC2-Other" (NAT + data transfer live here)?
   □ Dev/test NATs shut down outside working hours?
```

💡 **Where to look in billing:** NAT and data-transfer charges show up under **"EC2-Other"** in Cost Explorer, not under "VPC" — that's why they're easy to miss. Filter by **usage type** containing `NatGateway`, `DataTransfer`, and `Bytes`.

---

## 💰 Top 5 takeaways

1. **Add the free S3/DynamoDB gateway endpoints** — biggest, easiest NAT-data win.
2. **One NAT per AZ** — kills cross-AZ charges *and* a SPOF at once.
3. **Release idle EIPs** and minimize public IPv4 usage.
4. **Peering for a few VPCs, TGW for many** — match the tool to scale.
5. **NAT data hides in "EC2-Other"** — that's where to hunt for savings.

**Next:** [04-security-guide.md](04-security-guide.md).

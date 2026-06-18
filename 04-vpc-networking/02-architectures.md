# Module 2 — VPC Architectures

Three reference designs, smallest to largest: **Multi-tier** (the foundation) → **Production** (HA single-region) → **Enterprise** (many VPCs + on-prem). Each has a diagram, the subnet/route/SG plan, and the "why".

---

## A. Multi-Tier Architecture (the 3-tier foundation)

The mental model every other design extends. Three layers, each more locked-down than the one above.

```
   Internet
      │
   ┌──┴──────────────── VPC 10.0.0.0/16 ─────────────────────┐
   │  Internet Gateway                                        │
   │                                                          │
   │  TIER 1 — WEB / EDGE   (PUBLIC subnet 10.0.1.0/24)       │
   │  ┌────────────────────────────────────────────────────┐ │
   │  │  [ Application Load Balancer ]                       │ │
   │  │   SG-web: allow 80/443 from 0.0.0.0/0               │ │
   │  │  Route: 0.0.0.0/0 → IGW                              │ │
   │  └───────────────────────┬────────────────────────────┘ │
   │                          │ forwards to app                │
   │  TIER 2 — APP   (PRIVATE subnet 10.0.2.0/24)            │
   │  ┌───────────────────────▼────────────────────────────┐ │
   │  │  [ App EC2 / ECS ]  Auto Scaling Group              │ │
   │  │   SG-app: allow 8080 from SG-web ONLY               │ │
   │  │  Route: 0.0.0.0/0 → NAT (for outbound only)         │ │
   │  └───────────────────────┬────────────────────────────┘ │
   │                          │ queries                        │
   │  TIER 3 — DATA  (ISOLATED subnet 10.0.3.0/24)          │
   │  ┌───────────────────────▼────────────────────────────┐ │
   │  │  [ RDS ]  [ ElastiCache ]                            │ │
   │  │   SG-db: allow 3306 from SG-app ONLY                │ │
   │  │  Route: local only (NO internet at all)             │ │
   │  └─────────────────────────────────────────────────────┘ │
   └──────────────────────────────────────────────────────────┘
```

**Subnet plan:**
| Tier | Subnet | Type | `0.0.0.0/0` route | What's in it |
|------|--------|------|-------------------|--------------|
| Web | 10.0.1.0/24 | Public | → IGW | ALB, NAT GW, bastion |
| App | 10.0.2.0/24 | Private | → NAT | App servers, containers |
| Data | 10.0.3.0/24 | Isolated | *(none)* | RDS, cache |

**Security group chain (memorize this):**
```
   world ──443──► SG-web ──8080──► SG-app ──3306──► SG-db
   Each tier allows traffic ONLY from the SG directly in front of it.
```

**Why it's good:** Blast radius is tiny. If the web tier is compromised, the attacker still can't reach the DB directly (SG-db only trusts SG-app). The data tier has no internet path at all.

---

## B. Production Architecture (highly available, single Region)

Multi-tier + **multi-AZ redundancy** + managed scaling + private AWS access. This is the "do it right" default for a real workload.

```
                              Internet
                                 │
                          Route 53  (DNS, health checks, failover)
                                 │
                          Internet Gateway
   ┌──────────────────────── VPC 10.0.0.0/16 ──────────────────────────────┐
   │                                                                        │
   │           AZ ap-south-1a                AZ ap-south-1b                 │
   │   ┌─────────────────────────┐   ┌─────────────────────────┐           │
   │   │ PUBLIC 10.0.1.0/24      │   │ PUBLIC 10.0.11.0/24     │           │
   │   │   ALB node ◄════════════╪═══╪═══► ALB node            │ ← one ALB │
   │   │   NAT GW (A) + EIP      │   │   NAT GW (B) + EIP      │   2 nodes │
   │   └────────────┬────────────┘   └────────────┬────────────┘           │
   │   ┌────────────▼────────────┐   ┌────────────▼────────────┐           │
   │   │ PRIVATE-APP 10.0.2.0/24 │   │ PRIVATE-APP 10.0.12.0/24│           │
   │   │   App EC2 ×N  ◄═══ Auto Scaling Group spans AZs ═══►   │           │
   │   │   route 0/0 → NAT-A      │   │   route 0/0 → NAT-B      │ ← per-AZ │
   │   └────────────┬────────────┘   └────────────┬────────────┘   NAT     │
   │   ┌────────────▼────────────┐   ┌────────────▼────────────┐           │
   │   │ PRIVATE-DB 10.0.3.0/24  │   │ PRIVATE-DB 10.0.13.0/24 │           │
   │   │   RDS PRIMARY ◄═══ Multi-AZ sync replication ═══► STANDBY          │
   │   └─────────────────────────┘   └─────────────────────────┘           │
   │                                                                        │
   │   [ S3 Gateway Endpoint ]  [ Interface Endpoints: SSM, ECR, Secrets ]  │
   └────────────────────────────────────────────────────────────────────────┘
```

**Design decisions that matter:**
| Decision | Why |
|----------|-----|
| **2+ AZs**, subnets mirrored | Survive an AZ outage with zero downtime |
| **One NAT GW per AZ** | Avoid cross-AZ data charges + single point of failure |
| **Auto Scaling Group across AZs** | Capacity follows demand; replaces dead instances |
| **RDS Multi-AZ** | Automatic failover to standby in the other AZ |
| **ALB across public subnets** | Spreads/​health-checks traffic to healthy targets |
| **S3 Gateway Endpoint** | Private S3 access, removes NAT data cost |
| **Interface Endpoints (SSM/ECR/Secrets)** | Patch & deploy without exposing instances; no bastion needed |
| **No SSH / use SSM Session Manager** | 🔒 Removes port 22 and the bastion entirely |

**Routing summary:**
```
   Public RT  : 10.0.0.0/16 → local ; 0.0.0.0/0 → IGW
   App-A RT   : 10.0.0.0/16 → local ; 0.0.0.0/0 → NAT-A ; pl-S3 → vpce-s3
   App-B RT   : 10.0.0.0/16 → local ; 0.0.0.0/0 → NAT-B ; pl-S3 → vpce-s3
   DB RT      : 10.0.0.0/16 → local      (no internet)
```

💰 **Cost levers:** 2 NAT GWs ≈ the biggest line item; for dev environments use **one** NAT GW (accept the cross-AZ risk) or **NAT instance**; always add the free **S3 gateway endpoint**.

---

## C. Enterprise Architecture (multi-VPC, hub-and-spoke, on-prem)

When you have many teams/accounts/environments. Built around a **Transit Gateway** hub, centralized egress, and centralized inspection. Usually paired with **AWS Organizations** + multiple accounts.

```
   ON-PREMISES DATA CENTER
        │  AWS Direct Connect (primary)  +  Site-to-Site VPN (backup)
        ▼
   ┌══════════════════════ TRANSIT GATEWAY (regional hub) ══════════════════════┐
   │   TGW Route Tables enforce segmentation:                                    │
   │     • Prod   ↔ Shared, Egress, Inspection                                   │
   │     • Dev    ↔ Shared, Egress, Inspection   (Dev ✗ Prod  — isolated)        │
   └─┬───────────┬───────────┬───────────┬────────────┬────────────┬────────────┘
     │ attach    │ attach    │ attach    │ attach     │ attach     │ attach
   ┌─▼────┐   ┌──▼───┐   ┌───▼────┐  ┌───▼─────┐  ┌───▼──────┐  ┌──▼────────┐
   │ PROD │   │ DEV  │   │ SHARED │  │SECURITY │  │ EGRESS   │  │  on-prem  │
   │ VPC  │   │ VPC  │   │SERVICES│  │/INSPECT │  │ VPC      │  │ (DX/VPN)  │
   │      │   │      │   │  VPC   │  │  VPC    │  │ central  │  │           │
   │3-tier│   │3-tier│   │ DNS,   │  │firewall │  │ NAT GW   │  │           │
   │ app  │   │ app  │   │ AD, CI │  │ IDS/IPS │  │ for all  │  │           │
   └──────┘   └──────┘   └────────┘  └─────────┘  └──────────┘  └───────────┘
```

**The five VPC roles:**
| VPC | Purpose |
|-----|---------|
| **Prod / Dev / per-app** | The actual workloads (each a multi-tier VPC, isolated by TGW routing) |
| **Shared Services** | DNS (Route 53 Resolver), Active Directory, CI/CD, artifact repos |
| **Security / Inspection** | All inter-VPC and internet traffic routed through a firewall (Network Firewall / 3rd-party IDS/IPS) |
| **Egress** | One **central NAT GW** for all VPCs' outbound internet — saves money + central logging |
| **Ingress** (optional) | Centralized ALB/WAF for inbound public traffic |

**Why centralize egress & inspection:**
```
   WITHOUT central egress: every VPC runs its own NAT GW  →  10 VPCs = 10× NAT cost
   WITH central egress:    all VPCs → TGW → Egress VPC → 1 NAT GW set  →  cheaper + one audit point

   WITHOUT inspection: VPC-to-VPC traffic is unmonitored
   WITH inspection:    TGW routes everything through the Security VPC firewall first
```

**Connectivity to on-prem:**
```
   Direct Connect  →  private, dedicated, low-latency, high-bandwidth (primary)
   Site-to-Site VPN →  encrypted over internet, cheap, used as failover
   Both terminate on the TGW; BGP picks the active path.
```

**Key enterprise principles:**
- 🔒 **Segmentation via TGW route tables** — Dev physically cannot route to Prod.
- 💰 **Centralized egress/endpoints** — share expensive resources across all VPCs.
- 📋 **Non-overlapping CIDRs** across every VPC and on-prem (plan an IP allocation scheme up front, e.g. with AWS IPAM).
- 👁️ **Central inspection + flow logs** — one place to see and police all traffic.
- 🏢 **Multi-account** (AWS Organizations) — share the TGW with **Resource Access Manager (RAM)**.

---

## 📐 Choosing an architecture

```
   How many VPCs / accounts?            Recommended design
   ──────────────────────────────────────────────────────────────
   1 app, learning/dev          →  Multi-tier, single AZ
   1 app, real users            →  Production (multi-AZ, ASG, Multi-AZ RDS)
   2–3 VPCs, need to connect    →  VPC Peering
   4+ VPCs / multi-account / on-prem  →  Transit Gateway (Enterprise)
```

**Next:** [03-cost-optimization.md](03-cost-optimization.md).

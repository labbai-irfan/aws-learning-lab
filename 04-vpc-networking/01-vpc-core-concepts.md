# Module 1 — VPC Core Concepts (All 13 Topics)

Each topic has: **what it is → plain-English analogy → a diagram → key rules → CLI**. Read top to bottom; later topics build on earlier ones.

> Conventions: 🛠️ run this · 💰 cost · ⚠️ gotcha · 🔒 security · 💡 tip

**Topic index:**
[1. VPC](#1-vpc) · [2. CIDR](#2-cidr) · [3. Subnets](#3-subnets) · [4. Public Subnets](#4-public-subnets) · [5. Private Subnets](#5-private-subnets) · [6. Route Tables](#6-route-tables) · [7. Internet Gateway](#7-internet-gateway-igw) · [8. NAT Gateway](#8-nat-gateway) · [9. NACL](#9-nacl-network-acl) · [10. Security Groups](#10-security-groups) · [11. VPC Peering](#11-vpc-peering) · [12. Transit Gateway](#12-transit-gateway) · [13. VPC Endpoints](#13-vpc-endpoints)

---

## 1. VPC

**What:** A **Virtual Private Cloud** is your own logically-isolated virtual network inside one AWS Region. Nothing in it is reachable from the internet (or from other VPCs) unless *you* explicitly wire it up. Every account gets a *default VPC* per Region, but real projects build *custom* VPCs.

**Analogy:** Renting an empty plot of land inside a giant gated city (the Region). The plot is yours; you decide the rooms, doors, and guards.

**Diagram:**
```
   AWS GLOBAL
   └── Region: ap-south-1 (Mumbai)
        ├── VPC-A  10.0.0.0/16   ← Project A (isolated)
        │     └── spans every AZ in the Region
        ├── VPC-B  172.16.0.0/16 ← Project B (isolated, cannot see VPC-A)
        └── Default VPC 172.31.0.0/16 (auto-created)

   A VPC is REGIONAL: it automatically spans all AZs in that Region,
   but does NOT cross Region boundaries.
```

**Key rules:**
- A VPC lives in **one Region**, spans **all AZs** in it.
- Max **5 VPCs per Region** (soft limit, raisable).
- Default tenancy is **shared** hardware; `dedicated` is available but costly.
- VPCs are **isolated by default** — no peering = no communication.

🛠️ **Create one:**
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=prod-vpc}]'
```
💡 Enable DNS hostnames so instances get resolvable names:
```bash
aws ec2 modify-vpc-attribute --vpc-id vpc-xxxx --enable-dns-hostnames
```

---

## 2. CIDR

**What:** **CIDR** (Classless Inter-Domain Routing) is the notation `10.0.0.0/16` that defines an IP range. The `/16` is the **prefix length**: how many leading bits are *fixed* (the network). The remaining bits are *host* addresses you can hand out.

**Analogy:** A phone area code. `/16` fixes a big area code (lots of numbers free); `/24` fixes more digits (fewer numbers free).

**The math (memorize this table):**
```
   /XX  →  usable size       Hosts (minus 5 AWS-reserved per subnet)
   ─────────────────────────────────────────────────────────────────
   /16  →  65,536 addresses   ← typical VPC size
   /20  →  4,096
   /24  →  256                ← typical subnet size (251 usable)
   /28  →  16  (11 usable)    ← smallest subnet AWS allows
   ─────────────────────────────────────────────────────────────────
   Rule of thumb: each +1 to the prefix HALVES the range.
   /16 = 65,536 → /17 = 32,768 → /18 = 16,384 ...
```

**Diagram — how a /16 VPC splits into /24 subnets:**
```
   VPC 10.0.0.0/16   (10.0.0.0  →  10.0.255.255 ,  65,536 IPs)
   │
   ├── 10.0.0.0/24    (10.0.0.0   → 10.0.0.255 )   256 IPs
   ├── 10.0.1.0/24    (10.0.1.0   → 10.0.1.255 )   256 IPs
   ├── 10.0.2.0/24    (10.0.2.0   → 10.0.2.255 )   256 IPs
   └── ... up to 10.0.255.0/24   → 256 subnets of /24
```

**⚠️ AWS reserves 5 IPs in every subnet.** In `10.0.1.0/24`:
```
   10.0.1.0   Network address      (reserved)
   10.0.1.1   VPC router           (reserved)
   10.0.1.2   AWS DNS (.2 = base+2)(reserved)
   10.0.1.3   Future use           (reserved)
   10.0.1.255 Broadcast            (reserved)
   → so a /24 gives 251 usable, NOT 256.
```

**Key rules:**
- Use **private ranges** (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- VPC CIDR size: between `/16` (max) and `/28` (min).
- ⚠️ **Never overlap** CIDRs you might peer/connect later — overlap makes peering impossible.
- You can add **secondary CIDR blocks** to a VPC later if you run out.

💡 Plan with room to grow: a `/16` VPC + `/24` subnets is the boring, correct default.

---

## 3. Subnets

**What:** A **subnet** is a slice of the VPC's CIDR that lives in exactly **one Availability Zone**. You place resources (EC2, RDS) into subnets. Spreading subnets across AZs is how you get **high availability**.

**Analogy:** Rooms in your building. Each room is in one wing (AZ). You put furniture (servers) in rooms, not in the building at large.

**Diagram:**
```
   VPC 10.0.0.0/16
   ├── AZ ap-south-1a
   │     ├── Subnet 10.0.1.0/24  (public)
   │     └── Subnet 10.0.2.0/24  (private)
   ├── AZ ap-south-1b
   │     ├── Subnet 10.0.3.0/24  (public)
   │     └── Subnet 10.0.4.0/24  (private)
   └── AZ ap-south-1c
         ├── Subnet 10.0.5.0/24  (public)
         └── Subnet 10.0.6.0/24  (private)

   ⚠️ A subnet CANNOT span AZs. One subnet = one AZ, always.
```

**Key rules:**
- A subnet belongs to **one AZ**; it cannot be moved.
- "Public" vs "private" is **not a setting on the subnet** — it's decided entirely by its **route table** (see Topic 6).
- Best practice: at least **2 AZs**, one public + one private subnet per AZ.

🛠️ **Create a subnet:**
```bash
aws ec2 create-subnet --vpc-id vpc-xxxx \
  --cidr-block 10.0.1.0/24 --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1a}]'
```

---

## 4. Public Subnets

**What:** A subnet is **public** when its route table has a route `0.0.0.0/0 → Internet Gateway`, AND the resource has a public/Elastic IP. That's the *only* difference from a private subnet.

**Analogy:** A room with a door opening straight onto the street.

**Diagram:**
```
   PUBLIC SUBNET  10.0.1.0/24
   ┌─────────────────────────────────────────────┐
   │  Route Table:                                │
   │     10.0.0.0/16 → local                       │
   │     0.0.0.0/0   → igw-xxxx   ◄── makes it public
   │                                               │
   │   [ EC2 with public IP 13.x.x.x ]             │
   │        ▲                                       │
   └────────┼───────────────────────────────────────┘
            │
        Internet Gateway ──► Internet
```

**What belongs in a public subnet:**
- Load balancers (ALB/NLB)
- NAT Gateways
- Bastion / jump hosts
- Rarely: a public-facing single server (small apps)

**Key rules:**
- Needs **both**: route to IGW **and** a public IP (auto-assign or Elastic IP).
- 🔒 Keep as little as possible here. App servers and databases should NOT be public.
- 🛠️ Auto-assign public IPs:
```bash
aws ec2 modify-subnet-attribute --subnet-id subnet-xxxx --map-public-ip-on-launch
```

---

## 5. Private Subnets

**What:** A subnet with **no route to an Internet Gateway**. Resources here have no public IP and cannot be reached from the internet. They reach *out* (if at all) via a **NAT Gateway**.

**Analogy:** An inner office with no street door — staff reach the outside only through the building's mailroom (NAT).

**Diagram:**
```
   PRIVATE SUBNET  10.0.2.0/24
   ┌─────────────────────────────────────────────┐
   │  Route Table:                                │
   │     10.0.0.0/16 → local                       │
   │     0.0.0.0/0   → nat-xxxx   ◄── outbound only │
   │                  (NO route to IGW)             │
   │                                               │
   │   [ App EC2  10.0.2.10 ]   no public IP        │
   │   [ RDS DB   10.0.2.20 ]   no public IP        │
   └───────────────────────────────────────────────┘
        outbound ──► NAT Gateway (in public subnet) ──► IGW ──► Internet
        inbound  ──X── blocked
```

**What belongs in a private subnet:**
- Application servers, containers (ECS/EKS)
- Databases (RDS, ElastiCache) — ideally an *isolated* private subnet with no NAT route at all
- Internal microservices

**Key rules:**
- Default = private. Only becomes "able to reach out" if you add a NAT route.
- 🔒 A **data-tier** private subnet often has **no `0.0.0.0/0` route at all** (only `local`) — maximum isolation.
- 💰 Reaching the internet from private subnets costs money (NAT Gateway hourly + data).

---

## 6. Route Tables

**What:** A set of rules that say "traffic for *this* destination goes to *that* target". Every subnet is associated with **exactly one** route table. The **main** route table is the default for any subnet you don't explicitly associate.

**Analogy:** Direction signs at a junction: "City center → straight, Highway → left".

**Diagram — the decision:**
```
   Packet to 142.250.x.x (Google)
            │
   ┌────────▼─────────────── Route Table ───────────────────┐
   │  Destination      Target        Match?                  │
   │  10.0.0.0/16  →  local          no (not in VPC)         │
   │  10.1.0.0/16  →  pcx-peer       no                      │
   │  0.0.0.0/0    →  igw-xxxx       ✅ YES (catch-all)       │
   └─────────────────────────────────────────────────────────┘
            │
            ▼  send to Internet Gateway

   LONGEST-PREFIX MATCH: the MOST SPECIFIC matching route wins.
   e.g. 10.0.5.0/24 → X  beats  10.0.0.0/16 → Y  for IP 10.0.5.9
```

**Key rules:**
- The **`local` route** (the VPC CIDR) is always present and **cannot be deleted** — it's why everything in a VPC can talk to everything else by default (subject to SG/NACL).
- **Longest-prefix match** decides ties.
- A subnet → one route table; a route table → many subnets.
- Public vs private subnet = *which target the `0.0.0.0/0` route points at* (IGW vs NAT vs none).

🛠️ **Add an internet route:**
```bash
aws ec2 create-route --route-table-id rtb-xxxx \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxxx
```

---

## 7. Internet Gateway (IGW)

**What:** A horizontally-scaled, redundant, AWS-managed component that is the **two-way door** between your VPC and the internet. It also performs the NAT for instances that have **public IPs**.

**Analogy:** The front gate of your gated plot that opens onto the public road.

**Diagram:**
```
                 Internet
                    │
            ┌───────┴────────┐
            │ Internet Gateway│  (one per VPC, AWS-managed, no bandwidth limit)
            └───────┬────────┘
                    │  attached to VPC
   ┌────────────────▼─────────────────┐
   │  VPC 10.0.0.0/16                  │
   │   Public subnet route:           │
   │      0.0.0.0/0 → igw-xxxx         │
   │   [ EC2 public IP ] ◄──► internet │
   └───────────────────────────────────┘
```

**Key rules:**
- **One IGW per VPC.** It's free; you pay only for data through it.
- Needs **3 things** for an instance to be internet-reachable: (1) IGW attached, (2) route `0.0.0.0/0 → IGW`, (3) instance has a public/Elastic IP.
- It's **highly available and unlimited bandwidth** by design — never a bottleneck.

🛠️
```bash
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --internet-gateway-id igw-xxxx --vpc-id vpc-xxxx
```

---

## 8. NAT Gateway

**What:** A managed service in a **public** subnet that lets **private** subnet resources initiate **outbound** internet connections (updates, external APIs) while blocking all **inbound** connections. It does **Source-NAT**: replaces the private source IP with its own Elastic IP.

**Analogy:** The office mailroom. Staff (private servers) can send letters out and get replies, but no stranger can walk into their office directly.

**Diagram:**
```
   PRIVATE SUBNET                PUBLIC SUBNET
   ┌──────────────┐             ┌─────────────────┐
   │ App EC2      │  outbound   │  NAT Gateway     │
   │ 10.0.2.10    │────────────►│  + Elastic IP    │──► IGW ──► Internet
   │ (no public IP)│            │  52.x.x.x        │
   └──────────────┘             └─────────────────┘
        ▲                              │
        └────── reply allowed ─────────┘ (NAT tracks the session)

   Inbound from internet ──X── NAT Gateway  ❌ (cannot start a connection in)
```

**NAT Gateway vs NAT Instance:**
```
   NAT Gateway (managed)        |  NAT Instance (DIY EC2)
   ───────────────────────────  |  ─────────────────────────────
   AWS-managed, auto-scaling    |  You manage/patch an EC2
   Up to 100 Gbps               |  Limited by instance size
   HA within an AZ              |  You build HA yourself
   No SG (uses NACL)            |  Has a security group
   💰 hourly + per-GB           |  💰 just the EC2 cost (cheaper, riskier)
   → Default choice             |  → only for tiny/cost-sensitive setups
```

**Key rules:**
- ⚠️ A NAT Gateway lives in **one AZ**. For HA, deploy **one NAT GW per AZ** and route each AZ's private subnet to its local NAT.
- 💰 NAT Gateways cost per-hour **and** per-GB — a common surprise bill. Use **VPC Endpoints** for S3/DynamoDB to avoid NAT charges.
- Requires an **Elastic IP** and must sit in a **public** subnet (route to IGW).

---

## 9. NACL (Network ACL)

**What:** A **stateless** firewall at the **subnet** boundary. It has numbered **allow and deny** rules evaluated lowest-number-first. Because it's stateless, you must explicitly allow **both** directions of a conversation.

**Analogy:** A checkpoint at the floor entrance that checks every person both entering and leaving, with a numbered rulebook.

**Diagram:**
```
   SUBNET 10.0.1.0/24   ── guarded by NACL ──
   ┌──────────────────────────────────────────────────────┐
   │  INBOUND rules (evaluated by # ascending):            │
   │   #100  allow TCP 443  from 0.0.0.0/0   ✅             │
   │   #200  allow TCP 1024-65535 from 0.0.0.0/0 (returns)  │
   │   #*    DENY all                         (implicit)    │
   │                                                        │
   │  OUTBOUND rules:                                       │
   │   #100  allow TCP 1024-65535 to 0.0.0.0/0 (returns)    │
   │   #200  allow TCP 443 to 0.0.0.0/0                     │
   │   #*    DENY all                                       │
   └──────────────────────────────────────────────────────┘
   ⚠️ Stateless: an inbound 443 reply leaves on an EPHEMERAL port,
      so you MUST also allow outbound 1024-65535. Forget this = broken.
```

**Key rules:**
- **Stateless** — return traffic is NOT automatic. Allow ephemeral ports `1024-65535` for replies.
- Has **both allow and deny** rules (unlike SGs). Use deny to block a specific bad IP.
- Rules evaluated **in number order**, first match wins, then implicit `* DENY`.
- Applies to the **whole subnet** (all instances in it).
- Default NACL **allows all**; custom NACL **denies all** until you add rules.

🔒 Use NACLs as a **coarse backstop** (e.g. block a known-bad CIDR for an entire subnet). Use Security Groups for the real per-app rules.

---

## 10. Security Groups

**What:** A **stateful** firewall at the **instance/ENI** level. **Allow-only** (no deny rules). Because it's stateful, if you allow an inbound request, the response is automatically allowed out (and vice-versa).

**Analogy:** A personal bodyguard for each server who remembers "this guest is expected" and lets their reply pass without a second check.

**Diagram:**
```
   [ App EC2 ]  protected by  SG "app-sg"
   ┌─────────────────────────────────────────────────────┐
   │  INBOUND (allow-only):                                │
   │    TCP 8080  from  sg-alb   ◄── reference another SG!  │
   │    TCP 22    from  10.0.0.0/16 (internal SSH)          │
   │  OUTBOUND:                                             │
   │    ALL        to   0.0.0.0/0  (default)                │
   │                                                        │
   │  Stateful → a reply to an allowed request is           │
   │  automatically permitted. No return rule needed.       │
   └─────────────────────────────────────────────────────┘
```

**The killer feature — SG referencing (chaining):**
```
   Internet ──► sg-alb (allow 443 from 0.0.0.0/0)
                   │  "allow from sg-alb"
   ALB ─────────► sg-app (allow 8080 from sg-alb ONLY)
                   │  "allow from sg-app"
   App ─────────► sg-db (allow 3306 from sg-app ONLY)
   → No IP addresses hard-coded. Scales automatically as instances come/go.
```

**SG vs NACL (the classic interview table):**
```
                    Security Group        |   NACL
   ──────────────────────────────────────────────────────────────
   Level            Instance / ENI        |   Subnet
   State            Stateful (returns auto)|   Stateless (manual)
   Rules            Allow only            |   Allow + Deny
   Evaluation       All rules (OR)        |   Numbered, first match
   Default custom   Deny all inbound      |   Deny all (custom)
   Can reference    Other SGs ✅          |   CIDR only
   Applies to       Resources you attach  |   Everything in subnet
```

**Key rules:**
- **Stateful, allow-only.** Default SG denies inbound, allows all outbound.
- ⚠️ You can't write a "deny" in an SG. To block, use a NACL or just don't allow it.
- 💡 Reference SGs by ID, not IP, so rules survive auto-scaling.

🛠️
```bash
aws ec2 authorize-security-group-ingress --group-id sg-app \
  --protocol tcp --port 8080 --source-group sg-alb
```

---

## 11. VPC Peering

**What:** A **private, 1:1 network connection** between two VPCs (same or different account/Region) so resources talk using private IPs as if on one network. Traffic stays on the AWS backbone (never the internet).

**Analogy:** A private hallway you build between two adjacent houses. Only those two houses share it.

**Diagram:**
```
   VPC-A 10.0.0.0/16                    VPC-B 172.16.0.0/16
   ┌──────────────────┐  pcx-1234  ┌──────────────────┐
   │ App  10.0.1.10   │◄══════════►│ DB  172.16.1.20  │
   └──────────────────┘            └──────────────────┘
   Route in A:  172.16.0.0/16 → pcx-1234
   Route in B:  10.0.0.0/16   → pcx-1234
   (you must add routes on BOTH sides)

   ⚠️ NOT TRANSITIVE:
        A ── peer ── B ── peer ── C
        A canNOT reach C through B. Need a direct A–C peering.
```

**Key rules:**
- ⚠️ **No transitive peering** — A↔B and B↔C does not give A↔C.
- ⚠️ CIDRs **must not overlap**.
- Must add **routes on both VPCs** + allow traffic in SGs/NACLs.
- Works **cross-Region** and **cross-account**.
- 💡 Great for a *few* VPCs. For *many*, peering becomes a mesh nightmare (N·(N-1)/2 links) → use a **Transit Gateway** instead.

---

## 12. Transit Gateway

**What:** A regional **cloud router** that connects **many VPCs and on-premises networks** in a **hub-and-spoke** topology. One attachment per VPC instead of a full mesh of peerings. Supports **transitive** routing through TGW route tables.

**Analogy:** A central airport hub. Instead of a direct flight between every pair of cities (mesh), everyone connects through the hub.

**Diagram — mesh vs hub:**
```
   WITHOUT TGW (peering mesh, 5 VPCs = 10 links):     WITH TGW (5 links):
        A───B                                              A   B
        │╲ ╱│                                               ╲ ╱
        │ ╳ │                                          C ──[ TGW ]── D
        │╱ ╲│                                               ╱ ╲
        C───D ── E ...                                     E   (on-prem)
       (unmanageable)                                  (clean hub-and-spoke)
```

```
                 On-Prem DC
              (VPN / Direct Connect)
                      │
         ┌──────── TRANSIT GATEWAY ────────┐
         │   TGW Route Tables decide        │
         │   who can reach whom             │
         └──┬────────┬────────┬─────────────┘
       attach    attach    attach
        ┌─▼─┐    ┌─▼─┐    ┌──▼──┐
        │VPC│    │VPC│    │ VPC │
        │Prod│   │Dev│    │Shared│
        └───┘    └───┘    └─────┘
   Example policy: Prod↔Shared ✅,  Dev↔Shared ✅,  Dev↔Prod ❌ (route isolation)
```

**Key rules:**
- Solves peering's mesh explosion and **lack of transitivity**.
- **TGW route tables** segment traffic (e.g. isolate Dev from Prod).
- Connects VPCs, **VPN**, and **Direct Connect** in one place.
- 💰 Pay per-attachment-hour **and** per-GB processed.
- Regional; connect across Regions with **TGW peering**.

---

## 13. VPC Endpoints

**What:** A **private** entry point that lets resources in your VPC reach **AWS services** (S3, DynamoDB, SQS, etc.) **without** going over the internet, an IGW, or a NAT Gateway. Two types:

```
   GATEWAY ENDPOINT                 |  INTERFACE ENDPOINT (PrivateLink)
   ───────────────────────────────  |  ──────────────────────────────────
   For: S3 and DynamoDB ONLY        |  For: most other AWS services + SaaS
   How: a route-table entry         |  How: an ENI (private IP) in your subnet
        (prefix list → endpoint)    |       resolved via private DNS
   Cost: FREE 💰                    |  💰 hourly per-AZ + per-GB
   Scope: route table               |  Scope: security group on the ENI
```

**Analogy:** A private service tunnel from your building straight to the post office — no need to step onto the public street.

**Diagram:**
```
   WITHOUT endpoint (costs NAT $$ + leaves AWS edge):
     Private EC2 ──► NAT GW ──► IGW ──► Internet ──► S3

   WITH Gateway Endpoint (private, free):
   ┌──────────── VPC ────────────────┐
   │  Private subnet                  │
   │   [ EC2 10.0.2.10 ]              │
   │        │ route: pl-S3 → vpce-s3  │
   │        ▼                         │
   │   [ S3 Gateway Endpoint ]────────┼──► Amazon S3 (private, on AWS backbone)
   └──────────────────────────────────┘

   WITH Interface Endpoint (PrivateLink):
   │   [ EC2 ] ──► ENI 10.0.2.50 (vpce) ──► AWS service (e.g. SSM, ECR, SQS)
```

**Key rules:**
- 🔒 Keeps traffic to AWS services **entirely private** — never touches the internet.
- 💰 **Gateway endpoints (S3/DynamoDB) are FREE** and cut NAT data costs — almost always worth adding.
- Interface endpoints cost per-hour/per-GB but enable private access to ~100 services + your own/partner services via **PrivateLink**.
- Control access with **endpoint policies** (gateway) or **security groups** (interface).

🛠️ **Create an S3 gateway endpoint:**
```bash
aws ec2 create-vpc-endpoint --vpc-id vpc-xxxx \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids rtb-private
```

---

## ✅ Module 1 Recap — the whole picture in one diagram

```
                         Internet
                            │
                     [ Internet Gateway ]
                            │ route 0.0.0.0/0
   ┌──────────────── VPC 10.0.0.0/16 ───────────────────┐
   │  PUBLIC SUBNET 10.0.1.0/24  (NACL #100…)            │
   │    [ ALB ]   [ NAT GW + EIP ]   [ Bastion ]         │
   │      │  SG: 443 from world         │                │
   │  ────┼─────────────────────────────┼──────────────  │
   │  PRIVATE SUBNET 10.0.2.0/24         │ outbound       │
   │    [ App EC2 ] SG: 8080 from ALB SG ┘                │
   │      │ route 0.0.0.0/0 → NAT                          │
   │  ─────────────────────────────────────────────────   │
   │  ISOLATED SUBNET 10.0.3.0/24 (no internet route)     │
   │    [ RDS ] SG: 3306 from App SG only                 │
   │                                                      │
   │  [ S3 Gateway Endpoint ] ──► S3 (free, private)       │
   └───────┬──────────────────────────────────────────────┘
           │ pcx / TGW
      other VPCs / on-prem
```

**Next:** [02-architectures.md](02-architectures.md) — production, multi-tier, and enterprise designs in depth.

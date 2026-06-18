# Phase 04 — Amazon VPC Complete Learning Repository

> A hands-on, architecture-focused course on **Amazon VPC (Virtual Private Cloud)** — from "what is a network?" to designing **multi-tier, production, and enterprise** cloud networks with subnets, routing, gateways, firewalls, peering, Transit Gateway, and private endpoints.

Authored as a structured program by an **AWS Networking Architect**. Builds on [Phase 01 — AWS Fundamentals](../01-aws-fundamentals/README.md), [Phase 03 — EC2](../03-ec2/README.md), and [Phase 05 — S3](../05-s3/README.md). Every topic has a plain-English explanation, an ASCII diagram, real CLI, and practice.

---

## 🎯 Who This Is For
- Anyone who can launch an EC2 instance but doesn't fully understand **how packets actually move**.
- Developers and DevOps engineers who keep hitting "it can't reach the internet / database" issues.
- Candidates preparing for **AWS Solutions Architect / SysOps / Advanced Networking** and infra interviews.

**Prerequisites:** An AWS account with MFA + a billing budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Comfort launching an EC2 instance ([Phase 03](../03-ec2/README.md)) helps a lot.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file — beginner network theory + all flows + 3 architectures) | [README.md](README.md) | 45 min |
| 1 | VPC Core Concepts (all 13 topics, each with a diagram) | [01-vpc-core-concepts.md](01-vpc-core-concepts.md) | 5 hrs |
| 2 | Architectures (Multi-tier · Production · Enterprise) | [02-architectures.md](02-architectures.md) | 2 hrs |
| 3 | Cost Optimization | [03-cost-optimization.md](03-cost-optimization.md) | 1 hr |
| 4 | Security Guide | [04-security-guide.md](04-security-guide.md) | 1.5 hrs |
| 5 | Troubleshooting Guide | [05-troubleshooting.md](05-troubleshooting.md) | 1.5 hrs |
| 6 | Hands-on Labs | [06-labs.md](06-labs.md) | 5 hrs |
| 7 | 100 MCQs | [07-100-mcqs.md](07-100-mcqs.md) | 2 hrs |
| 8 | 100 Interview Questions | [08-100-interview-questions.md](08-100-interview-questions.md) | 3 hrs |
| 9 | 50 Scenario Questions | [09-50-scenario-questions.md](09-50-scenario-questions.md) | 2 hrs |
| 10 | Cheat Sheet (1-page revision) | [10-cheatsheet.md](10-cheatsheet.md) | 30 min |
| 11 | **Capstone Project:** Production 3-tier VPC in Terraform | [project/README.md](project/README.md) | 4+ hrs |

**Total:** ~27 hours.

---

## 📚 Topics Covered (Module 1)

| # | Topic | One-liner |
|---|-------|-----------|
| 1 | **VPC** | Your own logically-isolated virtual network inside an AWS Region |
| 2 | **CIDR** | The notation (e.g. `10.0.0.0/16`) that defines the IP address range |
| 3 | **Subnets** | Slices of the VPC's CIDR, each pinned to one Availability Zone |
| 4 | **Public Subnets** | A subnet whose route table sends `0.0.0.0/0` to an Internet Gateway |
| 5 | **Private Subnets** | A subnet with no direct route to the internet |
| 6 | **Route Tables** | The rules that decide where a packet goes next |
| 7 | **Internet Gateway (IGW)** | Two-way door between the VPC and the internet |
| 8 | **NAT Gateway** | Lets private subnets reach **out** to the internet, but not in |
| 9 | **NACL** | Stateless, subnet-level firewall (allow + deny rules) |
| 10 | **Security Groups** | Stateful, instance-level firewall (allow-only rules) |
| 11 | **VPC Peering** | A private 1:1 link between two VPCs |
| 12 | **Transit Gateway** | A cloud router that connects many VPCs + on-prem in a hub-and-spoke |
| 13 | **VPC Endpoints** | Private access to AWS services (S3, etc.) without the internet |

---

## 🧒 Beginner Network Explanation (read this first)

Forget the cloud for a second. Think about your **home**.

```
   YOUR HOME NETWORK                              THE INTERNET
   ─────────────────                              ────────────
                                                       │
   [Laptop] [Phone] [TV]                               │
       │       │      │                                │
       └───────┴──────┘                                │
              │                                        │
        [ Wi-Fi Router ]  ── public IP ──────────────► │
              │
       Private IPs: 192.168.0.x
```

- Every device gets a **private IP** (`192.168.0.10`, `192.168.0.11`…). These only mean something *inside your house*.
- Your **router** has ONE **public IP** given by your ISP. The whole internet sees only that.
- When your laptop loads a website, the router does **NAT** (Network Address Translation): it swaps your private IP for the public one on the way out, remembers the swap, and swaps it back on the reply.
- A **firewall** decides what traffic is allowed in/out.

**A VPC is exactly this, but software-defined inside AWS.** Map it 1:1:

| Home concept | AWS VPC concept |
|--------------|-----------------|
| Your house (the whole network) | **VPC** |
| Range of allowed addresses (192.168.0.0/24) | **CIDR block** |
| Rooms that group devices | **Subnets** |
| Room facing the street | **Public subnet** |
| Inner room, no street access | **Private subnet** |
| "To reach the street, use the front door" sign | **Route table** |
| Front door to the street | **Internet Gateway** |
| Router doing address translation for outgoing traffic | **NAT Gateway** |
| Security guard at the room door (per device) | **Security Group** |
| Security checkpoint at the building floor (per subnet) | **NACL** |
| A private hallway connecting two houses | **VPC Peering** |
| The building's central elevator/corridor system | **Transit Gateway** |
| A private service tunnel to the post office | **VPC Endpoint** |

If you understand the house, you already understand 80% of VPC. The rest is detail and IP math.

---

## ⚡ VPC Mental Model (60-second overview)

```
   AWS REGION (e.g. ap-south-1)
   └── VPC  10.0.0.0/16        ← your private network (65,536 IPs)
        │   ├── Internet Gateway (IGW)        ── door to the internet
        │   ├── Route Tables                  ── "where does this packet go?"
        │   ├── NACLs                         ── stateless subnet firewall
        │   │
        │   ├── Availability Zone A ──────────────────────────────┐
        │   │     ├── Public Subnet  10.0.1.0/24  → route to IGW   │
        │   │     │      ├── [ NAT Gateway ]                       │
        │   │     │      └── [ Load Balancer ]                     │
        │   │     └── Private Subnet 10.0.2.0/24  → route to NAT   │
        │   │            ├── [ App EC2 ]  ← Security Group         │
        │   │            └── [ RDS DB  ]  ← Security Group         │
        │   │                                                      │
        │   └── Availability Zone B (mirror of A, for HA) ─────────┘
        │
        ├── VPC Endpoint  → private path to S3 / DynamoDB
        ├── VPC Peering   → private link to another VPC
        └── Transit Gateway → hub connecting many VPCs + on-prem
```

**In words:** A **VPC** is your private slice of the AWS network, sized by a **CIDR** block. You carve it into **subnets** (one per AZ). A subnet is **public** if its **route table** points internet traffic at an **Internet Gateway**; otherwise it's **private**. Private resources reach out through a **NAT Gateway**. Traffic is filtered by **NACLs** (subnet, stateless) and **Security Groups** (instance, stateful). You connect VPCs with **Peering** or a **Transit Gateway**, and reach AWS services privately with **VPC Endpoints**.

---

## 🌐 The Three Flows (how traffic actually moves)

### 1. Packet Flow — the lowest level (where a single packet is checked)

Every packet leaving or entering an instance passes a fixed gauntlet. **Order matters.**

```
  OUTBOUND from an EC2 instance
  ┌──────────┐   ┌───────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────┐
  │ EC2 ENI  │──►│ Security Group│──►│ Subnet Route  │──►│ NACL          │──►│ IGW/NAT  │──► dest
  │ (sends)  │   │ (stateful,    │   │ Table         │   │ (stateless,   │   │ Endpoint │
  │          │   │  egress rule) │   │ (longest-prefix│   │  egress rule) │   │          │
  └──────────┘   └───────────────┘   │  match)       │   └──────────────┘   └──────────┘
                                      └──────────────┘

  INBOUND to an EC2 instance (reverse, with one twist)
  dest ◄── IGW/NAT ◄── NACL (ingress) ◄── Route Table ◄── Security Group (ingress) ◄── EC2 ENI
                       └─ stateless: you must                └─ stateful: if the instance
                          allow the RETURN traffic too          started the connection, the
                          (ephemeral ports 1024-65535)          reply is auto-allowed
```

**Key rules to memorize:**
- **Security Group = stateful.** Allow inbound 443 → the reply leaves automatically. You don't write a return rule.
- **NACL = stateless.** Allow inbound 443 → you ALSO need an outbound rule for ephemeral ports `1024-65535` (and vice-versa). This is the #1 NACL gotcha.
- **Route table** is evaluated by **longest-prefix match** (most specific route wins). `local` route (the VPC CIDR) can never be removed and always wins for in-VPC traffic.
- **Security Groups only ALLOW.** **NACLs allow AND deny**, evaluated by rule number (lowest first).

### 2. Request Flow — a user loading your web app (end to end)

```
  [ User Browser ]
        │  (1) DNS: app.example.com → 52.x.x.x  (Route 53)
        ▼
  [ Internet ]
        │  (2) HTTPS to the public IP
        ▼
  ┌──────────────────────── VPC 10.0.0.0/16 ───────────────────────────┐
  │  Internet Gateway                                                   │
  │        │ (3) route 0.0.0.0/0 → IGW                                  │
  │        ▼                                                            │
  │  PUBLIC SUBNET                                                      │
  │   [ Application Load Balancer ]  ← SG: allow 443 from 0.0.0.0/0     │
  │        │ (4) forwards to a healthy target                          │
  │        ▼                                                            │
  │  PRIVATE SUBNET (app tier)                                         │
  │   [ App EC2 ]  ← SG: allow 8080 ONLY from the ALB's SG             │
  │        │ (5) query                                                 │
  │        ▼                                                            │
  │  PRIVATE SUBNET (data tier)                                        │
  │   [ RDS / MySQL ]  ← SG: allow 3306 ONLY from the App SG           │
  └────────────────────────────────────────────────────────────────────┘
        │ (6) reply walks back the SAME path (stateful SGs allow returns)
        ▼
  [ User sees the page ]
```
Notice the **security group chaining**: the ALB allows the world, the app allows only the ALB, the DB allows only the app. Each tier trusts only the one in front of it — this is **defense in depth**.

### 3. Internet Flow — public IN vs. private OUT (the most-confused topic)

```
  PUBLIC INSTANCE  (has a public IP, in a public subnet)
  ────────────────────────────────────────────────────────
     Inbound  : Internet ──► IGW ──► instance   ✅ (two-way door)
     Outbound : instance  ──► IGW ──► Internet   ✅
     Requirement: public/Elastic IP + route 0.0.0.0/0 → IGW

  PRIVATE INSTANCE going OUT (e.g. OS updates, calling an API)
  ────────────────────────────────────────────────────────
     Outbound : instance ──► NAT Gateway ──► IGW ──► Internet  ✅
     Inbound  : Internet ──X── NAT Gateway                     ❌ blocked
     Why: NAT does Source-NAT — it remembers outbound sessions and only
          lets the matching reply back in. Nobody can START a connection in.

  PRIVATE INSTANCE reaching an AWS SERVICE (S3, DynamoDB)
  ────────────────────────────────────────────────────────
     Best path: instance ──► VPC Endpoint ──► S3   ✅ (never touches internet)
     Cheaper + safer than routing through a NAT Gateway.
```

**The golden rule:**
- Need to be reachable FROM the internet → **public subnet + IGW + public IP**.
- Need to reach OUT to the internet only → **private subnet + NAT Gateway**.
- Need to reach AWS services only → **VPC Endpoint** (no IGW, no NAT).

---

## 🏗️ Architecture Previews (full versions in [Module 2](02-architectures.md))

### Production Architecture (single-region, highly available)

```
                          Internet
                             │
                       Route 53 (DNS)
                             │
   ┌──────────────────── VPC 10.0.0.0/16 (Region) ────────────────────┐
   │                     Internet Gateway                              │
   │            ┌─────────────────┴─────────────────┐                 │
   │       AZ-A │                                    │ AZ-B           │
   │   ┌────────▼─────────┐              ┌───────────▼────────┐        │
   │   │ Public Subnet    │              │ Public Subnet      │        │
   │   │  ALB node        │◄──── ALB ───►│  ALB node          │        │
   │   │  NAT GW (A)       │              │  NAT GW (B)        │        │
   │   └────────┬─────────┘              └───────────┬────────┘        │
   │   ┌────────▼─────────┐              ┌───────────▼────────┐        │
   │   │ Private (app)    │  Auto Scaling│ Private (app)      │        │
   │   │  App EC2 ×N      │◄────group───►│  App EC2 ×N        │        │
   │   └────────┬─────────┘              └───────────┬────────┘        │
   │   ┌────────▼─────────┐              ┌───────────▼────────┐        │
   │   │ Private (data)   │  RDS Multi-AZ│ Private (data)     │        │
   │   │  RDS primary     │◄──replicate─►│  RDS standby       │        │
   │   └──────────────────┘              └────────────────────┘        │
   │   VPC Endpoint ──► S3 / DynamoDB (private)                        │
   └───────────────────────────────────────────────────────────────────┘
```

### Multi-Tier Architecture (the classic 3-tier)

```
   ┌──────────── TIER 1: WEB / PUBLIC ────────────┐  Public subnet
   │  ALB  ·  CloudFront  ·  (optional bastion)    │  Route → IGW
   └───────────────────┬───────────────────────────┘
                       │  SG: app allows only ALB SG
   ┌───────────────────▼───── TIER 2: APP ─────────┐  Private subnet
   │  EC2 / ECS / Lambda  ·  Auto Scaling Group     │  Route → NAT
   └───────────────────┬───────────────────────────┘
                       │  SG: db allows only app SG
   ┌───────────────────▼───── TIER 3: DATA ────────┐  Private (isolated)
   │  RDS  ·  ElastiCache  ·  no internet route      │  Route → local only
   └────────────────────────────────────────────────┘
```

### Enterprise Architecture (many VPCs + on-prem, hub-and-spoke)

```
        On-Premises DC                       Internet Egress (central)
            │ VPN / Direct Connect                    │
            ▼                                          ▼
   ┌───────────────────────── TRANSIT GATEWAY (hub) ─────────────────────────┐
   └───┬──────────────┬──────────────┬──────────────┬───────────────┬────────┘
       │              │              │              │               │
   ┌───▼───┐     ┌────▼────┐    ┌────▼────┐    ┌────▼─────┐    ┌─────▼──────┐
   │ Prod  │     │ Dev     │    │ Shared  │    │ Security │    │ Egress     │
   │ VPC   │     │ VPC     │    │ Services│    │ /Inspect │    │ VPC (NAT)  │
   │       │     │         │    │ VPC     │    │ VPC      │    │            │
   └───────┘     └─────────┘    └─────────┘    └──────────┘    └────────────┘
```
Each "spoke" VPC has its own subnets/SGs; the **Transit Gateway** is the central router. Route tables on the TGW control who can talk to whom (e.g. Dev cannot reach Prod).

---

## 🔑 VPC in One Line per Topic (cheat sheet)

| Topic | One-liner | Scope | Stateful? |
|-------|-----------|-------|-----------|
| **VPC** | Isolated virtual network in a Region | Region | — |
| **CIDR** | IP range notation `/16`, `/24`… | VPC/Subnet | — |
| **Subnet** | CIDR slice pinned to one AZ | AZ | — |
| **Route Table** | Decides next hop (longest-prefix wins) | Subnet | — |
| **IGW** | Two-way internet door | VPC | — |
| **NAT Gateway** | Outbound-only internet for private subnets | Subnet/AZ | yes (tracks sessions) |
| **NACL** | Subnet firewall, allow+deny, numbered rules | Subnet | **no** |
| **Security Group** | Instance firewall, allow-only | ENI/Instance | **yes** |
| **VPC Peering** | Private 1:1 VPC link (no transitive routing) | 2 VPCs | — |
| **Transit Gateway** | Hub router for many VPCs + on-prem | Region/global | — |
| **VPC Endpoint** | Private access to AWS services | VPC | — |

---

## 📌 Conventions
- 🛠️ = run this · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- CIDR examples use `10.0.0.0/16` as the standard VPC; CLI examples use AWS CLI v2.
- `→` in a route means "send matching traffic to this target".

---

## 📖 Official References
- VPC docs: https://docs.aws.amazon.com/vpc/
- VPC pricing (NAT, endpoints, TGW): https://aws.amazon.com/vpc/pricing/
- VPC security best practices: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html
- Subnet/CIDR sizing: https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html
- Transit Gateway: https://docs.aws.amazon.com/vpc/latest/tgw/

---

*Start with [01-vpc-core-concepts.md](01-vpc-core-concepts.md).* 🚀

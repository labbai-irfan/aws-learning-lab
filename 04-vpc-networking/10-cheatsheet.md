# 10 — VPC & Networking Cheat Sheet (1-Page Revision)

> Last-minute revision. Pair with [01 — Core Concepts](01-vpc-core-concepts.md).

## Building blocks
| Thing | One-liner |
|---|---|
| **VPC** | Your isolated virtual network (a CIDR block, e.g. `10.0.0.0/16`) — Regional |
| **Subnet** | A slice of the VPC CIDR in **one AZ** |
| **Route table** | Rules deciding where subnet traffic goes |
| **Internet Gateway (IGW)** | VPC's door to the internet (for public subnets) |
| **NAT Gateway** | Lets **private** subnets reach the internet outbound only |
| **Security Group** | Stateful, instance-level firewall (allow-only) |
| **NACL** | Stateless, subnet-level firewall (allow + deny, ordered) |
| **ENI** | A virtual network card attached to an instance/task |

## Public vs private subnet
```
PUBLIC  subnet → route 0.0.0.0/0 → IGW   (has public IPs: ALB, NAT, bastion)
PRIVATE subnet → route 0.0.0.0/0 → NAT   (app servers, RDS, ECS tasks)
```
💡 "Public" = has a route to the IGW. Nothing else.

## CIDR / IP math
- VPC: `/16` = 65,536 IPs. Subnet `/24` = 256 (AWS reserves **5** per subnet → 251 usable).
- Subnets can't overlap; plan ≥2 AZs (≥2 public + ≥2 private) for HA.
- Smaller prefix number = bigger network (`/16` > `/24`).

## SG vs NACL (the classic)
| | Security Group | NACL |
|---|---|---|
| Level | Instance/ENI | Subnet |
| State | **Stateful** | **Stateless** |
| Rules | Allow only | Allow **and** Deny |
| Eval | All rules | Rules in number order, first match |
| Default | Deny inbound / allow outbound | Default NACL allows all |

## Connectivity options
| Need | Use |
|---|---|
| VPC ↔ VPC (private) | **VPC Peering** (no transitive) |
| Many VPCs/on-prem hub | **Transit Gateway** |
| Private to AWS service (S3/DynamoDB) | **Gateway Endpoint** (free) |
| Private to other AWS services/PrivateLink | **Interface Endpoint** (ENI, ~$/hr) |
| On-prem ↔ AWS encrypted | **Site-to-Site VPN** |
| On-prem ↔ AWS dedicated | **Direct Connect** |
| Expose your service to other VPCs | **PrivateLink** |

## NAT options
- **NAT Gateway** = managed, HA per AZ, scales, ~$32/mo + data. (One per AZ for HA.)
- **NAT Instance** = legacy DIY on EC2 (cheaper, you manage). Prefer NAT Gateway.
- 💰 NAT data processing adds up — use **Gateway Endpoints** for S3/DynamoDB to bypass NAT.

## Observability & security
- **VPC Flow Logs** → capture accepted/rejected traffic to CloudWatch/S3 (security forensics).
- Defense in depth: NACL (subnet) + SG (instance) + private subnets + endpoints.

## Exam triggers 💡
- "Private subnet needs outbound internet" → **NAT Gateway**.
- "Private access to S3 without NAT/IGW" → **S3 Gateway Endpoint** (free).
- "Connect 3+ VPCs + on-prem centrally" → **Transit Gateway** (peering isn't transitive).
- "Block a specific IP range at subnet edge" → **NACL deny** (SGs can't deny).
- "RDS must not be internet-reachable" → **private subnets + SG from app only**.

## Gotchas ⚠️
- VPC peering is **not transitive** and CIDRs must not overlap.
- NACLs are stateless → you must allow **ephemeral return ports** (1024–65535).
- A subnet maps to exactly **one AZ**; "Multi-AZ" = multiple subnets.
- IGW alone doesn't make a subnet public — you also need the route + a public IP.

---
*Back to [VPC & Networking README](README.md).*

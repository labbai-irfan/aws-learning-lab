# Module 2 — Complete EC2 Architecture

> How all the EC2 pieces fit together, from a single instance to a production, highly-available, auto-scaled deployment. All ASCII so it renders anywhere.

---

## 1. Anatomy of a Single EC2 Instance

```
                         +-------------------------------+
   Key Pair (SSH) ─────► |                               |
                         |        EC2 INSTANCE           |
   User Data (boot) ───► |  AMI: Amazon Linux 2023       |
                         |  Type: t3.micro (2 vCPU/1GB)  |
   IAM Role (creds) ───► |  Hostname / Metadata          |
                         |                               |
                         |  +-------------------------+  |
                         |  | Root EBS volume (gp3)   |  |
                         |  +-------------------------+  |
                         |  | Data EBS volume (gp3)   |  |
                         |  +-------------------------+  |
                         +-------------------------------+
                            │            │            │
                   Security Group   Elastic IP   ENI (network
                   (firewall)       (static IP)   interface)
```

**Flow:** The AMI defines the disk image → launched as an instance of a chosen type → key pair enables SSH → user data bootstraps it → EBS provides persistent disks → an ENI connects it to the VPC → a security group filters traffic → an optional Elastic IP gives it a stable public address → an IAM role gives it AWS permissions without stored keys.

---

## 2. EC2 Inside the VPC / Network Layers

```
   REGION (ap-south-1)
   +-----------------------------------------------------------------+
   |  VPC  10.0.0.0/16                                                |
   |                                                                 |
   |   Internet Gateway (IGW)                                        |
   |        │                                                        |
   |   +----┴-------------------+     +-------------------------+    |
   |   | PUBLIC SUBNET (AZ-a)   |     | PRIVATE SUBNET (AZ-a)   |    |
   |   | 10.0.1.0/24            |     | 10.0.2.0/24             |    |
   |   |  [EC2 web] + EIP       |     |  [EC2 app] / [RDS]      |    |
   |   |  SG: 80,443,22         |     |  SG: 3306 from web SG   |    |
   |   +-----------┬------------+     +------------┬------------+    |
   |               │  (NAT Gateway for egress)     │                |
   |               └──────────────►NAT─────────────┘                |
   +-----------------------------------------------------------------+
        Route table: public subnet → IGW; private subnet → NAT
```

**Key ideas:**
- **Public subnet** (route to Internet Gateway) hosts internet-facing instances.
- **Private subnet** (no direct internet) hosts databases/internal app tiers; outbound via **NAT Gateway**.
- Security groups restrict traffic per tier (web → app → db).

---

## 3. Highly Available, Auto-Scaled Production Architecture

```
                         Users (Internet)
                              │
                       Route 53 (DNS, your domain)
                              │
                       CloudFront (optional CDN/edge cache)
                              │
                  Application Load Balancer (ALB)  :443/:80
                  (spans multiple AZs, health checks)
                              │
        ┌─────────────────────┴─────────────────────┐
      AZ-a                                          AZ-b
   PUBLIC SUBNET                                 PUBLIC SUBNET
   ┌───────────────┐                            ┌───────────────┐
   │ EC2 (web/app) │   ◄── Auto Scaling Group ──►│ EC2 (web/app) │
   └───────┬───────┘     (Launch Template,        └───────┬───────┘
           │              min2/desired2/max6)             │
   PRIVATE SUBNET                                 PRIVATE SUBNET
   ┌───────────────┐                            ┌───────────────┐
   │ RDS MySQL     │  ◄──── Multi-AZ standby ───►│ RDS (standby) │
   │ (primary)     │                            └───────────────┘
   └───────────────┘
           │
        S3 (static assets, backups)   CloudWatch (metrics, alarms, logs)
```

**Why this design:**
- **Route 53** resolves the domain; **CloudFront** caches static content at the edge.
- **ALB** distributes traffic across healthy instances in **multiple AZs** and does TLS termination.
- **Auto Scaling Group** keeps the right number of instances and self-heals.
- **RDS Multi-AZ** gives database high availability with automatic failover.
- **CloudWatch** monitors and triggers scaling/alarms.
- Survives an instance failure **and** a full AZ failure with no downtime.

---

## 4. Request Flow (end to end)

```
1. User types https://app.example.com
2. Route 53 resolves to the ALB (or CloudFront → ALB)
3. ALB terminates TLS, picks a healthy EC2 target (round-robin/least-conn)
4. Nginx on EC2 serves the React build for "/" and reverse-proxies "/api" to Node (PM2) :5000
5. Node app queries RDS MySQL (private subnet, port 3306)
6. Response travels back: Node → Nginx → ALB → user
7. CloudWatch records latency/CPU; ASG scales out if CPU target exceeded
```

---

## 5. Single-Instance Full-Stack Layout (the capstone deploys this)

```
   Internet ──► Security Group (22 from me, 80/443 from all)
                       │
              ┌────────┴───────── EC2 (t3.small, Ubuntu/Amazon Linux) ─────────┐
              │  Nginx :80/:443  (Let's Encrypt SSL)                            │
              │   ├── "/"     → serves React static build (/var/www/app)        │
              │   └── "/api"  → reverse proxy → Node.js (PM2) 127.0.0.1:5000    │
              │                                                                 │
              │  MySQL :3306 (localhost)  ◄── Node connects here                │
              │  EBS gp3 root volume (app code, build, db data)                 │
              └─────────────────────────────────────────────────────────────────┘
```
> Simple, low-cost, great for learning. The HA architecture (section 3) is the production evolution.

---

## 6. Scaling Evolution (how an app grows)

```
Stage 1: ONE BOX            Stage 2: SPLIT TIERS        Stage 3: HA + SCALE
+-----------------+         +--------+  +---------+      ALB ─► ASG(web) across AZs
| Nginx+Node+MySQL|   ──►   | EC2 app|  | RDS DB  |  ──► RDS Multi-AZ + CloudFront + S3
| on one EC2      |         +--------+  +---------+      + CloudWatch + Auto Scaling
+-----------------+         (DB managed)                 (self-healing, elastic)
   cheapest                 more reliable                production-grade
```

---

## 7. Where Each Module 1 Concept Appears

| Concept | Role in architecture |
|---------|----------------------|
| AMI | Image the ASG launches |
| Instance Type | Sizing each EC2 box |
| Launch Template | Blueprint for ASG instances |
| Security Group | Per-tier firewall (web/app/db) |
| Key Pair / SSH | Admin access to instances |
| Elastic IP | Stable IP for single-box / NAT |
| EBS | Persistent disk + snapshots/backups |
| Auto Scaling | Elasticity + self-healing |
| Placement Group | Performance/availability of fleets |
| User Data | Bootstrap each instance at boot |

---

➡️ Next: [03-instance-selection-guide.md](03-instance-selection-guide.md)

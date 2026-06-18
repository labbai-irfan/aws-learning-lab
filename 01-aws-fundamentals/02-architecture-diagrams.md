# Module 2 — Architecture Diagrams

> Visual reference for every core concept. All diagrams are ASCII so they render anywhere (GitHub, terminal, notes). Use them to "see" how the pieces fit.

## Index
1. Cloud service models (IaaS/PaaS/SaaS)
2. Deployment models (Public/Private/Hybrid)
3. AWS Global Infrastructure hierarchy
4. Region & Availability Zones
5. Edge Locations / CloudFront flow
6. Shared Responsibility Model
7. Highly available web app (Multi-AZ)
8. AWS Organizations & consolidated billing
9. IAM account structure
10. Cost management toolchain
11. Hybrid connectivity (Direct Connect / VPN)
12. Pricing model decision tree

---

## 1. Cloud Service Models — Responsibility Stack

```
   ON-PREM        IaaS          PaaS          SaaS
  +--------+    +--------+    +--------+    +--------+
  | Apps   |Y   | Apps   |Y   | Apps   |Y   | Apps   |A
  | Data   |Y   | Data   |Y   | Data   |Y   | Data   |A
  | Runtime|Y   | Runtime|Y   | Runtime|A   | Runtime|A
  | OS     |Y   | OS     |Y   | OS     |A   | OS     |A
  | Virtual|Y   | Virtual|A   | Virtual|A   | Virtual|A
  | Servers|Y   | Servers|A   | Servers|A   | Servers|A
  | Storage|Y   | Storage|A   | Storage|A   | Storage|A
  | Network|Y   | Network|A   | Network|A   | Network|A
  +--------+    +--------+    +--------+    +--------+
   Y=You manage   A=AWS manages

   Examples:  EC2/VPC/EBS   Beanstalk/Lambda/RDS   Gmail/Salesforce
   Control:   HIGH  <-------------------------------> LOW
   Effort(you):HIGH <-------------------------------> LOW
```

---

## 2. Deployment Models

```
   PUBLIC CLOUD                PRIVATE CLOUD             HYBRID CLOUD
 +---------------+          +----------------+      +----------------------+
 | AWS / Azure   |          | Single org     |      | Private/On-Prem      |
 | Many tenants  |          | Dedicated HW   |      |  +--------+          |
 | +---+ +---+   |          | Full control   |      |  | DB/legacy|        |
 | |A | |B |...  |          | Higher cost    |      |  +----+----+        |
 | +---+ +---+   |          | On-prem or     |      |       | DirectConnect|
 | Pay-as-you-go |          | hosted         |      |       v   / VPN      |
 +---------------+          +----------------+      |  +--------+          |
   Internet access            Isolated, secure      |  | AWS cloud|        |
                                                    |  +--------+          |
                                                    +----------------------+
```

---

## 3. AWS Global Infrastructure Hierarchy

```
                       AWS (Global)
                            |
        +-------------------+--------------------+
        |                                        |
     REGIONS (geographic areas)           EDGE LOCATIONS
        |                                  (400+ POPs worldwide)
        |                                   - CloudFront CDN
   +----+----+----+                         - Route 53 DNS
   | AZ-a AZ-b AZ-c |  (>=3 AZs each)        - Global Accelerator
   +----+----+----+
        |
   Each AZ = 1+ Data Centers
   (independent power, cooling, network)
```

---

## 4. Region & Availability Zones (Fault Isolation)

```
   REGION: ap-south-1 (Mumbai)
   +-----------------------------------------------------------+
   |                                                           |
   |   AZ ap-south-1a       AZ ap-south-1b      AZ ap-south-1c |
   |   +-------------+      +-------------+     +-------------+ |
   |   | Data Center |      | Data Center |     | Data Center | |
   |   | Data Center |      | Data Center |     | Data Center | |
   |   +------+------+      +------+------+     +------+------+ |
   |          |                    |                  |        |
   |          +------ low-latency private links ------+        |
   |                                                           |
   |   Isolated power/cooling/network per AZ.                  |
   |   One AZ failing does NOT take down the others.           |
   +-----------------------------------------------------------+
```

---

## 5. Edge Locations / CloudFront Flow

```
   ORIGIN (e.g., S3 bucket in us-east-1)
        ^
        | (cache miss: fetch once)
        |
   +----+---------- Regional Edge Cache ----------+
        ^                                          
        | (cache miss)                             
   +----+----+        +---------+        +---------+
   | Edge LA |        | Edge LON|        |Edge MUM |   <- Edge Locations
   +----+----+        +----+----+        +----+----+
        |                  |                  |
     User(US)           User(UK)         User(India)
   (low latency, served from nearest cached edge)
```

---

## 6. Shared Responsibility Model

```
   +=========================================================+
   |  CUSTOMER : SECURITY *IN* THE CLOUD                      |
   |  - Customer data                                        |
   |  - Apps, IAM identities & access management             |
   |  - OS, network & firewall (Security Groups) [for EC2]   |
   |  - Client/server-side data encryption                  |
   |  - Network traffic protection                          |
   +=========================================================+
   |  AWS : SECURITY *OF* THE CLOUD                           |
   |  - Compute / Storage / Database / Networking software   |
   |  - Hardware & Global Infrastructure                     |
   |    (Regions, Availability Zones, Edge Locations)        |
   +=========================================================+
   Always the customer's job: DATA + IAM access decisions.
   Always AWS's job: PHYSICAL security of facilities.
```

---

## 7. Highly Available Web Application (Multi-AZ)

```
                         Users (Internet)
                              |
                       +------v------+
                       |  Route 53   |  (DNS)
                       +------+------+
                              |
                       +------v------+
                       | CloudFront  |  (CDN / edge cache)
                       +------+------+
                              |
                    +---------v---------+
                    | Application Load  |
                    |   Balancer (ALB)  |
                    +----+---------+----+
                         |         |
            REGION (e.g. ap-south-1)
        +----------------+----------------+
        |  AZ-a          |     AZ-b        |
        | +-----------+  |  +-----------+  |
        | | EC2 web   |  |  | EC2 web   |  |  <- Auto Scaling group
        | +-----+-----+  |  +-----+-----+  |     spans 2 AZs
        |       |        |        |        |
        | +-----v-----+  |  +-----v-----+  |
        | | RDS       |==|==| RDS       |  |  <- RDS Multi-AZ
        | | (primary) |  |  | (standby) |  |     auto-failover
        | +-----------+  |  +-----------+  |
        +----------------+----------------+
                  |
            +-----v-----+
            |    S3     |  (static assets, backups)
            +-----------+

   If AZ-a fails: ALB routes to AZ-b, RDS fails over to standby. No downtime.
```

---

## 8. AWS Organizations & Consolidated Billing

```
                 ORGANIZATION
                       |
          MANAGEMENT ACCOUNT (pays consolidated bill)
                       |
        +--------------+--------------+
        |              |              |
     OU: Security    OU: Prod      OU: Dev
        |              |              |
   [audit acct]   [prod acct]    [dev acct]
                                   [test acct]

   SCPs (guardrails) -----> applied to OUs/accounts
                            (set MAX permissions; do not grant)

   Consolidated Billing -> one invoice, combined volume discounts,
                           shared Reserved Instances / Savings Plans.
```

---

## 9. IAM Account Structure

```
   AWS ACCOUNT
   +-----------------------------------------------+
   | ROOT USER  (email login, full power)          |
   |   -> Enable MFA, then lock away. Never daily.  |
   |-----------------------------------------------|
   | GROUPS         USERS              ROLES        |
   | [Admins]  ---> alice                           |
   | [Devs]    ---> bob, ravi          [EC2->S3]    |
   | [Finance] ---> priya              [Lambda->DB] |
   |                                   [CrossAcct]  |
   | Permissions attached to GROUPS (best practice) |
   | Roles = temporary creds for services/accounts  |
   +-----------------------------------------------+
```

---

## 10. Cost Management Toolchain

```
            BILLING & COST MANAGEMENT CONSOLE
                          |
   +--------------+-------+-------+----------------+
   |              |               |                |
 Bills        AWS Budgets    Cost Explorer    Cost & Usage
 (current     (ALERT/LIMIT   (ANALYZE,         Report (CUR)
  charges)     thresholds)    VISUALIZE,       (most granular,
                              FORECAST,         -> S3)
                              RI/SP & rightsize
                              recommendations)
        |
   CloudWatch Billing Alarm -> notifies when est. charges > $X
   Free Tier tracker -> watch free usage limits
```

---

## 11. Hybrid Connectivity

```
   ON-PREMISES DATA CENTER                        AWS REGION
   +-----------------------+                   +------------------+
   |  Servers, DB, legacy  |                   |  VPC             |
   |                       |   AWS Direct      |  +------------+  |
   |  Customer Gateway     |===Connect (private|  | EC2 / RDS  |  |
   |                       |   dedicated line) |  +------------+  |
   |                       |-------------------|  Virtual Private |
   |                       |   Site-to-Site    |  Gateway         |
   |                       |   VPN (encrypted  |                  |
   |                       |   over internet)  |                  |
   +-----------------------+                   +------------------+

   Direct Connect = consistent, private, low-latency (costs more).
   VPN            = quick, encrypted over public internet (cheaper).
```

---

## 12. Pricing Model Decision Tree (EC2)

```
   Need compute?
        |
        v
   Is the workload interruptible / fault-tolerant? --YES--> SPOT (up to ~90% off)
        | NO
        v
   Is usage steady & predictable for 1-3 yrs?  --YES--> SAVINGS PLANS / RESERVED (up to ~72% off)
        | NO
        v
   Short-term / spiky / unknown duration?      --YES--> ON-DEMAND (pay per use)
        |
        v
   Compliance / per-socket licensing / dedicated HW? --YES--> DEDICATED HOSTS
```

---

➡️ Next: [03-real-world-examples.md](03-real-world-examples.md)

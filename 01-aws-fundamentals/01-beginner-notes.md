# Module 1 — Beginner Notes

> Every fundamental concept explained from zero. Read top to bottom. Each section has: a plain-English definition, an analogy, key points, and an exam/interview tip.

## Table of Contents
1. [What is Cloud Computing](#1-what-is-cloud-computing)
2. [Traditional Infrastructure vs Cloud](#2-traditional-infrastructure-vs-cloud)
3. [IaaS, PaaS, SaaS](#3-iaas-paas-saas)
4. [Public Cloud](#4-public-cloud)
5. [Private Cloud](#5-private-cloud)
6. [Hybrid Cloud](#6-hybrid-cloud)
7. [AWS Global Infrastructure](#7-aws-global-infrastructure)
8. [Regions](#8-regions)
9. [Availability Zones](#9-availability-zones)
10. [Edge Locations](#10-edge-locations)
11. [Shared Responsibility Model](#11-shared-responsibility-model)
12. [AWS Pricing Models](#12-aws-pricing-models)
13. [AWS Free Tier](#13-aws-free-tier)
14. [AWS Account Structure](#14-aws-account-structure)
15. [AWS Organizations](#15-aws-organizations)
16. [Billing Dashboard](#16-billing-dashboard)
17. [Cost Explorer](#17-cost-explorer)

---

## 1. What is Cloud Computing

**Definition:** Cloud computing is the **on-demand delivery of IT resources** — compute power, storage, databases, networking, software — **over the internet**, with **pay-as-you-go pricing**. Instead of buying, owning, and maintaining physical servers and data centers, you rent these resources from a cloud provider like AWS.

**Analogy — Electricity:** You don't build a power plant in your backyard to get electricity. You plug into the grid and pay only for what you consume. Cloud computing is the same idea applied to computing: plug in, use what you need, pay for what you use, and never worry about running the "power plant."

### The 6 Advantages of Cloud Computing (AWS's official list — memorize these)

| # | Advantage | Plain English |
|---|-----------|---------------|
| 1 | **Trade capital expense (CapEx) for variable expense (OpEx)** | Stop spending big money up front on hardware; pay only as you use resources. |
| 2 | **Benefit from massive economies of scale** | AWS buys hardware in huge volume, so prices are lower than you could get alone. |
| 3 | **Stop guessing capacity** | Scale up or down instantly — no over-buying "just in case." |
| 4 | **Increase speed and agility** | Spin up servers in minutes, not weeks. Experiment cheaply. |
| 5 | **Stop spending money running and maintaining data centers** | Focus on your product, not on cooling, power, and racking servers. |
| 6 | **Go global in minutes** | Deploy your app to data centers around the world with a few clicks. |

### The 5 Essential Characteristics (NIST definition)
1. **On-demand self-service** — provision resources yourself, automatically, no human on the provider side.
2. **Broad network access** — reach it over the internet from any device.
3. **Resource pooling** — provider's resources are shared among many customers (multi-tenancy).
4. **Rapid elasticity** — scale out/in quickly, appearing unlimited.
5. **Measured service** — usage is metered; you pay for exactly what you consume.

💡 **Exam tip:** "Pay-as-you-go," "on-demand," and "elastic" are the trigger words. CapEx → OpEx is the #1 financial benefit.

---

## 2. Traditional Infrastructure vs Cloud

**Traditional (On-Premises):** You buy physical servers, install them in a room or data center you own/rent, set up networking, power, and cooling, hire staff to maintain them, and plan capacity months ahead.

**Cloud:** You request virtual resources through a web console or API. They are ready in minutes. The provider owns and maintains all the physical gear.

### Side-by-Side Comparison

| Aspect | Traditional / On-Premises | Cloud (AWS) |
|--------|---------------------------|-------------|
| **Upfront cost** | High (CapEx) — buy servers, build rooms | Low/none — pay-as-you-go (OpEx) |
| **Time to provision** | Weeks to months | Minutes |
| **Capacity planning** | Guess ahead; risk over/under-provisioning | Scale on demand; no guessing |
| **Scaling** | Buy more hardware | Click / API call / automatic |
| **Maintenance** | You patch, cool, power, replace | AWS handles physical layer |
| **Global reach** | Build/lease data centers abroad | Deploy in a region in minutes |
| **Disaster recovery** | Expensive second site | Multi-AZ / multi-region, pay-as-used |
| **Responsibility** | You own everything | Shared Responsibility Model |
| **Best for** | Stable, predictable, regulatory-locked loads | Variable, growing, experimental loads |

### ASCII Diagram

```
TRADITIONAL DATA CENTER                     CLOUD (AWS)
+---------------------------+              +---------------------------+
|  You buy & manage ALL:    |              |  You manage:              |
|   - Buildings             |              |   - Your apps & data      |
|   - Power & cooling        |              |   - Configuration         |
|   - Network cables         |   =====>     +---------------------------+
|   - Physical servers       |              |  AWS manages:             |
|   - OS, patching           |              |   - Hardware, power       |
|   - Apps & data            |              |   - Network, facilities   |
|                            |              |   - Virtualization        |
|  Weeks to scale            |              |  Minutes to scale         |
|  High CapEx                |              |  Pay-as-you-go OpEx       |
+---------------------------+              +---------------------------+
```

💡 **Exam tip:** Cloud converts large up-front capital expenditure into smaller, ongoing operational expenditure and removes the need to guess capacity.

---

## 3. IaaS, PaaS, SaaS

These are the **three cloud service models** — they describe **how much** the provider manages vs how much you manage.

### IaaS — Infrastructure as a Service
You rent the **raw building blocks**: virtual servers, storage, networking. You manage the OS, runtime, and apps. Maximum control and flexibility.
- **AWS examples:** Amazon EC2 (virtual servers), Amazon VPC (networking), Amazon EBS (block storage).
- **Analogy:** Renting an empty plot of land + utilities. You build the house.

### PaaS — Platform as a Service
You get a **ready-made platform** to deploy code. The provider manages OS, servers, patching, scaling. You manage only your application and data.
- **AWS examples:** AWS Elastic Beanstalk, AWS Lambda, Amazon RDS (managed database).
- **Analogy:** Renting a fully built kitchen. You just cook (write code).

### SaaS — Software as a Service
You use **finished software** over the internet. The provider manages everything. You just log in and use it.
- **Examples:** Gmail, Dropbox, Salesforce, Microsoft 365; on AWS: Amazon Chime, Amazon WorkMail.
- **Analogy:** Eating at a restaurant. You just order and eat.

### The "Pizza as a Service" Model (classic teaching analogy)

```
                 On-Prem    IaaS      PaaS      SaaS
                 (make at   (take &   (delivery (dine-in
                  home)     bake)     pizza)     restaurant)
Dining table      YOU        YOU       YOU        AWS
Soda / drinks     YOU        YOU       YOU        AWS
Electric/Oven     YOU        YOU       AWS        AWS
Pizza dough       YOU        YOU       AWS        AWS
Tomato sauce      YOU        YOU       AWS        AWS
Toppings          YOU        AWS       AWS        AWS
Cheese            YOU        AWS       AWS        AWS

= what YOU manage shrinks as you move right.
```

### What You Manage (the key table)

```
        | Apps | Data | Runtime | OS | Virtualization | Servers | Storage | Network |
On-Prem |  YOU | YOU  |  YOU    | YOU|     YOU        |  YOU    |  YOU    |  YOU    |
IaaS    |  YOU | YOU  |  YOU    | YOU|     AWS        |  AWS    |  AWS    |  AWS    |
PaaS    |  YOU | YOU  |  AWS    | AWS|     AWS        |  AWS    |  AWS    |  AWS    |
SaaS    |  AWS | AWS  |  AWS    | AWS|     AWS        |  AWS    |  AWS    |  AWS    |
```

💡 **Exam tip:** Control vs convenience trade-off. IaaS = most control, most responsibility. SaaS = least control, least responsibility. EC2 = IaaS, Elastic Beanstalk/Lambda = PaaS, finished apps = SaaS.

---

## 4. Public Cloud

**Definition:** Cloud infrastructure **owned and operated by a third-party provider** (AWS, Azure, Google Cloud) and **shared among many customers** over the public internet. You own none of the hardware.

**Key points:**
- Multi-tenant — many customers share the same physical infrastructure (securely isolated).
- No upfront hardware cost; pure pay-as-you-go.
- Virtually unlimited scale.
- Provider handles maintenance and security of the infrastructure.

**Examples:** AWS, Microsoft Azure, Google Cloud Platform (GCP).

**Best for:** Startups, web/mobile apps, variable workloads, dev/test, fast global launches.

```
        PUBLIC CLOUD (AWS)
   +-----------------------------+
   |  Shared infrastructure       |
   |  +-------+ +-------+ +-----+ |
   |  |Cust A | |Cust B | |Cust C| |  <- isolated tenants
   |  +-------+ +-------+ +-----+ |
   +-----------------------------+
       Access over the internet
```

💡 **Exam tip:** "Public cloud" = AWS/Azure/GCP. Most CLF-C02 questions assume public cloud.

---

## 5. Private Cloud

**Definition:** Cloud infrastructure **dedicated to a single organization**. It can be hosted on-premises (in your own data center) or by a third party, but the resources are **not shared** with other customers.

**Key points:**
- Single-tenant — full control and isolation.
- Better for strict **security, compliance, and regulatory** needs (e.g., banking, defense, healthcare).
- Higher cost and responsibility — you (or a vendor) manage it.
- Less elastic than public cloud (limited by your own capacity).

**Examples:** VMware-based private cloud, OpenStack, **AWS Outposts** (AWS hardware in your own data center).

**Best for:** Organizations with sensitive data, legacy systems, or compliance rules requiring data to stay in-house.

💡 **Exam tip:** Private cloud = single organization, more control, used when compliance/regulation demands it.

---

## 6. Hybrid Cloud

**Definition:** A **combination of public and private cloud** (or cloud + on-premises) that work together, with data and applications moving between them.

**Why use it:**
- Keep sensitive data on-premises/private; burst to public cloud for scale.
- Gradual migration path — move to cloud in stages.
- Disaster recovery: on-prem primary, cloud backup.

**AWS services that enable hybrid:**
- **AWS Direct Connect** — private dedicated network link from your data center to AWS.
- **AWS VPN** — encrypted tunnel over the internet to AWS.
- **AWS Outposts** — AWS infrastructure running in your own data center.
- **AWS Storage Gateway** — bridge on-prem storage to AWS cloud storage.

```
   ON-PREMISES / PRIVATE              PUBLIC CLOUD (AWS)
   +--------------------+            +--------------------+
   | Sensitive DB       |  Direct    | Web/app servers    |
   | Legacy apps        |<=Connect=> | Auto Scaling       |
   | Compliance data    |   / VPN    | Backups, DR        |
   +--------------------+            +--------------------+
            \________ work together as one __________/
```

**Best for:** Banks, hospitals, governments, enterprises mid-migration.

💡 **Exam tip:** Hybrid = public + private connected. Direct Connect (dedicated/private link) and VPN (encrypted over internet) are the connectors. Outposts brings AWS on-prem.

---

## 7. AWS Global Infrastructure

AWS runs the world's largest cloud, built as a hierarchy:

```
                AWS GLOBAL INFRASTRUCTURE
                          |
        +-----------------+-----------------+
        |                 |                 |
     REGIONS          EDGE LOCATIONS   (Local Zones,
        |             (CloudFront,      Wavelength,
   Availability Zones  Global Accel.)   Outposts)
        |
   Data Centers
```

- **Region** = a geographic area (e.g., Mumbai, N. Virginia). Contains multiple AZs.
- **Availability Zone (AZ)** = one or more discrete data centers with redundant power/network, isolated from other AZs but close enough for low-latency links.
- **Edge Location** = a site for caching content close to users (used by CloudFront CDN, Route 53).

💡 **Exam tip:** Order of size: **Region > Availability Zone > Data Center**. Edge Locations are far more numerous than Regions and exist for low-latency content delivery.

---

## 8. Regions

**Definition:** A **Region** is a separate **geographic area** in the world where AWS clusters data centers. Examples: `us-east-1` (N. Virginia), `ap-south-1` (Mumbai), `eu-west-1` (Ireland).

**Key facts:**
- Each Region is **completely independent and isolated** from others (fault containment, data sovereignty).
- A Region contains **multiple Availability Zones** (usually 3+).
- You **choose** the Region for your resources.
- Data does **not** automatically replicate between Regions — you control that.

### How to Choose a Region (4 factors)
1. **Latency** — pick a Region close to your users for speed.
2. **Compliance / data residency** — laws may require data to stay in a country (e.g., GDPR in EU).
3. **Service availability** — not every service is in every Region; new services launch in some Regions first.
4. **Pricing** — costs vary by Region (e.g., N. Virginia is often cheapest).

```
        AWS REGION (e.g., ap-south-1 Mumbai)
   +-------------------------------------------+
   |   AZ-a        AZ-b        AZ-c            |
   |  +------+    +------+    +------+         |
   |  | DCs  |    | DCs  |    | DCs  |         |
   |  +------+    +------+    +------+         |
   +-------------------------------------------+
   Each AZ is physically separate but low-latency linked.
```

💡 **Exam tip:** Regions are isolated. Some services are **global** (IAM, Route 53, CloudFront, WAF) — they are not tied to one Region.

---

## 9. Availability Zones

**Definition:** An **Availability Zone (AZ)** is **one or more discrete data centers** within a Region, each with independent power, cooling, and networking. AZs in a Region are physically separated (often by many kilometers) yet connected by **high-speed, low-latency private links**.

**Why AZs matter — High Availability:**
- If one AZ fails (power outage, flood, fire), your app keeps running in another AZ.
- Best practice: run resources across **at least 2 AZs** (Multi-AZ deployment).

**Naming:** AZ names look like `us-east-1a`, `us-east-1b`. (Note: AZ letters are randomized per account, so `us-east-1a` for you ≠ `us-east-1a` for someone else.)

```
   REGION
   +-------------------------------------------------+
   |  AZ-a              AZ-b              AZ-c        |
   |  [Web+DB]   <==>   [Web+DB]   <==>   [backup]    |
   |   active           active            standby     |
   |                                                 |
   |  If AZ-a dies, AZ-b serves traffic. No downtime.|
   +-------------------------------------------------+
```

**Multi-AZ example:** Amazon RDS Multi-AZ keeps a standby database copy in a second AZ and auto-fails over if the primary fails.

💡 **Exam tip:** AZ = fault isolation for **high availability**. Use multiple AZs to survive a data-center failure. Use multiple **Regions** for disaster recovery and global reach.

---

## 10. Edge Locations

**Definition:** **Edge Locations** are AWS sites located in **major cities worldwide** (far more numerous than Regions) used to **cache content close to end users** and reduce latency. They power AWS's content delivery and DNS services.

**Services that use Edge Locations:**
- **Amazon CloudFront** — Content Delivery Network (CDN); caches images, videos, web pages near users.
- **Amazon Route 53** — DNS service, resolves domain names quickly at the edge.
- **AWS Global Accelerator** — routes user traffic to the optimal AWS endpoint.
- **AWS WAF / Shield** — security at the edge.

**How it helps (CloudFront example):**
```
User in Mumbai requests video stored in N. Virginia (origin).

WITHOUT CDN:                          WITH CLOUDFRONT EDGE:
Mumbai ---> N.Virginia (far, slow)    Mumbai ---> Mumbai Edge (cached, fast)
                                                     |
                                          (first time only) ---> N.Virginia origin
```
First user fetches from origin and the file is cached at the edge; later users in that area get it instantly from the nearby edge.

💡 **Exam tip:** Edge Location = caching/low-latency delivery. CloudFront = the CDN that uses them. "Regional Edge Caches" sit between edge locations and the origin for larger/less-popular content.

---

## 11. Shared Responsibility Model

**The single most important security concept in AWS.** Security is a **partnership** between AWS and you.

> **AWS is responsible for security OF the cloud.**
> **You (customer) are responsible for security IN the cloud.**

### Who does what

| AWS — Security **OF** the cloud | Customer — Security **IN** the cloud |
|--------------------------------|--------------------------------------|
| Physical data centers (guards, locks) | Your data (classification, encryption choices) |
| Hardware & global infrastructure | Identity & access management (IAM users, MFA) |
| Networking infrastructure | OS patching on EC2 (for IaaS) |
| Virtualization layer (hypervisor) | Firewall / Security Group configuration |
| Managed service software (e.g., RDS engine) | Application code & its security |
| Region/AZ/Edge facilities | Client- and server-side encryption settings |

### Diagram

```
+-------------------------------------------------------------+
|  CUSTOMER  =  Security IN the cloud                          |
|  - Customer data                                            |
|  - Platform, apps, IAM (identity & access)                  |
|  - OS, network & firewall config (for EC2/IaaS)            |
|  - Client/server-side encryption, network traffic protection|
+-------------------------------------------------------------+
|  AWS  =  Security OF the cloud                               |
|  - Software: compute, storage, database, networking        |
|  - Hardware/Global Infra: Regions, AZs, Edge Locations     |
+-------------------------------------------------------------+
```

### ⚠️ It shifts by service type
- **EC2 (IaaS):** You patch the OS, configure firewalls, manage everything on top. More responsibility on you.
- **RDS / Lambda / S3 (managed/PaaS):** AWS patches the underlying OS and engine; you handle access, data, and config. Less responsibility on you.
- **Always yours, no matter what:** your **data**, your **IAM/credentials**, and **who you grant access to**.

💡 **Exam tip:** Remember the phrasing — AWS = "**OF** the cloud," Customer = "**IN** the cloud." The customer is *always* responsible for their data and for managing IAM access. AWS is *always* responsible for physical security.

---

## 12. AWS Pricing Models

AWS's core principle: **Pay only for what you use, with no long-term contracts required.** Three pricing fundamentals:
1. **Compute** — pay for processing time.
2. **Storage** — pay for data stored.
3. **Data transfer OUT** — pay to send data out of AWS (data IN is usually free).

### EC2 (Compute) Purchasing Options — know these well

| Option | What it is | Best for | Savings |
|--------|-----------|----------|---------|
| **On-Demand** | Pay per second/hour, no commitment | Short-term, unpredictable, dev/test | Baseline (most expensive) |
| **Reserved Instances (RI)** | Commit to 1 or 3 years for a specific instance | Steady, predictable workloads | Up to ~72% |
| **Savings Plans** | Commit to $/hour of usage for 1 or 3 years (flexible across instance types) | Steady, predictable, flexible | Up to ~72% |
| **Spot Instances** | Bid on AWS's spare capacity; can be reclaimed with 2-min notice | Fault-tolerant, batch, big data, flexible-time jobs | Up to ~90% |
| **Dedicated Hosts** | A physical server dedicated to you | Compliance / per-socket licensing | Most expensive |

### Other Cost Levers
- **Free Tier** — try services free (see Module 13 in this file).
- **Volume discounts** — the more you use (e.g., S3 storage tiers), the lower the per-unit price.
- **Reserved capacity** for RDS, ElastiCache, Redshift, etc.

### The 3 Drivers of Cost (remember "C-S-O")
- **C**ompute hours used
- **S**torage consumed
- **O**utbound data transfer

💰 **Cost tip:** Spot for interruptible/batch; Reserved/Savings Plans for steady baseline; On-Demand for spiky/unknown; Dedicated Hosts only for licensing/compliance.

💡 **Exam tip:** Spot = cheapest but interruptible. Savings Plans are more flexible than Reserved Instances. Data transfer **in** is generally free; **out** costs money.

---

## 13. AWS Free Tier

**Definition:** The **AWS Free Tier** lets you use certain AWS services **free** within limits, so you can learn and experiment at low/no cost. It has **three types**:

| Type | Meaning | Example |
|------|---------|---------|
| **12 Months Free** | Free for 12 months after you create your account | 750 hrs/month of EC2 t2.micro/t3.micro, 5 GB S3 standard, 750 hrs RDS |
| **Always Free** | Free forever, within limits | 1M AWS Lambda requests/month, 25 GB DynamoDB storage |
| **Free Trials** | Short-term free trial for a specific service | Amazon Inspector (free trial), some ML services |

### Common Free Tier limits (illustrative — always verify current values)
- **EC2:** 750 hours/month of t2.micro or t3.micro (Linux/Windows) for 12 months.
- **S3:** 5 GB standard storage, 20,000 GET, 2,000 PUT requests/month for 12 months.
- **RDS:** 750 hours/month of db.t2/t3.micro, 20 GB storage for 12 months.
- **Lambda:** 1,000,000 free requests + 400,000 GB-seconds/month — **always free**.
- **DynamoDB:** 25 GB storage — always free.

### ⚠️ Free Tier Gotchas (very common mistakes)
- Exceeding limits → you get **billed** automatically. There's no hard cap by default.
- Some "always free" limits are easy to blow past (e.g., data transfer out).
- Forgetting to **stop/terminate** resources (e.g., a running EC2 or an Elastic IP not attached) → charges.
- **Set up a billing alarm / AWS Budget** on day one (see Billing Guide).

💰 **Cost tip:** On your very first day: enable a **$1 or $5 Budget alert** and a **CloudWatch billing alarm**. This is the cheapest insurance against surprise bills.

💡 **Exam tip:** Know the 3 categories — 12-Months-Free, Always-Free, Trials. Lambda & DynamoDB free amounts are "Always Free."

---

## 14. AWS Account Structure

**An AWS account** is the fundamental container for your AWS resources and the boundary for billing and security.

### Key identities inside an account

| Identity | What it is | Best practice |
|----------|-----------|---------------|
| **Root user** | The email you sign up with; has **unrestricted** access to everything | Use ONLY for initial setup; enable MFA; then lock it away. Never use daily. |
| **IAM user** | An identity you create for a person/app with specific permissions | Create individual users; grant least privilege |
| **IAM role** | A set of permissions that can be *assumed* temporarily (by users, services, or other accounts) | Use for EC2/Lambda to access AWS, and for cross-account access |
| **IAM group** | A collection of IAM users sharing permissions | Assign permissions to groups, not individuals |

### Account boundary
- Each account is an **isolated environment** — resources, billing, and security are scoped to it.
- Best practice for organizations: use **multiple accounts** (e.g., separate dev, test, prod) for blast-radius isolation and clearer billing — managed centrally via **AWS Organizations**.

```
                AWS ACCOUNT (123456789012)
   +------------------------------------------------+
   | ROOT USER (lock away, MFA on) -- full power     |
   |                                                |
   | IAM Groups:  [Admins]  [Developers]  [Finance]  |
   |                 |           |            |       |
   | IAM Users:   alice       bob, ravi     priya     |
   |                                                |
   | IAM Roles:   EC2-S3-ReadRole, Lambda-DDB-Role   |
   +------------------------------------------------+
```

🔒 **Security tip:** First 5 things in a new account — (1) MFA on root, (2) create an admin IAM user, (3) stop using root, (4) set a billing alarm, (5) follow least privilege.

💡 **Exam tip:** Root user = unlimited, used rarely. IAM = users/groups/roles for day-to-day. Roles = temporary credentials, ideal for services and cross-account access.

---

## 15. AWS Organizations

**Definition:** **AWS Organizations** is a free service to **centrally manage and govern multiple AWS accounts** as a single unit.

### Core concepts

| Term | Meaning |
|------|---------|
| **Management (master) account** | The account that creates the organization and pays the consolidated bill |
| **Member accounts** | All other accounts joined to the organization |
| **Organizational Unit (OU)** | A folder to group accounts (e.g., "Prod", "Dev", "Finance") |
| **Service Control Policies (SCPs)** | Guardrails that set the **maximum permissions** for accounts/OUs (they limit, never grant) |
| **Consolidated Billing** | One bill for all accounts; combine usage for volume discounts |

### Benefits
1. **Consolidated billing** — single payment method, combined volume discounts, one view of all spend.
2. **Centralized governance** — apply SCPs to enforce rules (e.g., "no one can disable CloudTrail," "only allowed Regions").
3. **Account isolation** — separate accounts for dev/test/prod limit blast radius.
4. **Automation** — programmatically create accounts.

```
              MANAGEMENT ACCOUNT (pays the bill)
                          |
              +-----------+-----------+
              |           |           |
            OU: Prod    OU: Dev    OU: Security
              |           |           |
         [acct-prod] [acct-dev]  [acct-audit]
              ^
        SCPs apply as guardrails at OU/account level
```

💰 **Cost tip:** Consolidated billing aggregates usage across accounts so you reach **volume discount tiers** faster and share Reserved Instance/Savings Plan benefits.

💡 **Exam tip:** SCPs **limit** maximum permissions — they don't grant access by themselves. Organizations is **free**. Consolidated billing = combined volume discounts + single bill.

---

## 16. Billing Dashboard

**Definition:** The **AWS Billing Dashboard** (AWS Billing & Cost Management console) is your home for **viewing, understanding, and managing what you spend** on AWS.

### What you can see/do there
- **Month-to-date spend** and a **forecast** of the month's total.
- **Bills** — detailed breakdown by service and by Region.
- **Payment methods** and invoices.
- **AWS Budgets** — set custom spending/usage limits with email/SNS alerts.
- **Free Tier usage tracking** — see how close you are to limits.
- **Cost Explorer** launch point (analyze trends).
- **Cost Allocation Tags** — tag resources to attribute costs to teams/projects.
- **Credits** — apply promotional credits.

### Key tools within Billing & Cost Management
| Tool | Purpose |
|------|---------|
| **Bills** | See current charges by service/Region |
| **AWS Budgets** | Set thresholds + alerts (cost, usage, RI/SP coverage) |
| **Cost Explorer** | Visualize and analyze cost trends over time |
| **Cost & Usage Report (CUR)** | Most detailed line-item data, delivered to S3 |
| **Free Tier** | Track free tier consumption |
| **Billing Alarms (via CloudWatch)** | Alarm when estimated charges exceed a value |

💰 **Cost tip:** Set at least one **AWS Budget** with an email alert the day you open your account.

💡 **Exam tip:** Billing Dashboard = view & manage spend. **Budgets** = proactive alerts/limits. **Cost Explorer** = analyze/visualize. **CUR** = most granular data.

---

## 17. Cost Explorer

**Definition:** **AWS Cost Explorer** is a free tool to **visualize, understand, and analyze your AWS costs and usage over time** — with graphs, filters, and forecasts.

### What it does
- View costs over the **last 13 months** and forecast the **next 12 months**.
- **Filter and group** by service, account, Region, tag, instance type, etc.
- Identify trends, spikes, and your biggest cost drivers.
- Get **Reserved Instance & Savings Plans recommendations** to save money.
- See **Rightsizing recommendations** (e.g., downsize underused EC2).

### Cost Explorer vs Budgets vs CUR (don't confuse these)
| Tool | Best answer to... |
|------|-------------------|
| **Cost Explorer** | "Where is my money going and what's the trend?" (analyze & forecast) |
| **AWS Budgets** | "Alert me / cap me when I cross a threshold" (proactive control) |
| **Cost & Usage Report** | "Give me every line item for deep analysis" (most granular, to S3) |

```
   COST EXPLORER VIEW (example)
   $ |                         ____
     |                  ____   |EC2|
     |          ____    |EC2|  |---|
     |   ____   |EC2|   |---|  |S3 |
     |   |EC2|  |---|   |S3 |  |---|
     |   |S3 |  |S3 |   |---|  |RDS|
     +---Jan----Feb----Mar----Apr--->  (group by service, filter by tag)
```

💡 **Exam tip:** Cost Explorer = **analyze & visualize & forecast** + RI/Savings Plans & rightsizing recommendations. Budgets = **alert/limit**. Both live under Billing & Cost Management.

---

## ✅ Module 1 Recap Checklist

You should now be able to explain, in your own words:
- [ ] What cloud computing is and its 6 advantages
- [ ] Why cloud beats traditional infra (CapEx → OpEx, elasticity, speed)
- [ ] The difference between IaaS, PaaS, SaaS (with AWS examples)
- [ ] Public vs Private vs Hybrid cloud and when to use each
- [ ] Regions vs AZs vs Edge Locations
- [ ] The Shared Responsibility Model ("OF" vs "IN" the cloud)
- [ ] The 5 EC2 pricing options and when to use each
- [ ] The 3 Free Tier types and the #1 gotcha
- [ ] Root user vs IAM users/roles/groups
- [ ] What AWS Organizations, SCPs, and consolidated billing do
- [ ] Billing Dashboard vs Budgets vs Cost Explorer vs CUR

➡️ Next: [02-architecture-diagrams.md](02-architecture-diagrams.md)

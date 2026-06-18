# Module 10 — Revision Notes (Last-Minute Cheat Sheet)

> One-page-per-topic, ultra-condensed. Read this the night before an exam or interview. If you can recall everything here, you know the fundamentals.

---

## ☁️ Cloud Computing
- = On-demand IT over internet, **pay-as-you-go**.
- **6 advantages:** CapEx→OpEx · economies of scale · stop guessing capacity · speed/agility · stop running data centers · go global in minutes.
- **5 traits:** on-demand self-service · broad network access · resource pooling · rapid elasticity · measured service.
- **Elasticity** = auto scale up/down with demand.

## 🏢 Traditional vs Cloud
- Traditional = **CapEx**, slow (weeks), you maintain HW, guess capacity.
- Cloud = **OpEx**, fast (minutes), AWS maintains HW, scale on demand.

## 🧱 IaaS / PaaS / SaaS
- **IaaS** = raw infra (EC2, VPC, EBS) — most control, you manage OS+.
- **PaaS** = managed platform (Beanstalk, Lambda, RDS) — manage app+data.
- **SaaS** = finished software (Gmail, Salesforce) — just use it.
- Moving IaaS→SaaS: **control ↓, AWS responsibility ↑**.

## 🌐 Deployment Models
- **Public** = AWS/Azure/GCP, multi-tenant, pay-as-you-go.
- **Private** = single org, isolated, compliance (Outposts).
- **Hybrid** = public + private/on-prem; connect via **Direct Connect** (private) or **VPN** (encrypted over internet).

## 🗺️ Global Infrastructure
- **Region** = geographic area, isolated, has multiple AZs. Choose by: **latency, compliance, service availability, pricing**.
- **AZ** = 1+ discrete data centers, independent power/cooling/network; linked by low-latency private fiber. Use **multiple AZs = high availability**.
- **Edge Location** = caching POPs near users (most numerous). Used by **CloudFront** (CDN) & **Route 53** (DNS).
- **Multi-AZ** = HA in one Region; **Multi-Region** = DR/global.
- **Global services:** IAM, Route 53, CloudFront, WAF.
- Size order: **Region > AZ > Data Center**.

## 🔐 Shared Responsibility Model
- **AWS = security OF the cloud** (HW, facilities, infra, managed-service software).
- **Customer = security IN the cloud** (data, IAM, OS for EC2, Security Groups, encryption config).
- **Always customer's:** data + IAM access. **Always AWS's:** physical security.
- More managed service = less customer burden (but data/access still yours).

## 💵 Pricing Models (EC2)
| Option | Use for | Save |
|--------|---------|------|
| On-Demand | short/spiky/unknown | baseline |
| Reserved Instances | steady, 1/3-yr commit | ~72% |
| Savings Plans | steady, flexible commit | ~72% |
| Spot | interruptible/batch | ~90% (2-min notice) |
| Dedicated Hosts | licensing/compliance | most $$$ |
- Cost drivers: **Compute, Storage, Outbound data transfer**. Data **in** free, **out** costs.

## 🆓 Free Tier
- **3 types:** 12-months-free (EC2 750h, S3 5GB) · always-free (Lambda 1M req, DynamoDB 25GB) · trials.
- Exceeding limits → **billed**. Always set a **Budget/alarm**.

## 👤 Account Structure & IAM
- **Root** = unlimited; enable MFA, lock away, no access keys, don't use daily.
- **IAM user** = person/app identity; **group** = users sharing permissions; **role** = temporary assumable permissions (services, cross-account).
- Practice **least privilege**.

## 🏛️ AWS Organizations
- Centrally manage many accounts (free).
- **Management account** pays consolidated bill; **member accounts**; **OUs** group accounts.
- **SCPs** = guardrails (max permissions, never grant).
- **Consolidated billing** = one bill + combined volume discounts + shared RIs/SPs.

## 💰 Billing & Cost Tools
- **Billing Dashboard** = view spend/forecast/invoices/Free Tier.
- **AWS Budgets** = proactive threshold alerts/actions.
- **Cost Explorer** = visualize/analyze/forecast + RI/SP & rightsizing recs.
- **CUR** = most granular line-item data → S3.
- **Pricing Calculator** = estimate before building.
- **Cost allocation tags** = attribute cost to teams/projects.

---

## 🔁 7 Rs of Migration
Rehost (lift&shift) · Replatform (lift,tinker&shift) · Repurchase (→SaaS) · Refactor (cloud-native) · Retain (keep) · Retire (delete) · Relocate (hypervisor move).

## ⚡ 30-Second Self-Test (say the answer aloud)
1. AWS responsibility vs yours? → OF vs IN the cloud.
2. Region vs AZ vs Edge? → geo area / data centers / caching POPs.
3. Cheapest interruptible EC2? → Spot.
4. Steady 24/7 savings? → Savings Plans/RIs.
5. 3 Free Tier types? → 12-mo, always-free, trials.
6. SCP does what? → limits max permissions.
7. Analyze spend vs alert on spend? → Cost Explorer vs Budgets.
8. Most control service model? → IaaS.
9. Hybrid connectors? → Direct Connect / VPN.
10. First day must-dos? → MFA on root + Budget alarm.

---

➡️ Next: [11-certification-notes.md](11-certification-notes.md)

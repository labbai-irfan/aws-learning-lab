# Module 11 — Certification Notes (AWS Certified Cloud Practitioner, CLF-C02)

> Everything you need to know about the entry-level AWS certification and how the fundamentals in this repo map to it.

---

## 🎓 About the Exam

| Item | Detail |
|------|--------|
| **Name** | AWS Certified Cloud Practitioner |
| **Code** | CLF-C02 |
| **Level** | Foundational (entry-level) |
| **Format** | 65 questions (multiple choice + multiple response) |
| **Duration** | 90 minutes |
| **Passing score** | ~700/1000 (scaled) |
| **Cost** | ~$100 USD (check current pricing) |
| **Delivery** | Online proctored or test center |
| **Validity** | 3 years |
| **Prerequisites** | None (6 months AWS exposure recommended) |

> ⚠️ Always verify current exam details on the official page: https://aws.amazon.com/certification/certified-cloud-practitioner/

---

## 📊 Exam Domains (CLF-C02 weighting)

| Domain | Weight | What it covers |
|--------|--------|----------------|
| **1. Cloud Concepts** | 24% | Benefits of cloud, cloud economics, Well-Architected, migration basics |
| **2. Security & Compliance** | 30% | Shared Responsibility Model, IAM, security services, compliance |
| **3. Cloud Technology & Services** | 34% | Core AWS services (compute, storage, network, DB), global infra, ways to deploy |
| **4. Billing, Pricing & Support** | 12% | Pricing models, billing tools, support plans, Organizations |

💡 Security & Compliance + Technology = ~64% of the exam. This repo's fundamentals cover the conceptual backbone of all four domains.

---

## ✅ How This Repo Maps to the Exam

| Repo Topic | Exam Domain |
|------------|-------------|
| Cloud computing, benefits, traditional vs cloud | Domain 1 |
| IaaS/PaaS/SaaS, deployment models | Domain 1 & 3 |
| Regions / AZs / Edge Locations | Domain 3 |
| Shared Responsibility Model | Domain 2 |
| Account structure, IAM, root user, MFA | Domain 2 |
| Pricing models, Free Tier | Domain 4 |
| Organizations, SCPs, consolidated billing | Domain 4 & 2 |
| Billing Dashboard, Budgets, Cost Explorer, CUR | Domain 4 |
| Migration (7 Rs) | Domain 1 |

---

## 🧠 High-Yield Exam Facts (memorize)

**Shared Responsibility**
- AWS = "OF the cloud" (HW, facilities, infra). Customer = "IN the cloud" (data, IAM, config).
- Customer ALWAYS owns data + IAM; AWS ALWAYS owns physical security.

**Global Infrastructure**
- Region = isolated geo area; ≥3 AZs typical. AZ = 1+ data centers. Edge = caching POPs.
- Global services: IAM, Route 53, CloudFront, WAF, Organizations.
- Multi-AZ = HA; Multi-Region = DR/global reach.

**Pricing**
- On-Demand / Reserved / Savings Plans / Spot / Dedicated Hosts.
- Spot ~90% (interruptible); RIs/SPs ~72% (commit); data IN free, OUT paid.
- 3 cost drivers: compute, storage, outbound transfer.

**Free Tier**
- 12-months-free, always-free, trials.

**Accounts/Org**
- Root: MFA + lock away. IAM least privilege. Roles = temporary creds.
- Organizations: consolidated billing + SCP guardrails (SCPs limit, not grant).

**Cost Tools**
- Cost Explorer = analyze/forecast. Budgets = alert/limit. CUR = granular→S3. Pricing Calculator = estimate.

---

## 🛟 AWS Support Plans (often tested — know the tiers)

| Plan | Key feature | Best for |
|------|-------------|----------|
| **Basic** | Free; docs, forums, Trusted Advisor (core checks), Personal Health Dashboard | Everyone |
| **Developer** | Business-hours email to Cloud Support Associates | Dev/test |
| **Business** | 24/7 phone/chat/email, full Trusted Advisor, <1hr for production-down | Production workloads |
| **Enterprise On-Ramp** | <30 min for business-critical, pool of TAMs | Growing critical workloads |
| **Enterprise** | Dedicated **TAM**, <15 min for business-critical, concierge | Mission-critical, large orgs |

💡 Response-time tiers and the dedicated **Technical Account Manager (TAM)** = Enterprise-only are common exam points.

---

## 🏛️ AWS Well-Architected Framework (6 Pillars — know names)
1. **Operational Excellence**
2. **Security**
3. **Reliability**
4. **Performance Efficiency**
5. **Cost Optimization**
6. **Sustainability**

💡 Exam may ask which pillar a recommendation belongs to (e.g., right-sizing = Cost Optimization; multi-AZ = Reliability).

---

## 🔑 Cloud Adoption Framework (CAF) — 6 Perspectives (awareness)
Business, People, Governance (business capabilities) · Platform, Security, Operations (technical capabilities).

---

## 📝 Exam-Taking Strategy
- **Eliminate** obviously wrong answers first.
- Watch keywords: *"most cost-effective," "highly available," "least operational overhead," "fastest."*
- "Highly available" → multiple **AZs**. "Disaster recovery/global" → multiple **Regions**.
- "Least operational overhead" → **managed/serverless** services.
- "Interruptible/cheapest compute" → **Spot**. "Steady/committed" → **Savings Plans/RIs**.
- "Alert me on spend" → **Budgets**. "Analyze spend" → **Cost Explorer**.
- "Maximum permission guardrail" → **SCP**.
- There's **no penalty for guessing** — answer every question.
- Flag and revisit hard questions; manage your 90 minutes (~1.4 min/question).

---

## 📚 Recommended Study Resources
- AWS Skill Builder (free digital training): https://skillbuilder.aws/
- Official Exam Guide & sample questions (download from the cert page).
- AWS Cloud Practitioner Essentials course (free, AWS).
- AWS Whitepapers: *Overview of AWS*, *AWS Well-Architected Framework*, *How AWS Pricing Works*.
- This repo's Modules 7 (MCQs), 9 (Scenarios), and 10 (Revision).

---

## 🗓️ Suggested 2-Week Study Plan
- **Days 1–3:** Module 1 (Beginner Notes) + Module 2 (Diagrams).
- **Days 4–5:** Modules 3–4 (Real World + Migration).
- **Days 6–7:** Modules 5–6 (Account Setup + Billing) — do it hands-on.
- **Days 8–9:** Module 7 (100 MCQs) — review every miss.
- **Days 10–11:** Module 9 (Scenarios) + Module 8 (Interview Qs).
- **Day 12:** Module 12 (Common Mistakes) + Module 13 (Hands-on).
- **Day 13:** Module 10 (Revision) + official sample questions.
- **Day 14:** Light review + book/take the exam.

---

## 🚀 What's Next After Cloud Practitioner?
- **AWS Certified Solutions Architect – Associate (SAA-C03)** — most popular next step.
- **AWS Certified Developer – Associate** / **SysOps Administrator – Associate**.
- Build the Mini Projects in [14-mini-projects.md](14-mini-projects.md) to gain real experience.

---

➡️ Next: [12-common-mistakes.md](12-common-mistakes.md)

# Module 6 — Billing & Cost Management Guide

> How to understand your AWS bill, set guardrails, and analyze spend. The single best habit a beginner can build is **cost awareness from day one**.

---

## The Cost Management Toolset (at a glance)

| Tool | One-line purpose | Proactive or Reactive |
|------|------------------|------------------------|
| **Billing Dashboard** | See current/forecast charges & invoices | View |
| **AWS Budgets** | Set thresholds → get alerts / actions | Proactive |
| **CloudWatch Billing Alarm** | Alarm when estimated charges exceed $X | Proactive |
| **Cost Explorer** | Visualize/analyze/forecast spend | Analyze |
| **Cost & Usage Report (CUR)** | Most detailed line-item data → S3 | Deep analysis |
| **Free Tier tracker** | Watch free usage limits | Proactive |
| **Cost Allocation Tags** | Attribute cost to teams/projects | Organize |
| **Pricing Calculator** | Estimate cost *before* you build | Plan |

---

## 1. The Billing Dashboard

Found at **Console → Billing & Cost Management**. Key sections:

- **Summary / Bills** — Month-to-date spend, forecast, and a breakdown by **service** and **Region**.
- **Payments & invoices** — payment methods and downloadable invoices.
- **Free Tier** — track how much of each free allowance you've used.
- **Credits** — apply promo codes.
- **Billing preferences** — enable billing alerts, set PDF invoices, configure alert emails.

🛠️ **Do this now:** Billing → **Billing preferences** → enable **"Receive AWS Free Tier alerts"** and **"Receive Billing Alerts."**

---

## 2. AWS Budgets (your #1 safety net) 💰

A **Budget** lets you set a cost or usage limit and get alerted (or even take automatic action) when you approach/exceed it.

**Budget types:**
- **Cost budget** — "alert me if I'm going to spend more than $X."
- **Usage budget** — "alert me if I use more than N hours/GB."
- **RI/Savings Plans budgets** — track reservation utilization/coverage.

🛠️ **Create a cost budget:**
1. Billing → **Budgets → Create budget**.
2. Choose **Cost budget**.
3. Set amount (e.g., **$5/month** for learning).
4. Add **alert thresholds** at 50%, 80%, 100% of budget (and a forecasted-to-exceed alert).
5. Add your **email** (or an SNS topic) as the recipient.

💡 You can also configure **budget actions** (e.g., apply a restrictive IAM policy or stop instances) when a threshold is hit — useful for hard cost control.

---

## 3. CloudWatch Billing Alarm

A classic, simple alarm on the `EstimatedCharges` metric.

🛠️ **Steps:**
1. Switch Region to **US East (N. Virginia) `us-east-1`** — billing metrics are published there.
2. CloudWatch → **Alarms → Create alarm**.
3. Select metric: **Billing → Total Estimated Charges → USD**.
4. Condition: **Greater than** e.g. **5** (USD).
5. Create an **SNS topic**, subscribe your email, confirm the subscription email.
6. Finish — you'll get an email if estimated charges cross the threshold.

💡 **Budgets vs Billing Alarm:** Budgets are newer, more flexible (usage, coverage, actions). The CloudWatch alarm is the original simple email trigger. For beginners, a **Budget** is enough.

---

## 4. Cost Explorer (analyze & forecast)

**Console → Billing & Cost Management → Cost Explorer.**

What you can do:
- View **up to 13 months** of history; **forecast up to 12 months** ahead.
- **Group by:** Service, Region, Linked Account, Instance Type, Usage Type, **Tag**.
- **Filter** to isolate a team, environment, or service.
- See **Savings Plans / Reserved Instance recommendations**.
- See **rightsizing recommendations** (e.g., underused EC2 to downsize/terminate).

**Typical investigation:** Bill spiked? → Open Cost Explorer → Group by **Service** (find the culprit) → Group by **Region** (find where) → drill into **Usage Type** → fix the resource.

---

## 5. Cost & Usage Report (CUR)

The **most granular** billing data — every line item, hourly/daily, delivered to an **S3 bucket** for analysis (e.g., with Amazon Athena or QuickSight).

Use when: you need detailed chargeback/showback, FinOps analysis, or custom dashboards beyond what Cost Explorer shows.

---

## 6. Cost Allocation Tags

**Tags** are key-value labels on resources (e.g., `Team=Marketing`, `Env=Prod`, `Project=Apollo`).

- Activate **cost allocation tags** in Billing → Cost allocation tags.
- Then filter/group by them in Cost Explorer and Budgets.
- Enables **showback/chargeback** — knowing exactly which team/project spends what.

💡 **Best practice:** Define a tagging standard early (e.g., every resource gets `Env`, `Owner`, `Project`).

---

## 7. AWS Pricing Calculator (plan before you build)

https://calculator.aws/ — estimate monthly cost of a proposed architecture **before** deploying. Add services, set usage, get a shareable estimate. Great for proposals and budgeting.

---

## 8. Understanding Consolidated Billing (Organizations)

With **AWS Organizations**, the **management account** receives **one consolidated bill** for all member accounts:
- Single payment method and invoice.
- **Combined usage** pushes you into **volume discount tiers** faster.
- **Shared Reserved Instances / Savings Plans** benefits across accounts.
- Per-account cost visibility is retained (you can still see each account's spend).

---

## 9. Quick Cost-Saving Checklist 💰

```
[ ] Set an AWS Budget with email alerts (day one)
[ ] Stop/terminate EC2 instances when not in use
[ ] Release unattached Elastic IPs (they cost money when idle)
[ ] Delete unused EBS volumes & old snapshots
[ ] Delete unused NAT Gateways (they bill per hour + data)
[ ] Use Free Tier eligible resources while learning
[ ] Choose the cheapest suitable Region
[ ] Use Spot for interruptible workloads (up to ~90% off)
[ ] Use Savings Plans/Reserved for steady workloads (up to ~72% off)
[ ] Right-size with Cost Explorer recommendations
[ ] Turn on S3 lifecycle rules to move/expire old data
[ ] Tag everything for cost visibility
```

---

## 10. Reading Your First Bill (example)

```
   AWS Bill — June 2026 (example)
   Service                 Region        Cost
   ----------------------------------------------
   Amazon EC2              ap-south-1    $0.00  (Free Tier: 750 hrs t2.micro)
   Amazon S3              ap-south-1    $0.00  (Free Tier: <5 GB)
   AWS Lambda             ap-south-1    $0.00  (Always Free)
   Data Transfer OUT      -             $0.12  (small overage)
   ----------------------------------------------
   TOTAL                                 $0.12
```
⚠️ Watch **Data Transfer OUT** and any resource left running — these are the usual sources of small surprise charges while learning.

---

➡️ Next: [07-100-mcqs.md](07-100-mcqs.md)

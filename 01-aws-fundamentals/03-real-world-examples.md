# Module 3 — Real World Examples

> Concrete, relatable scenarios that map each fundamental concept to something a business actually does. Great for interviews ("give me an example...").

---

## 1. Cloud Computing — The Startup That Couldn't Afford Servers

**Scenario:** A 3-person startup wants to launch a food-delivery app. Buying servers would cost ₹15–20 lakh up front plus a server room.

**Cloud solution:** They open an AWS account, launch on the Free Tier, and pay only as users arrive. Launch cost: ~$0. When the app goes viral, they scale from 1 server to 50 automatically; when demand drops at night, they scale back down.

**Concept shown:** CapEx → OpEx, elasticity, "stop guessing capacity," go global in minutes.

---

## 2. Traditional vs Cloud — Retailer on Black Friday / Diwali Sale

**Traditional:** A retailer buys enough servers to handle peak Diwali traffic. Those servers sit 90% idle the other 11 months — wasted money. If they under-buy, the site crashes during the sale.

**Cloud:** The same retailer runs a small baseline year-round and uses **Auto Scaling** to add hundreds of servers for 48 hours during the sale, then removes them. Pays for peak capacity only when needed.

**Concept shown:** Elasticity, pay-as-you-go, no over/under-provisioning.

---

## 3. IaaS — Lift-and-Shift of a Legacy ERP

**Scenario:** A manufacturing company has an old ERP system on physical Windows servers nearing end of life.

**IaaS solution:** They recreate the same Windows servers as **EC2 instances** (IaaS), copy the app over, and keep full control of the OS and software. No code rewrite needed.

**Concept shown:** IaaS gives maximum control — perfect for moving existing apps as-is.

---

## 4. PaaS — Developer Ships a Web App Without Touching Servers

**Scenario:** A solo developer builds a Python web app and wants it live without managing OS patches or scaling.

**PaaS solution:** They push code to **AWS Elastic Beanstalk** (or use **AWS Lambda** for functions). AWS provisions servers, load balancing, scaling, and patching automatically. The developer focuses only on code.

**Concept shown:** PaaS removes infrastructure management.

---

## 5. SaaS — Company Adopts Email & CRM

**Scenario:** A consulting firm needs email and a sales CRM but has no IT team.

**SaaS solution:** They subscribe to **Microsoft 365** (email) and **Salesforce** (CRM). They just log in and use them — no servers, no installs, no patching.

**Concept shown:** SaaS = finished software, zero infrastructure responsibility.

---

## 6. Public Cloud — Mobile Game Goes Global Overnight

**Scenario:** A gaming studio launches a mobile game and hopes for global players.

**Public cloud:** On AWS, they deploy in multiple Regions so players in India, the US, and Europe all get low latency — no need to build data centers abroad.

**Concept shown:** Public cloud + global reach.

---

## 7. Private Cloud — Bank Keeps Core Banking In-House

**Scenario:** A bank's regulator requires customer financial data to stay within strictly controlled, single-tenant infrastructure.

**Private cloud:** The bank runs a **VMware/OpenStack private cloud** (or **AWS Outposts** in its own data center) for the regulated core, retaining full control and isolation.

**Concept shown:** Private cloud for compliance and control.

---

## 8. Hybrid Cloud — Hospital Keeps Records Local, Bursts to Cloud

**Scenario:** A hospital must keep patient records on-premises for compliance but wants cloud power for an AI diagnostics workload.

**Hybrid solution:** Records stay on-prem; the AI training runs on AWS GPU instances. A secure **AWS Direct Connect** link bridges them. Sensitive data stays local; heavy compute happens in the cloud.

**Concept shown:** Hybrid cloud — best of both, connected via Direct Connect/VPN.

---

## 9. Regions — Choosing Where to Deploy

**Scenario:** A European fintech serving EU customers must comply with **GDPR** (data residency in the EU).

**Region choice:** They deploy in `eu-west-1` (Ireland) or `eu-central-1` (Frankfurt) so customer data stays in the EU, and for low latency to European users.

**Concept shown:** Region selection driven by compliance + latency.

---

## 10. Availability Zones — Surviving a Data Center Fire

**Scenario:** An e-commerce site cannot afford downtime.

**Multi-AZ design:** Web servers run in `us-east-1a` and `us-east-1b`; the database uses **RDS Multi-AZ** with a standby in a second AZ. When one AZ has a power failure, traffic and the database fail over to the other AZ automatically. Customers never notice.

**Concept shown:** AZs deliver high availability / fault tolerance.

---

## 11. Edge Locations — Streaming Video Without Buffering

**Scenario:** A video platform's content is stored in the US, but viewers are in India and Brazil.

**CloudFront solution:** **Amazon CloudFront** caches videos at **Edge Locations** near viewers. The first viewer pulls from the US origin; everyone after streams from a nearby edge — fast, no buffering, and lower data-transfer cost from the origin.

**Concept shown:** Edge Locations + CDN for low-latency global delivery.

---

## 12. Shared Responsibility — Who's at Fault for a Breach?

**Scenario A:** A customer leaves an **S3 bucket public** and data leaks.
→ **Customer's fault** — they misconfigured access ("security IN the cloud").

**Scenario B:** A hard drive in an AWS data center is stolen.
→ **AWS's responsibility** — physical security ("security OF the cloud"). (AWS also destroys decommissioned media to prevent this.)

**Concept shown:** The line between AWS and customer responsibility.

---

## 13. Pricing Models — Matching Purchase Type to Workload

**Scenario:** A media company has three workloads:
- **24/7 website** → **Savings Plan / Reserved Instances** (steady, commit, save up to ~72%).
- **Nightly video rendering** (can restart if interrupted) → **Spot Instances** (save up to ~90%).
- **Occasional ad-hoc analytics** → **On-Demand** (pay only when running).

**Concept shown:** Right pricing model per workload pattern.

---

## 14. Free Tier — Student Learns AWS for Free

**Scenario:** A college student wants to learn AWS but has no budget.

**Free Tier:** They use a t2.micro EC2 (750 hrs/month free for 12 months), 5 GB S3, and always-free Lambda. They set a **$1 Budget alert** to avoid surprises and **stop instances** when not in use.

**Concept shown:** Free Tier for learning + the importance of billing alarms.

---

## 15. AWS Organizations — Enterprise With Many Teams

**Scenario:** A 500-person company has separate dev, test, and prod environments and wants one bill plus guardrails.

**Organizations solution:** They create an organization with OUs for Dev/Test/Prod, separate accounts per environment, **SCPs** to block disabling of logging and to restrict Regions, and **consolidated billing** for one invoice and combined volume discounts.

**Concept shown:** Multi-account governance, SCP guardrails, consolidated billing.

---

## 16. Cost Explorer — Finding the Mystery $4,000

**Scenario:** A company's AWS bill jumped unexpectedly.

**Cost Explorer:** They open Cost Explorer, group by service and Region, and discover an engineer left a large GPU instance running in an unused Region. They terminate it and set a **Budget alert** to catch it next time.

**Concept shown:** Cost Explorer for analysis; Budgets for prevention.

---

## 17. End-to-End — A SaaS Company on AWS (ties it together)

A B2B SaaS company:
- Uses **public cloud** (AWS) across 3 **Regions** for global customers.
- Runs each Region across 3 **AZs** for high availability.
- Serves the dashboard via **CloudFront edge locations** for speed.
- Splits AWS accounts (dev/stage/prod) under **Organizations** with **SCP** guardrails and **consolidated billing**.
- Buys **Savings Plans** for steady load, **Spot** for batch jobs.
- Watches spend with **Cost Explorer** + **Budgets**, and secures its side per the **Shared Responsibility Model** (IAM, encryption, Security Groups).

**Concept shown:** How all fundamentals combine in a real architecture.

---

➡️ Next: [04-cloud-migration-examples.md](04-cloud-migration-examples.md)

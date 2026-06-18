# Module 14 — Mini Projects

> Apply everything you've learned. Each project lists the **goal, services, architecture, steps, learning outcomes, and cost notes**. Build at least one end-to-end and document it (great for your résumé/portfolio). All target **Free Tier** where possible. ⚠️ Always clean up.

---

## Project 1 — Personal Static Portfolio Website (Beginner)

**Goal:** Host your own portfolio/résumé website on AWS with a CDN.

**Concepts used:** S3 (storage), CloudFront (edge/CDN), Region selection, Shared Responsibility (public access), billing awareness.

**Architecture:**
```
   Users ---> CloudFront (edge cache) ---> S3 bucket (static site origin)
                     |
               (optional) Route 53 custom domain + ACM HTTPS cert
```

**Steps:**
1. Build a simple HTML/CSS portfolio (`index.html`, `style.css`).
2. Create an S3 bucket; upload files; enable static website hosting.
3. Put **CloudFront** in front for global low latency + HTTPS.
4. (Optional) Register a domain in **Route 53** and add a free **ACM** TLS certificate.
5. Add tags (`Project=Portfolio`).

**Learning outcomes:** S3 hosting, CDN delivery, HTTPS, DNS basics, cost control.
**Cost:** Mostly Free Tier. ⚠️ Delete CloudFront + bucket when done if just practicing.

---

## Project 2 — Highly Available Web App (Intermediate)

**Goal:** Deploy a web app that survives an AZ failure and scales with load.

**Concepts used:** EC2, Multi-AZ, Auto Scaling, Load Balancer, Security Groups, high availability.

**Architecture:**
```
        Users ---> Application Load Balancer (public)
                          |
        +-----------------+-----------------+
      AZ-a                                AZ-b
   [EC2 web]   <-- Auto Scaling group -->  [EC2 web]
        \______________ shared ______________/
                          |
                  (optional) RDS Multi-AZ
```

**Steps:**
1. Create a launch template (Amazon Linux + httpd user-data installing a web page).
2. Create an **Auto Scaling group** across 2 AZs (min 2, max 4).
3. Put an **Application Load Balancer** in front; register the ASG as a target group.
4. Test: open the ALB DNS name; refresh to see different instances respond.
5. Simulate failure: terminate one instance and watch ASG replace it; traffic continues.

**Learning outcomes:** High availability, elasticity, load balancing, self-healing.
**Cost:** t2.micro Free Tier (watch hours with 2+ instances + ALB hourly cost). 💰
⚠️ **Cleanup:** Delete ALB, ASG, launch template, instances.

---

## Project 3 — Cost Monitoring & Governance Dashboard (Intermediate)

**Goal:** Build a cost-control setup any company would want.

**Concepts used:** Budgets, Cost Explorer, billing alarms, tagging, (optional) Organizations + SCP.

**Steps:**
1. Create multiple **Budgets**: total monthly, plus per-service (e.g., EC2).
2. Configure **alerts** (50/80/100%) + a forecasted-overspend alert.
3. Define and apply a **tagging standard** (`Env`, `Owner`, `Project`); activate cost allocation tags.
4. In **Cost Explorer**, build saved views grouped by service, Region, and tag.
5. (Optional) In **Organizations**, create an OU and an **SCP** that restricts usage to approved Regions.

**Learning outcomes:** FinOps basics, proactive cost governance, tagging, guardrails.
**Cost:** $0 (these tools are free).

---

## Project 4 — Secure Multi-Account Landing Zone (Advanced concept)

**Goal:** Design (and partially build) an enterprise-style multi-account setup.

**Concepts used:** Organizations, OUs, SCPs, consolidated billing, IAM, least privilege.

**Architecture:**
```
            Management Account (billing + org root)
                          |
        +-----------------+------------------+
     OU: Security        OU: Workloads      OU: Sandbox
        |                   |                   |
   [Log/Audit acct]   [Prod] [Dev] accts   [Sandbox acct]
   SCP guardrails applied per OU; consolidated billing at top.
```

**Steps:**
1. Create an organization; design OUs (Security, Workloads, Sandbox).
2. Write **SCPs**: deny disabling CloudTrail, restrict Regions, deny root actions.
3. Plan IAM strategy (admin via IAM Identity Center / least privilege roles).
4. Document consolidated billing benefits and the security baseline.
5. (Build the parts you can safely; design the rest on paper.)

**Learning outcomes:** Enterprise governance, account isolation, guardrails, blast-radius thinking.
**Cost:** $0 for Organizations; be careful applying SCPs.

---

## Project 5 — Serverless Visitor Counter API (Intermediate, cloud-native)

**Goal:** Build a fully serverless mini app to feel PaaS/serverless.

**Concepts used:** Lambda, API Gateway, DynamoDB (all largely "always free"), IAM roles.

**Architecture:**
```
   Browser ---> API Gateway ---> Lambda ---> DynamoDB (counter)
                                    ^
                              IAM role (least privilege)
```

**Steps:**
1. Create a **DynamoDB** table `Visitors` (partition key `id`).
2. Write a **Lambda** function (Python/Node) that increments and returns the count.
3. Give Lambda an **IAM role** with DynamoDB access only (least privilege).
4. Expose it via **API Gateway** (HTTP API).
5. Call the endpoint from a webpage (e.g., your Project 1 portfolio) to show live visits.

**Learning outcomes:** Serverless architecture, pay-per-request, no servers to manage, IAM roles.
**Cost:** Largely Always-Free tier. 💰 Minimal.
⚠️ **Cleanup:** Delete API, Lambda, DynamoDB table.

---

## Project 6 — Cloud Migration Plan (Documentation / Design)

**Goal:** Produce a professional migration plan (no AWS spend — pure architecture skill).

**Concepts used:** 7 Rs, migration phases, hybrid connectivity, cost estimation, Well-Architected.

**Deliverable (write a document):**
1. Pick a fictional company (e.g., on-prem e-commerce with a web app + MySQL + file server).
2. Inventory workloads; assign a **migration strategy (7 Rs)** to each.
3. Choose target AWS services (EC2/RDS/S3/CloudFront) and Regions (justify by latency/compliance).
4. Design a **phased plan** (Assess → Mobilize → Migrate) with waves.
5. Add **hybrid connectivity** (Direct Connect/VPN) for the transition.
6. Estimate cost with the **AWS Pricing Calculator**.
7. Map decisions to **Well-Architected pillars**.

**Learning outcomes:** End-to-end migration thinking — exactly what architects/interviews ask for.
**Cost:** $0.

---

## 🏆 Portfolio Tips
- Document each project with a **README**: problem, architecture diagram, services, steps, what you learned, screenshots.
- Push to GitHub; link from your résumé/LinkedIn.
- Be ready to **explain trade-offs** (why Multi-AZ, why Spot vs On-Demand, why this Region).

## 🧹 Always Clean Up
After every project, run the **Master Cleanup Checklist** from [13-hands-on-exercises.md](13-hands-on-exercises.md) and verify the Billing Dashboard trends to ~$0.

---

🎉 **Congratulations!** You've completed the AWS Fundamentals learning repository. Next steps:
- Take the **AWS Certified Cloud Practitioner** exam (see [11-certification-notes.md](11-certification-notes.md)).
- Move toward **Solutions Architect – Associate**.
- Keep building. The cloud rewards hands-on practice. 🚀

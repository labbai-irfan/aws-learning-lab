# Module 9 — 50 Scenario-Based Questions (with Answers)

> Real-world "what would you do" questions, like the AWS Cloud Practitioner exam and architecture interviews. Read the scenario, decide, then check the **Answer & Reasoning**.

---

**1.** A startup expects unpredictable, spiky traffic and has no budget for hardware. Which approach fits best?
**Answer:** Public cloud (AWS) with pay-as-you-go and Auto Scaling. *Reasoning:* No upfront cost, scales with demand, no capacity guessing.

**2.** A retailer's website crashes every festival sale due to traffic spikes. What's the cloud solution?
**Answer:** Auto Scaling across multiple AZs behind a load balancer. *Reasoning:* Elastically add capacity for the spike, remove it after.

**3.** A bank must keep core customer data in single-tenant, tightly controlled infrastructure for compliance. Which model?
**Answer:** Private cloud (possibly AWS Outposts). *Reasoning:* Compliance/isolation requirements favor single-tenant/on-prem.

**4.** A hospital needs records on-prem (compliance) but wants cloud GPUs for AI. Which model and connection?
**Answer:** Hybrid cloud via Direct Connect (or VPN). *Reasoning:* Keep sensitive data local, burst compute to cloud over a secure link.

**5.** A team wants to run an existing app on AWS quickly without rewriting it. Which service/strategy?
**Answer:** Rehost (lift & shift) onto EC2 (IaaS). *Reasoning:* Fastest move, full OS control, no code changes.

**6.** A developer wants to deploy code without managing servers or scaling. Best fit?
**Answer:** PaaS/serverless — Elastic Beanstalk or Lambda. *Reasoning:* AWS handles infra, scaling, patching.

**7.** A company wants email and CRM with zero infrastructure management. Which model?
**Answer:** SaaS (e.g., Microsoft 365, Salesforce). *Reasoning:* Finished software, just log in and use.

**8.** A global SaaS wants low latency for users in India, US, and Europe. What do you do?
**Answer:** Deploy in multiple Regions and use CloudFront for edge caching. *Reasoning:* Proximity + CDN reduces latency.

**9.** An app must survive a single data-center failure with no downtime. Design?
**Answer:** Deploy across multiple AZs with a Multi-AZ database. *Reasoning:* AZ isolation provides high availability.

**10.** A company must survive an entire Region outage. Design?
**Answer:** Multi-Region architecture with cross-Region replication/DR. *Reasoning:* Regions are isolated; survive a Region failure with another Region.

**11.** A European fintech must keep EU citizen data in the EU. What governs your Region choice?
**Answer:** Compliance/data residency (GDPR) → choose an EU Region. *Reasoning:* Legal requirement overrides cost.

**12.** Video streaming buffers for overseas users. Fix?
**Answer:** Use CloudFront to cache content at edge locations near users. *Reasoning:* Serve from nearby edge, not distant origin.

**13.** An engineer accidentally made an S3 bucket public and data leaked. Whose responsibility?
**Answer:** The customer's (security IN the cloud). *Reasoning:* Misconfiguration of access controls is the customer's job.

**14.** A drive in an AWS data center fails/is stolen. Whose responsibility?
**Answer:** AWS's (security OF the cloud). *Reasoning:* Physical security and media destruction are AWS's responsibility.

**15.** A nightly video-rendering job can restart if interrupted. Cheapest EC2 option?
**Answer:** Spot Instances. *Reasoning:* Up to ~90% savings; interruptions are acceptable for restartable jobs.

**16.** A 24/7 production database server runs constantly for years. Cost optimization?
**Answer:** Reserved Instances or Savings Plans (1- or 3-year). *Reasoning:* Steady usage → commit for up to ~72% savings.

**17.** A workload is short-lived and unpredictable; you don't want commitment. Option?
**Answer:** On-Demand. *Reasoning:* Pay per use, no commitment, ideal for spiky/unknown duration.

**18.** Software licensing requires a dedicated physical server (per-socket). Option?
**Answer:** Dedicated Hosts. *Reasoning:* Provides visibility/control of physical sockets for licensing/compliance.

**19.** A student wants to learn AWS at minimal cost. What should they use and set up?
**Answer:** Free Tier resources + a Budget/billing alarm; stop instances when idle. *Reasoning:* Learn cheaply while avoiding surprise bills.

**20.** Your AWS bill spiked unexpectedly. How do you investigate?
**Answer:** Use Cost Explorer, group by service/Region to find the driver. *Reasoning:* Cost Explorer visualizes and isolates cost sources.

**21.** You want to be alerted before spending exceeds $50/month. Tool?
**Answer:** AWS Budgets with alert thresholds (or a CloudWatch billing alarm). *Reasoning:* Proactive threshold alerts.

**22.** A 500-person company wants one bill and guardrails across dev/test/prod accounts. Solution?
**Answer:** AWS Organizations with OUs, SCPs, and consolidated billing. *Reasoning:* Central governance + combined billing/discounts.

**23.** You must ensure no member account can disable CloudTrail logging. How?
**Answer:** Apply a Service Control Policy (SCP) denying that action. *Reasoning:* SCP guardrails set maximum permissions.

**24.** A new account is created. What are the first security steps?
**Answer:** Enable MFA on root, create an admin IAM user, stop using root, set least privilege, enable billing alerts. *Reasoning:* Standard secure baseline.

**25.** Multiple developers need AWS access. Best practice?
**Answer:** Individual IAM users in groups with least-privilege policies + MFA. *Reasoning:* Avoid shared root; enforce least privilege.

**26.** An EC2 instance needs to read from an S3 bucket securely. How grant access?
**Answer:** Attach an IAM role to the instance. *Reasoning:* Roles give temporary credentials — no hard-coded keys.

**27.** You want combined volume discounts across many accounts. How?
**Answer:** Consolidated billing via AWS Organizations. *Reasoning:* Aggregated usage reaches discount tiers faster.

**28.** A company wants to estimate monthly cost of a planned architecture before building. Tool?
**Answer:** AWS Pricing Calculator. *Reasoning:* Estimates cost pre-deployment.

**29.** Finance wants to know which team spends what on AWS. How?
**Answer:** Cost allocation tags + Cost Explorer grouping by tag. *Reasoning:* Tags enable showback/chargeback.

**30.** A workload's EC2 instances are heavily underutilized. How to save money?
**Answer:** Rightsize using Cost Explorer rightsizing recommendations (downsize/terminate). *Reasoning:* Match instance size to real need.

**31.** A legacy app can't move yet due to dependencies. Migration strategy?
**Answer:** Retain (keep on-prem for now). *Reasoning:* Not all workloads are ready; revisit later.

**32.** An old internal tool is no longer used. Migration strategy?
**Answer:** Retire (decommission). *Reasoning:* Stop paying to run/move unneeded systems.

**33.** A self-managed database on EC2 is too much maintenance. Strategy?
**Answer:** Replatform to Amazon RDS. *Reasoning:* Managed service reduces ops with minimal app change.

**34.** A monolith needs to scale to millions and minimize idle cost long term. Strategy?
**Answer:** Refactor/re-architect to serverless (API Gateway + Lambda + DynamoDB). *Reasoning:* Cloud-native scales to zero and to massive demand.

**35.** A company wants to swap its on-prem CRM for a cloud product. Strategy?
**Answer:** Repurchase (drop & shop) → move to SaaS (e.g., Salesforce). *Reasoning:* Replace rather than migrate.

**36.** You must move 200 TB of data to AWS but have limited bandwidth. Tool?
**Answer:** AWS Snowball (physical device). *Reasoning:* Faster/cheaper than network transfer for huge datasets.

**37.** You need to migrate a database to AWS with minimal downtime. Tool?
**Answer:** AWS Database Migration Service (DMS). *Reasoning:* Continuous replication minimizes downtime.

**38.** An app needs a globally fast DNS with health-based routing. Service?
**Answer:** Amazon Route 53. *Reasoning:* Global DNS with routing policies and health checks.

**39.** You want to reduce latency and offload traffic from your origin servers. Service?
**Answer:** Amazon CloudFront (CDN). *Reasoning:* Edge caching reduces latency and origin load.

**40.** A media company has steady web traffic plus interruptible batch jobs. Pricing mix?
**Answer:** Savings Plans/RIs for the steady web tier + Spot for batch. *Reasoning:* Match pricing model to each workload pattern.

**41.** A team forgot to stop a large EC2 instance over the weekend, causing charges. Prevention?
**Answer:** Budgets/billing alarms + instance scheduling/auto-stop + tagging. *Reasoning:* Proactive alerts and automation prevent waste.

**42.** Data transfer costs are unexpectedly high. Likely cause and fix?
**Answer:** High outbound data transfer; reduce with CloudFront caching and architecture review. *Reasoning:* Outbound transfer is billed; caching cuts it.

**43.** A compliance team needs the most detailed line-item billing data for analysis. Tool?
**Answer:** Cost & Usage Report (CUR) delivered to S3. *Reasoning:* CUR is the most granular billing dataset.

**44.** You want to apply different guardrails to Prod vs Dev accounts. How?
**Answer:** Put them in separate OUs and attach different SCPs. *Reasoning:* OUs enable targeted policy application.

**45.** A web app needs to scale out automatically during the day and in at night. Service?
**Answer:** EC2 Auto Scaling (with a load balancer). *Reasoning:* Automatic horizontal scaling to match demand.

**46.** A company is unsure which Region is cheapest for a new workload. What do they consider?
**Answer:** Compare Region pricing, but also latency, compliance, and service availability. *Reasoning:* Cost is one of four selection factors.

**47.** You need temporary cross-account access for an auditor. Mechanism?
**Answer:** An IAM role the auditor's account can assume. *Reasoning:* Roles provide temporary, scoped cross-account access.

**48.** Management wants to forecast next quarter's AWS spend. Tool?
**Answer:** Cost Explorer (forecasting). *Reasoning:* It projects future spend from trends.

**49.** A SaaS product must isolate the "blast radius" if one environment is compromised. Design?
**Answer:** Separate AWS accounts per environment under Organizations. *Reasoning:* Account boundaries contain incidents.

**50.** A beginner asks the single most important thing to do on day one. Your answer?
**Answer:** Enable MFA on the root user and set up a billing budget/alarm. *Reasoning:* Security + cost protection are the two highest-impact first actions.

---

➡️ Next: [10-revision-notes.md](10-revision-notes.md)

# Module 8 — 100 Interview Questions (with Model Answers)

> Concise, interview-ready answers. Each is what you'd actually say out loud — clear and confident. Grouped by topic.

---

## Cloud Computing Basics (1–15)

**1. What is cloud computing?**
On-demand delivery of IT resources (compute, storage, databases, networking) over the internet with pay-as-you-go pricing, instead of owning physical infrastructure.

**2. Name the six advantages of cloud computing.**
Trade CapEx for variable expense; benefit from economies of scale; stop guessing capacity; increase speed/agility; stop spending on running data centers; go global in minutes.

**3. What does pay-as-you-go mean?**
You pay only for the resources you actually consume, with no large upfront cost or long-term lock-in required.

**4. Define elasticity.**
The ability to automatically scale resources up or down to match demand, so you neither over-pay nor run short.

**5. Difference between scalability and elasticity?**
Scalability is the capability to grow (handle more load); elasticity is doing it automatically and bidirectionally in real time with demand.

**6. What is the difference between CapEx and OpEx in cloud terms?**
CapEx is large upfront capital spend on hardware; OpEx is ongoing operational, usage-based spend. Cloud shifts CapEx to OpEx.

**7. What are the five characteristics of cloud (NIST)?**
On-demand self-service, broad network access, resource pooling, rapid elasticity, measured service.

**8. What is multi-tenancy?**
Multiple customers securely share the same pooled physical infrastructure, isolated from each other.

**9. What is high availability?**
Designing systems to remain operational despite failures, e.g., spreading across multiple Availability Zones.

**10. What is fault tolerance?**
The ability of a system to keep working correctly even when components fail, often via redundancy.

**11. Why is agility a key cloud benefit?**
You can provision resources in minutes and experiment cheaply, accelerating innovation and time-to-market.

**12. How does cloud reduce capacity guessing?**
Auto Scaling and on-demand provisioning let you match capacity to actual demand instead of buying ahead.

**13. What is the difference between vertical and horizontal scaling?**
Vertical = bigger instance (scale up); horizontal = more instances (scale out). Cloud favors horizontal scaling.

**14. Give an example where cloud saves money over on-prem.**
Seasonal traffic (e.g., a sale): scale up for the peak and down afterward, paying only for what you use rather than buying for peak year-round.

**15. What is a CDN and why use one?**
A Content Delivery Network (e.g., CloudFront) caches content at edge locations near users to reduce latency and origin load.

---

## Traditional vs Cloud (16–22)

**16. Compare on-prem vs cloud provisioning time.**
On-prem takes weeks/months (procure, rack, configure); cloud takes minutes via console/API.

**17. What are downsides of on-premises infrastructure?**
High upfront cost, slow scaling, capacity guessing, maintenance burden, harder DR and global reach.

**18. When might on-premises still be preferred?**
Strict regulatory/data-residency needs, ultra-low-latency local requirements, or large existing investments not yet amortized.

**19. What is "lift and shift"?**
Migrating an application to the cloud as-is (rehosting) without redesigning it.

**20. How does cloud improve disaster recovery?**
You can replicate across AZs/Regions cost-effectively and pay only for DR resources as used, rather than building a second physical site.

**21. What is the main financial shift moving to cloud?**
From large upfront capital expense to smaller, usage-based operational expense.

**22. Why is "stop maintaining data centers" valuable?**
Teams focus on product/innovation instead of power, cooling, racking, and hardware refresh cycles.

---

## IaaS / PaaS / SaaS (23–35)

**23. Explain IaaS, PaaS, SaaS.**
IaaS = raw infrastructure (EC2, you manage OS+up); PaaS = managed platform (Beanstalk/Lambda, you manage app+data); SaaS = finished software (Gmail, you just use it).

**24. Which model gives the most control? The least?**
IaaS gives the most control and responsibility; SaaS the least of both.

**25. Give AWS examples of each model.**
IaaS: EC2, VPC, EBS. PaaS: Elastic Beanstalk, Lambda, RDS. SaaS: Amazon Chime, WorkMail.

**26. In PaaS, what does the customer manage?**
Only their application and data; AWS manages OS, runtime, scaling, and patching.

**27. Why choose PaaS over IaaS?**
Less operational overhead and faster delivery when you don't need OS-level control.

**28. Is Amazon RDS IaaS or PaaS?**
PaaS-like managed service — AWS handles the engine, patching, backups, and failover; you manage data and access.

**29. Is AWS Lambda IaaS or PaaS?**
PaaS/FaaS (serverless) — you provide code; AWS handles all infrastructure and scaling.

**30. How does responsibility change across the models?**
Moving IaaS → PaaS → SaaS, the customer's responsibility (and control) decreases as AWS manages more.

**31. What is serverless?**
A model where you run code/functions without managing servers; you pay per execution and it scales automatically (e.g., Lambda).

**32. When would you pick SaaS?**
When you want finished functionality with zero infrastructure management (email, CRM, collaboration).

**33. What is FaaS?**
Function as a Service — event-driven functions (Lambda) that run on demand; a subset of serverless/PaaS.

**34. Example of replatforming?**
Moving a self-managed database on EC2 to managed Amazon RDS with minimal app changes.

**35. Trade-off between control and convenience?**
More control (IaaS) means more management work; more convenience (SaaS) means less control but less effort.

---

## Deployment Models (36–43)

**36. Define public, private, and hybrid cloud.**
Public = shared third-party provider (AWS); private = dedicated to one org; hybrid = public + private/on-prem working together.

**37. When is private cloud appropriate?**
Strict compliance/regulatory or data-control needs requiring single-tenant, often on-prem, infrastructure.

**38. What is hybrid cloud good for?**
Keeping sensitive data local while using cloud for scale, gradual migration, or DR.

**39. How do you connect on-prem to AWS?**
AWS Direct Connect (dedicated private link) or Site-to-Site VPN (encrypted tunnel over the internet).

**40. What is AWS Outposts?**
AWS-managed hardware running in your own data center, extending AWS services on-prem (hybrid/private).

**41. Direct Connect vs VPN?**
Direct Connect is private, consistent, low-latency (and pricier); VPN is quick and encrypted over the public internet (cheaper, variable).

**42. Advantage of public cloud?**
Near-unlimited elastic scale, no hardware to buy, fast global deployment, pay-as-you-go.

**43. What is a community cloud?**
Infrastructure shared by organizations with common concerns (e.g., compliance), less common than public/private/hybrid.

---

## Global Infrastructure (44–62)

**44. What is an AWS Region?**
An isolated geographic area containing multiple Availability Zones.

**45. What is an Availability Zone?**
One or more discrete data centers with independent power, cooling, and networking within a Region.

**46. Why deploy across multiple AZs?**
For high availability — if one AZ fails, the app continues from another.

**47. What is an Edge Location?**
A site (more numerous than Regions) used to cache content close to users for low latency, used by CloudFront and Route 53.

**48. How do you choose a Region?**
By latency to users, compliance/data residency, service availability, and pricing.

**49. Are Regions isolated from each other?**
Yes — each Region is independent; data doesn't auto-replicate across Regions unless you configure it.

**50. Name some global AWS services.**
IAM, Route 53, CloudFront, AWS WAF — they aren't tied to a single Region.

**51. What is CloudFront?**
AWS's CDN that caches and delivers content from edge locations near users.

**52. What is Route 53?**
A scalable DNS and domain registration service that routes users to endpoints, often with health checks and routing policies.

**53. What does RDS Multi-AZ provide?**
A synchronous standby in another AZ with automatic failover for high availability.

**54. Multi-AZ vs Multi-Region?**
Multi-AZ = high availability within a Region; Multi-Region = disaster recovery and global reach across geographies.

**55. What is a Regional Edge Cache?**
A larger cache between edge locations and the origin for content too big or infrequent for edge caches.

**56. How does AWS achieve low latency globally?**
By placing Regions worldwide and caching at hundreds of edge locations via CloudFront.

**57. Why are AZ identifiers randomized per account?**
So load is balanced across physical AZs and `us-east-1a` doesn't map to the same physical AZ for everyone.

**58. What is AWS Global Accelerator?**
A service that routes user traffic over the AWS backbone to the optimal endpoint, improving performance/availability.

**59. What is data residency and why does it matter?**
The requirement to keep data within a geographic boundary (e.g., GDPR); it dictates Region choice.

**60. How are AZs connected within a Region?**
By redundant, high-bandwidth, low-latency private fiber links.

**61. What's the order of size: Region, AZ, Data Center?**
Region > Availability Zone > Data Center.

**62. How would you make a web app highly available?**
Run instances across multiple AZs behind a load balancer with Auto Scaling, and use a Multi-AZ database.

---

## Shared Responsibility Model (63–72)

**63. Explain the Shared Responsibility Model.**
AWS secures the cloud (hardware, facilities, infrastructure); the customer secures what's in the cloud (data, IAM, config, OS for IaaS).

**64. Give the one-line memory aid.**
AWS = security OF the cloud; customer = security IN the cloud.

**65. Who patches the OS on EC2 vs RDS?**
On EC2, the customer; on RDS (managed), AWS patches the engine/OS.

**66. What is always the customer's responsibility?**
Their data and managing IAM access — regardless of service.

**67. Who handles physical security?**
AWS, always.

**68. Whose fault is a public S3 bucket leak?**
The customer's — it's a configuration responsibility.

**69. How does responsibility shift with managed services?**
The more managed the service, the more AWS handles, reducing customer burden (but data and access stay the customer's job).

**70. Who is responsible for encryption?**
The customer chooses and configures encryption; AWS provides the tools (KMS, encryption options).

**71. Who configures Security Groups and NACLs?**
The customer.

**72. How does the model apply to SaaS like Amazon WorkMail?**
AWS manages nearly everything; the customer manages users, access, and their data within the app.

---

## Pricing & Free Tier (73–86)

**73. What EC2 purchasing options exist?**
On-Demand, Reserved Instances, Savings Plans, Spot Instances, Dedicated Hosts.

**74. When use Spot Instances?**
For fault-tolerant, interruptible, time-flexible work (batch, big data) — up to ~90% savings.

**75. When use Reserved Instances or Savings Plans?**
For steady, predictable workloads where a 1- or 3-year commitment yields up to ~72% savings.

**76. Savings Plans vs Reserved Instances?**
Savings Plans commit to a $/hour spend and are more flexible across instance families/Regions; RIs commit to specific instance attributes.

**77. When use On-Demand?**
Short-term, spiky, or unpredictable workloads, or while testing before committing.

**78. When use Dedicated Hosts?**
For per-socket/per-core software licensing or compliance requiring dedicated physical servers.

**79. What are the three main AWS cost drivers?**
Compute, storage, and outbound data transfer.

**80. Is data transfer into AWS charged?**
Generally inbound is free; outbound (and some inter-Region/inter-AZ) transfer is charged.

**81. What are the three Free Tier types?**
12-months free, always free, and short-term trials.

**82. Give an always-free example.**
1M Lambda requests/month and 25 GB DynamoDB storage.

**83. What's a common Free Tier mistake?**
Leaving resources running or exceeding limits, which causes charges; mitigate with budgets/alarms.

**84. How do you estimate costs before building?**
Use the AWS Pricing Calculator.

**85. How do volume discounts work?**
Per-unit price decreases as usage grows (e.g., S3 storage tiers).

**86. How does consolidated billing reduce cost?**
It aggregates usage across accounts so you reach volume-discount tiers and share RIs/Savings Plans.

---

## Accounts, Organizations, Billing Tools (87–100)

**87. What is the root user and how should it be handled?**
The all-powerful account owner identity — enable MFA, use only for tasks that require it, and lock it away.

**88. IAM users vs roles vs groups?**
Users = identities for people/apps; groups = collections of users sharing permissions; roles = temporary, assumable permissions (ideal for services and cross-account).

**89. What is least privilege?**
Granting only the permissions needed to do a task — a core security best practice.

**90. What is AWS Organizations?**
A service to centrally manage multiple AWS accounts with consolidated billing and governance.

**91. What is an OU?**
An Organizational Unit — a folder grouping accounts for applying policies.

**92. What are SCPs?**
Service Control Policies — guardrails that define the maximum permissions for accounts/OUs (they limit, not grant).

**93. Benefits of multiple accounts?**
Blast-radius isolation, clearer billing per environment/team, and easier governance.

**94. What does the Billing Dashboard show?**
Current and forecast spend, invoices, Free Tier usage, and links to Budgets and Cost Explorer.

**95. What is AWS Budgets?**
A tool to set cost/usage thresholds and get alerts (or automated actions) when approaching/exceeding them.

**96. What is Cost Explorer?**
A tool to visualize, analyze, and forecast spend, with RI/Savings Plans and rightsizing recommendations.

**97. Cost Explorer vs Budgets vs CUR?**
Cost Explorer analyzes trends; Budgets proactively alerts/limits; CUR is the most granular line-item data delivered to S3.

**98. What is MFA and why use it?**
Multi-Factor Authentication adds a second verification factor, protecting accounts even if a password leaks.

**99. What are cost allocation tags?**
Key-value labels on resources to attribute costs to teams/projects for showback/chargeback.

**100. What's your day-one checklist for a new AWS account?**
Enable MFA on root, create an admin IAM user, stop using root, set a Budget/billing alarm, enable S3 Block Public Access, and apply least privilege.

---

➡️ Next: [09-50-scenario-questions.md](09-50-scenario-questions.md)

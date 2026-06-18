# Module 12 — Common Mistakes (and How to Avoid Them)

> The pitfalls that trip up beginners — in real accounts AND on the exam. Each has the mistake, why it's wrong, and the fix.

---

## 🔒 Security Mistakes

**1. Using the root user for daily work**
- ❌ Why wrong: Root has unlimited power; one slip can destroy or expose everything.
- ✅ Fix: Lock root away (MFA on), create IAM users/roles with least privilege for daily use.

**2. Not enabling MFA on root**
- ❌ A leaked root password = total account takeover.
- ✅ Enable virtual or hardware MFA on root immediately after sign-up.

**3. Creating access keys for the root user**
- ❌ Root keys are extremely dangerous if leaked.
- ✅ Never create root access keys; use IAM roles for programmatic access.

**4. Granting AdministratorAccess to everyone**
- ❌ Violates least privilege; widens blast radius.
- ✅ Grant only the permissions each role needs; use groups and scoped policies.

**5. Hard-coding AWS credentials in code**
- ❌ Keys end up in Git, leak, and get abused (often causing huge bills).
- ✅ Use IAM roles (for EC2/Lambda) and never commit secrets; use Secrets Manager/SSM.

**6. Leaving S3 buckets public by accident**
- ❌ #1 cause of public data leaks (customer responsibility!).
- ✅ Enable account-level **S3 Block Public Access**; review bucket policies.

---

## 💰 Cost Mistakes

**7. No billing alarm / budget**
- ❌ Surprise bills with no early warning.
- ✅ Set an **AWS Budget** + billing alarm on day one.

**8. Leaving resources running after labs**
- ❌ EC2, RDS, NAT Gateways keep billing 24/7.
- ✅ Stop/terminate instances; delete NAT Gateways; use auto-stop scheduling.

**9. Forgetting unattached Elastic IPs**
- ❌ An allocated but unused Elastic IP is billed.
- ✅ Release Elastic IPs you don't need.

**10. Ignoring data transfer OUT costs**
- ❌ Outbound data transfer adds up silently.
- ✅ Use CloudFront caching; review architecture; remember data **in** is free, **out** is not.

**11. Assuming Free Tier = unlimited**
- ❌ Exceeding limits is billed automatically; no hard cap by default.
- ✅ Track Free Tier usage; set budgets; understand each limit.

**12. Buying Reserved Instances for variable workloads**
- ❌ Commitment wasted if usage isn't steady.
- ✅ Match pricing to workload: On-Demand for variable, Spot for interruptible, RIs/SPs for steady.

**13. Orphaned EBS volumes & old snapshots**
- ❌ Detached volumes and forgotten snapshots keep costing money.
- ✅ Delete unused volumes/snapshots; use lifecycle policies.

---

## 🌐 Architecture & Concept Mistakes

**14. Running everything in a single AZ**
- ❌ One AZ failure = total outage.
- ✅ Spread across multiple AZs; use Multi-AZ databases for high availability.

**15. Confusing Multi-AZ with Multi-Region**
- ❌ Multi-AZ ≠ disaster recovery across geographies.
- ✅ Multi-AZ = HA within a Region; Multi-Region = DR/global reach.

**16. Confusing Regions, AZs, and Edge Locations**
- ❌ Mixing up the hierarchy on the exam.
- ✅ Region (geo area) > AZ (data centers) > Edge (caching POPs, most numerous).

**17. Thinking AWS secures everything**
- ❌ Misreading the Shared Responsibility Model.
- ✅ AWS = OF the cloud; you = IN the cloud (data, IAM, config always yours).

**18. Picking a Region only by price**
- ❌ Ignoring latency/compliance can break the law or UX.
- ✅ Weigh latency, compliance, service availability, AND price.

**19. Confusing service models (IaaS/PaaS/SaaS)**
- ❌ Calling EC2 "SaaS" or Lambda "IaaS."
- ✅ EC2 = IaaS; Beanstalk/Lambda/RDS = PaaS/managed; Gmail/Salesforce = SaaS.

**20. Assuming all services are Regional**
- ❌ Forgetting global services exist.
- ✅ Remember IAM, Route 53, CloudFront, WAF are global.

---

## 🛠️ Operational Mistakes

**21. No tagging strategy**
- ❌ Can't tell which team/project drives cost.
- ✅ Tag everything (`Env`, `Owner`, `Project`); activate cost allocation tags.

**22. Not separating environments**
- ❌ Dev mistakes hit production.
- ✅ Use separate accounts (via Organizations) for dev/test/prod.

**23. Ignoring SCPs / governance**
- ❌ Member accounts do risky things (disable logging, wrong Regions).
- ✅ Apply SCP guardrails at the OU/account level.

**24. Thinking SCPs grant permissions**
- ❌ SCPs only set the **maximum** allowed; they don't grant.
- ✅ Combine SCP guardrails with IAM grants.

**25. Skipping cost analysis tools**
- ❌ Spending blind.
- ✅ Use Cost Explorer to analyze and Budgets to alert.

---

## 📝 Exam-Specific Traps

**26. Misreading "least operational overhead"** → choose **managed/serverless**, not self-managed EC2.

**27. Misreading "most cost-effective for interruptible"** → choose **Spot**, not On-Demand.

**28. Misreading "highly available"** → **multiple AZs**, not a bigger single server.

**29. Confusing Budgets vs Cost Explorer** → Budgets = alert; Cost Explorer = analyze.

**30. Confusing CUR vs Cost Explorer** → CUR = most granular line-item data to S3; Cost Explorer = visual analysis.

---

## ✅ The Golden Rules
1. **Never use root daily; always MFA.**
2. **Set a budget before you build.**
3. **Multi-AZ for availability; Multi-Region for DR.**
4. **Match pricing model to workload.**
5. **Your data and IAM are always your responsibility.**
6. **Tag everything; clean up what you don't use.**

---

➡️ Next: [13-hands-on-exercises.md](13-hands-on-exercises.md)

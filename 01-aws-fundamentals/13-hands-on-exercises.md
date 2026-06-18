# Module 13 — Hands-On Exercises

> Learn by doing. These labs use **Free Tier** resources. 🛠️ = action you perform. 💰 = cost note. ⚠️ = cleanup reminder.

> **Before you start:** Complete [05-aws-account-setup-guide.md](05-aws-account-setup-guide.md) (account + MFA + Budget). **Always clean up** after each lab to avoid charges.

---

## Lab 0 — Explore the Console (15 min)
**Goal:** Get comfortable navigating AWS.
1. 🛠️ Sign in via your **IAM admin user** (not root).
2. 🛠️ Note the **Region selector** (top-right). Switch between two Regions (e.g., Mumbai, N. Virginia) and watch resources change scope.
3. 🛠️ Open the **Services** menu; find EC2, S3, IAM, Billing.
4. 🛠️ Open **Billing & Cost Management** and locate your Budget.

**Outcome:** You can navigate, switch Regions, and find billing.

---

## Lab 1 — Secure Your Account (30 min) 🔒
**Goal:** Apply security best practices.
1. 🛠️ Confirm **MFA is enabled on root** (IAM → root security credentials).
2. 🛠️ Create an IAM **group** `Developers` and attach a read-only policy (e.g., `ReadOnlyAccess`).
3. 🛠️ Create an IAM **user** `dev-test`, add to `Developers`, enable console access.
4. 🛠️ Set an **IAM password policy** (min length, complexity).
5. 🛠️ Turn on **S3 Block Public Access** at the account level.

**Outcome:** Understand IAM users, groups, policies, and least privilege.
⚠️ Cleanup: keep these (no cost) or delete the test user.

---

## Lab 2 — Launch & Connect to an EC2 Instance (45 min) 🛠️
**Goal:** Experience IaaS firsthand.
1. 🛠️ EC2 → **Launch instance**.
2. 🛠️ Name it `lab-web`, choose **Amazon Linux 2023**, instance type **t2.micro / t3.micro** (Free Tier eligible). 💰
3. 🛠️ Create a new **key pair** (download the `.pem`).
4. 🛠️ Security Group: allow **SSH (22)** from *your IP only* and **HTTP (80)** from anywhere.
5. 🛠️ Launch, wait for "running" + status checks.
6. 🛠️ Connect via **EC2 Instance Connect** (browser) or SSH.
7. 🛠️ Install a web server:
   ```bash
   sudo dnf install -y httpd
   sudo systemctl enable --now httpd
   echo "Hello from AWS EC2!" | sudo tee /var/www/html/index.html
   ```
8. 🛠️ Open `http://<public-ip>` in your browser — see your page.

**Outcome:** You launched a virtual server (IaaS), configured a firewall (Security Group), and served a webpage.
⚠️ **Cleanup:** **Terminate** the instance when done. Release any Elastic IP. 💰

---

## Lab 3 — Host a Static Website on S3 (30 min) 🛠️
**Goal:** Use object storage + understand the public-access responsibility.
1. 🛠️ S3 → **Create bucket** (globally unique name, e.g., `yourname-lab-site-2026`).
2. 🛠️ Upload an `index.html` (any HTML).
3. 🛠️ Enable **Static website hosting** (Properties).
4. 🛠️ To make it public for this lab: disable Block Public Access *for this bucket only* and add a bucket policy granting `s3:GetObject` to everyone. ⚠️ (Understand this is a customer responsibility!)
5. 🛠️ Visit the website endpoint URL.

**Outcome:** You understand S3 object storage and why public access must be deliberate.
⚠️ **Cleanup:** Delete objects + bucket; re-enable Block Public Access globally. 💰 (S3 free up to 5 GB.)

---

## Lab 4 — Set Up Billing Protection (20 min) 💰
**Goal:** Never get a surprise bill.
1. 🛠️ Billing → **Budgets → Create budget** → Cost budget → **$5/month**.
2. 🛠️ Add alerts at 50%, 80%, 100% to your email.
3. 🛠️ (Optional) In `us-east-1`, create a **CloudWatch billing alarm** on `EstimatedCharges > $5` with an SNS email subscription (confirm the email).
4. 🛠️ Explore **Free Tier** usage page.

**Outcome:** Proactive cost control configured.

---

## Lab 5 — Explore Costs with Cost Explorer (20 min) 💰
**Goal:** Analyze where money goes.
1. 🛠️ Billing → **Cost Explorer** → enable it (first time).
2. 🛠️ View daily/monthly costs.
3. 🛠️ **Group by Service**, then **by Region**.
4. 🛠️ Apply a **filter** (e.g., by service = EC2).
5. 🛠️ Note any **forecast** and **recommendations**.

**Outcome:** You can investigate and forecast spend.

---

## Lab 6 — IAM Role for EC2 → S3 (40 min) 🔒
**Goal:** Use roles instead of keys.
1. 🛠️ Create an IAM **role** for EC2 with `AmazonS3ReadOnlyAccess`.
2. 🛠️ Launch (or reuse) a t2.micro EC2 and **attach the role**.
3. 🛠️ SSH in and run:
   ```bash
   aws s3 ls
   ```
   It works **without any stored keys** — credentials come from the role.

**Outcome:** You understand why roles are the secure way for services to access AWS.
⚠️ **Cleanup:** Terminate the instance.

---

## Lab 7 — Create a CloudFront Distribution (40 min) 🌐
**Goal:** See edge caching / CDN in action.
1. 🛠️ Use your S3 static site (Lab 3) as the **origin**.
2. 🛠️ CloudFront → **Create distribution** → select the S3 origin.
3. 🛠️ Wait for it to deploy; open the CloudFront domain (`d123...cloudfront.net`).
4. 🛠️ Notice content is served from a nearby **edge location**.

**Outcome:** You experienced a CDN delivering cached content with lower latency.
⚠️ **Cleanup:** Disable then delete the distribution. 💰 (Mostly Free Tier for low usage.)

---

## Lab 8 — Tagging & Cost Allocation (20 min) 💰
**Goal:** Attribute costs.
1. 🛠️ Add tags to a resource: `Env=Lab`, `Owner=YourName`, `Project=Fundamentals`.
2. 🛠️ Billing → **Cost allocation tags** → activate your tag keys.
3. 🛠️ Later, in Cost Explorer, **group by tag**.

**Outcome:** You can track cost by team/project.

---

## Lab 9 (Optional) — AWS Organizations (30 min) 🏛️
**Goal:** See multi-account governance (only if you can create/invite an account).
1. 🛠️ AWS Organizations → **Create organization**.
2. 🛠️ Create an **OU** (e.g., `Sandbox`).
3. 🛠️ (If you have a second account) invite it as a **member**.
4. 🛠️ Explore **Service Control Policies** (e.g., a policy restricting Regions). Review only — apply carefully.

**Outcome:** Understand OUs, SCPs, and consolidated billing.
⚠️ Be cautious applying SCPs — they can block actions.

---

## 🧹 Master Cleanup Checklist (run after every session)
```
[ ] EC2 instances TERMINATED
[ ] Elastic IPs RELEASED
[ ] EBS volumes / snapshots DELETED
[ ] NAT Gateways DELETED (expensive!)
[ ] CloudFront distributions DISABLED + DELETED
[ ] S3 test buckets EMPTIED + DELETED
[ ] S3 Block Public Access RE-ENABLED globally
[ ] RDS instances DELETED (if created)
[ ] Check Billing Dashboard shows ~$0 trending
```

💡 **Tip:** Build a habit — end every lab by checking the **Billing Dashboard** and **EC2 → Instances** to confirm nothing is left running.

---

➡️ Next: [14-mini-projects.md](14-mini-projects.md)

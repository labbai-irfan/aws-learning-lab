# Module 5 — AWS Account Setup Guide (Hands-On)

> Step-by-step guide to creating your first AWS account safely and securing it. Follow this **before** doing any hands-on exercises. 🛠️

---

## ⏱️ What You'll Need
- A valid **email address** (not already used for AWS).
- A **phone number** (for verification).
- A **credit/debit card** (required even for Free Tier; small temporary auth charge ~$1, refunded).
- ~20 minutes.

---

## Part 1 — Create the Account

🛠️ **Step 1: Go to the sign-up page**
- Visit https://aws.amazon.com/ and click **"Create an AWS Account"**.

🛠️ **Step 2: Enter account details**
- **Root user email address** — use a dedicated email (ideally a team distribution list, not personal).
- **AWS account name** — e.g., "MyName-Learning".
- Verify the email with the OTP code AWS sends.

🛠️ **Step 3: Create a strong root password**
- Use a long, unique password. Store it in a password manager.

🛠️ **Step 4: Contact information**
- Choose **Personal** (for learning) or **Business**.
- Fill in name, address, phone.

🛠️ **Step 5: Payment information**
- Enter a card. AWS may place a small temporary authorization (refunded).
- 💰 Free Tier still requires a card; you're only charged if you exceed limits.

🛠️ **Step 6: Identity verification**
- Verify via SMS or voice call (enter the code shown).

🛠️ **Step 7: Choose a support plan**
- Select **Basic Support — Free** (good for learning).

✅ Your account is created. **Do not start launching resources yet — secure it first (Part 2).**

---

## Part 2 — Secure the Root User (DO THIS IMMEDIATELY) 🔒

The **root user** can do *anything*, including closing the account and changing billing. Protect it.

🛠️ **Step 1: Sign in as root**
- Sign in at the console using your root email.

🛠️ **Step 2: Enable MFA (Multi-Factor Authentication) on root**
- Go to **IAM → top-right account name → Security credentials**.
- Under **Multi-factor authentication (MFA)**, click **Assign MFA device**.
- Use a virtual MFA app (Google Authenticator, Authy, Microsoft Authenticator) or a hardware key.
- Scan the QR code, enter two consecutive codes, finish.
- ⚠️ Without MFA, a leaked root password = full account compromise.

🛠️ **Step 3: Do NOT create access keys for root**
- Never generate root access keys. Use IAM users/roles for programmatic access.

🛠️ **Step 4: Note the account ID**
- Found top-right under your account name. You'll need it for IAM sign-in.

---

## Part 3 — Stop Using Root: Create an Admin IAM User

Daily work should use an **IAM user**, not root.

🛠️ **Step 1: Go to IAM**
- Console → search **IAM** → open it.

🛠️ **Step 2 (recommended): Use IAM Identity Center or create an IAM user**
- For simplicity here, **Users → Create user**.
- Username: e.g., `admin-yourname`.
- Check **Provide user access to the AWS Management Console**.
- Set a custom password; require reset at first sign-in if shared.

🛠️ **Step 3: Attach permissions**
- Choose **Add user to group** → create a group `Admins`.
- Attach the **AdministratorAccess** managed policy to the group.
- (Best practice later: apply **least privilege** — give only what's needed.)

🛠️ **Step 4: Enable MFA on the IAM user too** 🔒
- After creation, open the user → **Security credentials** → assign an MFA device.

🛠️ **Step 5: Save the IAM sign-in URL**
- IAM dashboard shows a URL like `https://<account-id>.signin.aws.amazon.com/console`.
- Bookmark it and sign in here from now on (not as root).

✅ From now on, **use the IAM admin user**, not the root user.

---

## Part 4 — Baseline Security Settings (Quick Wins) 🔒

🛠️ Set an **account-wide password policy**: IAM → **Account settings** → require minimum length, complexity, rotation.

🛠️ Turn on **S3 Block Public Access** at the account level (S3 console → Block Public Access settings) to prevent accidental public buckets.

🛠️ Consider enabling **AWS CloudTrail** (records all account activity) — a free trail in one Region is a great audit baseline.

🛠️ Set your **default Region** (top-right Region selector) to one near you (e.g., Mumbai `ap-south-1`).

---

## Part 5 — Turn On Billing Protection (DO NOT SKIP) 💰

This prevents surprise bills while learning. Full details in [06-billing-guide.md](06-billing-guide.md).

🛠️ **Step 1: Enable billing alerts**
- Sign in as root (one-time) → **Billing & Cost Management → Billing preferences**.
- Enable **"Receive Billing Alerts"** / Free Tier usage alerts.

🛠️ **Step 2: Create an AWS Budget**
- **Billing → Budgets → Create budget**.
- Choose **Cost budget**, set e.g. **$5/month**, add your email for alerts at 50%, 80%, 100%.

🛠️ **Step 3 (optional): CloudWatch billing alarm**
- Switch to **us-east-1** (billing metrics live there) → CloudWatch → Alarms → create alarm on `EstimatedCharges` > $5.

✅ Now you'll be warned long before any real charge.

---

## Part 6 — First-Day Checklist ✅

```
[ ] Account created with a dedicated email
[ ] Root password strong + stored in password manager
[ ] MFA enabled on ROOT user
[ ] No access keys on root
[ ] Admin IAM user created (in an Admins group)
[ ] MFA enabled on the IAM admin user
[ ] Signing in via IAM URL, not root
[ ] Password policy set
[ ] S3 Block Public Access ON
[ ] Default Region chosen
[ ] Billing alerts enabled
[ ] AWS Budget ($5) with email alerts created
[ ] (Optional) CloudWatch billing alarm in us-east-1
[ ] (Optional) CloudTrail enabled
```

---

## ⚠️ Common Setup Mistakes (avoid these)
- Using the **root user** for daily work. (Use IAM.)
- **No MFA** on root. (Biggest risk.)
- Creating **root access keys**. (Never.)
- Skipping **billing alerts** → surprise bill.
- Leaving **resources running** (EC2, NAT Gateway, Elastic IPs) after labs.
- Granting **AdministratorAccess** to everyone instead of least privilege.

---

➡️ Next: [06-billing-guide.md](06-billing-guide.md)

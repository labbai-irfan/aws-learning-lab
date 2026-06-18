# Capstone Project — Build a Production 3-Tier VPC with Terraform

You've learned every piece. Now assemble them into **one real, highly-available VPC** using Infrastructure as Code — the way it's actually done in production. By the end you'll have a multi-AZ network with public/app/data tiers, per-AZ NAT, SG chaining, and a free S3 endpoint, all created and destroyed with two commands.

> 💰 **Cost:** the NAT Gateways are the only meaningful charge (~$0.045/hr each + data). Two NATs ≈ **$0.09/hr**. Run `terraform destroy` when done. Everything else (VPC, subnets, IGW, route tables, SGs, S3 endpoint) is **free**.

---

## 🎯 What you'll build

```
                            Internet
                               │
                        Internet Gateway
   ┌──────────────────── VPC 10.0.0.0/16 ───────────────────────┐
   │        AZ-a                          AZ-b                   │
   │  ┌─────────────────┐         ┌─────────────────┐           │
   │  │ PUBLIC 10.0.0/24│         │ PUBLIC 10.0.10/24│          │
   │  │  NAT GW (a)     │         │  NAT GW (b)      │          │
   │  └────────┬────────┘         └────────┬─────────┘          │
   │  ┌────────▼────────┐         ┌────────▼─────────┐          │
   │  │ APP   10.0.1/24 │         │ APP   10.0.11/24 │          │
   │  │  route → NAT-a  │         │  route → NAT-b   │          │
   │  └────────┬────────┘         └────────┬─────────┘          │
   │  ┌────────▼────────┐         ┌────────▼─────────┐          │
   │  │ DATA  10.0.2/24 │         │ DATA  10.0.12/24 │          │
   │  │  local only     │         │  local only      │          │
   │  └─────────────────┘         └──────────────────┘          │
   │  [ S3 Gateway Endpoint ] (free, private)                    │
   │  SG chain: sg_alb ─443► sg_app ─8080► sg_db ─3306►          │
   └─────────────────────────────────────────────────────────────┘
```

**Components created:** 1 VPC · 6 subnets (2 public, 2 app, 2 data) · 1 IGW · 2 NAT GWs + 2 EIPs · 4 route tables · 3 chained security groups · 1 S3 gateway endpoint.

---

## 📋 Prerequisites
- **Terraform** ≥ 1.5 (`terraform -version`)
- **AWS CLI v2** configured (`aws sts get-caller-identity` works)
- An IAM identity allowed to create VPC resources

---

## 🚀 Run it

```bash
cd 04-vpc-networking/project

terraform init        # download the AWS provider
terraform plan        # preview ~25 resources to be created
terraform apply       # type 'yes' — takes ~2 min (NAT GWs are the slow part)
```

When it finishes you'll see the outputs (VPC id, subnet ids, NAT IPs). Inspect them:
```bash
terraform output
```

### Verify your network
```bash
# Confirm the VPC and its subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,AZ:AvailabilityZone,CIDR:CidrBlock}' \
  --output table

# Confirm the SG chain (sg_db should allow 3306 only from sg_app)
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw db_sg_id) \
  --query 'SecurityGroups[0].IpPermissions'
```

### 🧹 Tear it down (stop the NAT billing!)
```bash
terraform destroy    # type 'yes'
```
✅ Confirm in the console that **no NAT Gateways or unattached EIPs remain**.

---

## 🗂️ Files

| File | What it defines |
|------|-----------------|
| [variables.tf](variables.tf) | Region, CIDRs, AZ count — change these to customize |
| [main.tf](main.tf) | The whole network: VPC, subnets, IGW, NATs, routes, SGs, endpoint |
| [outputs.tf](outputs.tf) | IDs/IPs you'll reference when launching workloads |

---

## 🧠 What to study in the code
- **`for_each` / `count` over AZs** — how one block creates per-AZ subnets and NATs (the HA pattern).
- **Route table associations** — app subnets point to their *local* NAT (no cross-AZ charge).
- **SG `referenced_security_group_id`** — the chaining pattern in code, not hard-coded CIDRs.
- **Data tier route table** — has *only* the implicit local route (no internet).
- **S3 gateway endpoint** — attached to the app route tables, free, private.

---

## 🎓 Extensions (level up)
1. **Add an ALB** in the public subnets + a target group in the app subnets; open the app in a browser.
2. **Add an Auto Scaling Group** of app instances across both AZs.
3. **Add RDS Multi-AZ** in the data subnets, reachable only via `sg_db`.
4. **Add interface endpoints** (`ssm`, `ssmmessages`, `ec2messages`) and connect to a private instance with **zero SSH**.
5. **Enable VPC Flow Logs** to S3 and find an ACCEPT and a REJECT.
6. **Single-NAT toggle** — add a `var.single_nat` to save cost in dev; discuss the HA trade-off.

---

## ✅ Definition of done
- [ ] `terraform apply` creates the full network with no errors.
- [ ] App subnets can reach the internet **outbound** (via NAT) — test from an instance.
- [ ] Data subnets have **no** internet route.
- [ ] `sg_db` allows 3306 **only** from `sg_app` (verified above).
- [ ] S3 gateway endpoint present on the app route tables.
- [ ] `terraform destroy` removes everything and leaves no idle EIPs/NATs.

You've now built — as code — the exact [Production Architecture](../02-architectures.md#b-production-architecture-highly-available-single-region) from Module 2. 🎉

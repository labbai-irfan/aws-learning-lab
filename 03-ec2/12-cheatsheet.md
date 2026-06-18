# 12 — EC2 Cheat Sheet (1-Page Revision)

> Last-minute revision for exams & interviews. Pair with [01 — Core Concepts](01-ec2-core-concepts.md).

## Core objects
| Thing | One-liner |
|---|---|
| **AMI** | Template (OS + software) an instance boots from |
| **Instance type** | CPU/RAM/network/storage profile (e.g. `t3.micro`, `m5.large`) |
| **Key pair** | SSH public/private key for login |
| **Security Group** | Stateful instance firewall (allow rules only) |
| **EBS** | Network-attached block storage (persists separately from instance) |
| **Instance store** | Ephemeral local disk — lost on stop/terminate |
| **Elastic IP** | Static public IPv4 you own |
| **User data** | Boot-time script (runs once at first launch by default) |
| **Instance profile** | Wraps an IAM role so the instance gets AWS creds (no static keys) |

## Instance families (the letters)
`T` burstable · `M` general · `C` compute-optimized · `R` memory (RAM) · `X` extra RAM · `I` storage/IOPS · `G/P` GPU · `D` dense storage. 💡 Mnemonic by workload, not memorization.

## Purchase models (cost)
| Model | Save | Use when |
|---|---|---|
| **On-Demand** | 0% | Spiky/short, dev, unknown |
| **Spot** | up to 90% | Fault-tolerant, batch, interruptible |
| **Reserved (1/3yr)** | up to 72% | Steady 24/7 baseline |
| **Savings Plans** | up to 72% | Flexible commit ($/hr) across families |
| **Dedicated Host/Instance** | — | Compliance / licensing |

## EBS volume types
| Type | For |
|---|---|
| **gp3 / gp2** | General SSD (default) — gp3 lets you tune IOPS/throughput independently |
| **io2 / io1** | High-IOPS SSD for critical DBs |
| **st1** | Throughput HDD (big sequential — logs, data warehouse) |
| **sc1** | Cold HDD (cheapest, infrequent) |
- Snapshots = incremental backups to S3. Encrypt at create (KMS). Resize/modify live.

## Lifecycle
`pending → running → (stop/start | reboot) → stopping → stopped → terminated`
- **Stop**: EBS persists, public IP changes (unless EIP). **Terminate**: root EBS deleted by default.
- **Reboot**: keeps IP + disks.

## Networking quick facts
- SG = **stateful** (return traffic auto-allowed), allow-only. NACL = **stateless**, allow+deny, subnet-level.
- Open `22`(SSH)/`3389`(RDP) only to **your IP** — prefer **SSM Session Manager** (no open port).
- One Elastic IP free *while attached* to a running instance; charged when idle.

## Commands
```bash
aws ec2 run-instances --image-id ami-xxx --instance-type t3.micro \
  --key-name my-key --security-group-ids sg-xxx --subnet-id subnet-xxx \
  --iam-instance-profile Name=my-profile --user-data file://boot.sh
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws ec2 create-image --instance-id i-xxx --name "my-ami"     # bake an AMI
ssh -i my-key.pem ec2-user@<public-ip>
```

## Exam triggers 💡
- "No static credentials on the instance" → **IAM role / instance profile**.
- "Interruptible + cheap" → **Spot**. "Steady 24/7 cheap" → **Reserved/Savings Plan**.
- "Survive stop/terminate" → **EBS** (not instance store).
- "Same config, many instances, auto-replace" → **Launch Template + ASG** ([Phase 07](../07-elb-autoscaling/06-auto-scaling.md)).
- "Bootstrap software at launch" → **User data**.

## Gotchas ⚠️
- Instance store data is **lost** on stop/terminate.
- Terminating deletes the root volume unless `DeleteOnTermination=false`.
- Security group changes apply immediately; NACL rule order matters (lowest number first).
- `t`-family throttles when CPU credits run out (watch `CPUCreditBalance`).

---
*Back to [EC2 README](README.md).*

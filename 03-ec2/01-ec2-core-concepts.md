# Module 1 — EC2 Core Concepts

> Every EC2 building block explained, with definitions, analogies, key points, CLI examples, and exam/production tips.

## Table of Contents
1. [EC2 Fundamentals](#1-ec2-fundamentals)
2. [AMI (Amazon Machine Image)](#2-ami-amazon-machine-image)
3. [Instance Types](#3-instance-types)
4. [Launch Templates](#4-launch-templates)
5. [Security Groups](#5-security-groups)
6. [Key Pairs](#6-key-pairs)
7. [Elastic IP](#7-elastic-ip)
8. [EBS (Elastic Block Store)](#8-ebs-elastic-block-store)
9. [Auto Scaling](#9-auto-scaling)
10. [Placement Groups](#10-placement-groups)
11. [User Data](#11-user-data)

---

## 1. EC2 Fundamentals

**Definition:** **Amazon EC2 (Elastic Compute Cloud)** provides resizable **virtual servers** ("instances") in the AWS cloud. You choose the OS, CPU, memory, storage, and networking, launch in minutes, and pay only for what you use.

**Analogy:** EC2 is like renting a computer in AWS's data center. You pick the specs, turn it on, log in, install software, and turn it off when done.

### The lifecycle of an instance
```
   pending ──► running ──► stopping ──► stopped ──► (start) ──► running
                  │                                   │
                  └──► terminating ──► terminated (gone forever)
```
- **running** — billed for compute + storage.
- **stopped** — not billed for compute; still billed for EBS storage; public IP is released (unless Elastic IP).
- **terminated** — instance deleted; root volume deleted by default.

### Key facts
- EC2 is **IaaS** — you manage the OS and everything above it (Shared Responsibility Model).
- Instances live in a **VPC** subnet inside an **Availability Zone** within a **Region**.
- Billed **per second** (Linux, 60s minimum) or per hour depending on OS/option.
- **Tenancy:** shared (default), dedicated instance, or dedicated host.

### Quick launch (CLI)
```bash
aws ec2 run-instances \
  --image-id ami-0abcd1234 \
  --instance-type t3.micro \
  --key-name my-key \
  --security-group-ids sg-0123 \
  --subnet-id subnet-0123 \
  --count 1
```

💡 **Tip:** **Stop** an instance to pause billing for compute (you still pay for EBS). **Terminate** to delete it entirely.
⚠️ Stopping releases the auto-assigned public IP; use an **Elastic IP** if you need a stable address.

---

## 2. AMI (Amazon Machine Image)

**Definition:** An **AMI** is a **template** used to launch an instance. It contains the OS, configuration, and optionally pre-installed software and data.

**Analogy:** A "golden image" or a snapshot of a fully set-up machine that you can stamp out into identical servers.

### What's in an AMI
- A root volume snapshot (OS + installed software).
- Launch permissions (who can use it).
- Block device mapping (which EBS volumes to attach).

### Types / sources of AMIs
| Source | Description |
|--------|-------------|
| **AWS-provided** | Amazon Linux 2023, Ubuntu, Windows Server, etc. |
| **AWS Marketplace** | Vendor images (often with licensed software) |
| **Community AMIs** | Shared by other users (verify before trusting) |
| **Your own custom AMIs** | Created from a configured instance (a "golden image") |

### Why build a custom AMI
- **Faster, consistent deployments** — bake software in so new instances boot ready.
- Essential for **Auto Scaling** (every new instance is identical).

### Create a custom AMI (CLI)
```bash
aws ec2 create-image \
  --instance-id i-0123456789 \
  --name "my-app-golden-v1" \
  --description "App + Nginx + Node baked in"
```

### Key facts
- AMIs are **Region-specific** — copy an AMI to use it in another Region:
  ```bash
  aws ec2 copy-image --source-region us-east-1 --source-image-id ami-0abc --region ap-south-1 --name "copy-app"
  ```
- AMIs are backed by **EBS snapshots** (stored in S3 behind the scenes) — you pay for the snapshot storage.

💡 **Bake vs. bootstrap:** "Bake" = pre-install everything into a custom AMI (fast boot, immutable). "Bootstrap" = install at launch via User Data (flexible, slower). Production often uses a mix.

---

## 3. Instance Types

**Definition:** An **instance type** defines the hardware: vCPUs, memory, storage, and network performance. Naming: `<family><generation>.<size>` e.g., `m5.large`, `t3.micro`, `c7g.xlarge`.

### Reading the name `m5.large`
- `m` = family (general purpose)
- `5` = generation (newer = better price/performance)
- `large` = size (nano < micro < small < medium < large < xlarge < 2xlarge ...)
- A trailing `g` (e.g., `c7g`) = **AWS Graviton (ARM)** processor — cheaper, power-efficient.

### Instance families (memorize the categories)
| Family | Letters | Optimized for | Examples / use |
|--------|---------|---------------|----------------|
| **General Purpose** | t, m | Balanced CPU/RAM | t3/t4g (burstable, dev/web), m5/m7g (apps) |
| **Compute Optimized** | c | High CPU | c7g — batch, gaming, HPC, app servers |
| **Memory Optimized** | r, x, z | Large RAM | r6g — databases, in-memory caches, analytics |
| **Storage Optimized** | i, d, h | High disk I/O | i4i — NoSQL, data warehouses, big local storage |
| **Accelerated Computing** | p, g, inf, trn | GPU/ML chips | p4/g5 — ML training/inference, graphics |

### Burstable (T family) — important for cost
- T instances (t3/t4g) earn **CPU credits** when idle and spend them when busy.
- Great for low/variable workloads (dev, small sites). 
- ⚠️ Under sustained high CPU they throttle (or charge for "unlimited" mode).

### CLI
```bash
aws ec2 describe-instance-types --instance-types t3.micro \
  --query "InstanceTypes[].{vCPU:VCpuInfo.DefaultVCpus,MemMiB:MemoryInfo.SizeInMiB}"
```

💡 **Exam tip:** Memorize family purposes — C=Compute, R=RAM (memory), I=I/O (storage), P/G=GPU, T/M=general. Graviton (`g`) = best price/performance for compatible workloads.

---

## 4. Launch Templates

**Definition:** A **Launch Template** captures all the parameters to launch instances (AMI, instance type, key pair, security groups, user data, storage, tags) so you can launch consistently and version your configuration.

**Launch Template vs Launch Configuration:**
- Launch **Configuration** = older, immutable, EC2-Auto-Scaling-only (legacy).
- Launch **Template** = newer, **versioned**, supports the latest features, works with Auto Scaling, Spot Fleet, and manual launches. **Use Launch Templates.**

### Why use them
- One source of truth for "how to launch our app server."
- **Versioning** — update to v2 without losing v1; roll back easily.
- Required/ideal for **Auto Scaling Groups**.

### Create a launch template (CLI)
```bash
aws ec2 create-launch-template \
  --launch-template-name web-app-lt \
  --version-description "v1 nginx+node" \
  --launch-template-data '{
    "ImageId":"ami-0abcd1234",
    "InstanceType":"t3.micro",
    "KeyName":"my-key",
    "SecurityGroupIds":["sg-0123"],
    "UserData":"<base64-encoded-script>"
  }'
```

💡 **Tip:** Reference `$Latest` or `$Default` version in an Auto Scaling Group, or pin a specific version for stability.

---

## 5. Security Groups

**Definition:** A **Security Group (SG)** is a **virtual, stateful firewall** attached to an instance's network interface. It controls **inbound** and **outbound** traffic with **allow rules** only.

### Key properties
- **Stateful:** if you allow inbound traffic, the response is automatically allowed out (and vice versa). You don't need a matching reverse rule.
- **Allow-only:** there are no "deny" rules — anything not explicitly allowed is denied.
- Rules reference **ports**, **protocols**, and **sources** (CIDR like `0.0.0.0/0`, or another security group).
- Multiple SGs can attach to one instance (rules are combined/union).
- Changes apply **immediately**.

### Typical web server rules
| Direction | Type | Port | Source | Why |
|-----------|------|------|--------|-----|
| Inbound | SSH | 22 | **your IP /32** | admin access (never 0.0.0.0/0!) 🔒 |
| Inbound | HTTP | 80 | 0.0.0.0/0 | public web |
| Inbound | HTTPS | 443 | 0.0.0.0/0 | public secure web |
| Outbound | All | All | 0.0.0.0/0 | default — allow all out |

### Security Group vs Network ACL (know the difference)
| | Security Group | Network ACL (NACL) |
|---|----------------|--------------------|
| Level | Instance (ENI) | Subnet |
| State | **Stateful** | **Stateless** (need explicit return rules) |
| Rules | Allow only | Allow **and** Deny |
| Evaluation | All rules | Rules in number order |

### CLI
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0123 --protocol tcp --port 22 --cidr 203.0.113.5/32
```

🔒 **Best practice:** SSH (22) only from your IP; reference SGs (not wide CIDRs) for app→DB traffic, e.g., DB SG allows 3306 only from the web SG.

---

## 6. Key Pairs

**Definition:** A **key pair** is a public/private key used for secure **SSH** login to Linux instances (or to retrieve the Windows password). AWS stores the **public key**; you keep the **private key** (`.pem`).

### How it works
```
   You launch instance ──► AWS injects PUBLIC key into ~/.ssh/authorized_keys
   You connect ──► SSH proves you hold the matching PRIVATE key ──► access granted
```

### Key facts
- Download the **private key once** at creation — AWS does **not** store it; if you lose it, you can't recover it.
- Protect the file: `chmod 400 my-key.pem` (SSH refuses world-readable keys).
- Default Linux usernames: Amazon Linux = `ec2-user`, Ubuntu = `ubuntu`, Debian = `admin`, CentOS = `centos`.

### Create + connect
```bash
aws ec2 create-key-pair --key-name my-key \
  --query 'KeyMaterial' --output text > my-key.pem
chmod 400 my-key.pem
ssh -i my-key.pem ec2-user@<public-ip>
```

### Lost your key? Recovery options
- Use **EC2 Instance Connect** (browser-based, no stored key needed) or **SSM Session Manager**.
- Or detach the root volume, attach to another instance, add a new public key, reattach.

🔒 **Tip:** For teams/production, prefer **SSM Session Manager** (no open SSH port, no key sprawl, full audit logging).

---

## 7. Elastic IP

**Definition:** An **Elastic IP (EIP)** is a **static, public IPv4 address** you allocate to your account and can attach to an instance (or NAT Gateway). It stays the same across stops/starts and can be remapped.

### Why you need it
- A normal instance's auto-assigned public IP **changes** when you stop/start. An EIP is **fixed** — essential for DNS records, allowlists, and stable endpoints.

### Key facts & cost 💰
- An EIP is **free while attached to a running instance**.
- ⚠️ You are **charged** for an EIP that is **allocated but not in use** (not attached, or attached to a stopped instance), and (as of 2024) for **all** public IPv4 addresses. Release EIPs you don't need.
- You can **remap** an EIP to another instance for quick failover.

### CLI
```bash
aws ec2 allocate-address --domain vpc
aws ec2 associate-address --instance-id i-0123 --allocation-id eipalloc-0abc
# when done:
aws ec2 release-address --allocation-id eipalloc-0abc
```

💡 **Production tip:** For web apps behind a load balancer or a domain, you often point DNS at an **ALB** or use EIPs only where a fixed single IP is required (e.g., a NAT instance, a whitelisted egress IP).

---

## 8. EBS (Elastic Block Store)

**Definition:** **EBS** provides **persistent block storage volumes** (virtual hard drives) that attach to EC2 instances. Data persists independently of the instance lifecycle.

### Key properties
- **Persistent:** survives instance stop/start (root volume is deleted on terminate by default — change with `DeleteOnTermination=false`).
- **AZ-locked:** a volume lives in one AZ and can only attach to an instance in the same AZ.
- **Snapshots:** point-in-time backups stored in S3; can restore to a new volume or copy across Regions.
- Attach multiple volumes; one instance, many disks.

### Volume types
| Type | Name | Best for | Notes |
|------|------|----------|-------|
| **gp3** | General Purpose SSD | Most workloads (default) | Baseline 3,000 IOPS, cheaper than gp2, independently scalable IOPS/throughput |
| **gp2** | General Purpose SSD | Legacy general use | IOPS scale with size |
| **io1 / io2** | Provisioned IOPS SSD | High-performance DBs | Highest, guaranteed IOPS; io2 Block Express for extreme |
| **st1** | Throughput HDD | Big sequential (logs, big data) | Low cost, throughput-oriented |
| **sc1** | Cold HDD | Infrequent access | Cheapest |

💡 **Default choice = gp3** (better price/performance than gp2).

### EBS vs Instance Store (very common question)
| | EBS | Instance Store |
|---|-----|----------------|
| Persistence | **Persistent** | **Ephemeral** (lost on stop/terminate) |
| Attach/detach | Yes, movable | Fixed to host |
| Use | Almost everything | High-speed scratch/cache |

### Snapshot & resize (CLI)
```bash
aws ec2 create-snapshot --volume-id vol-0123 --description "daily backup"
aws ec2 modify-volume --volume-id vol-0123 --size 50 --volume-type gp3
# then on the instance, grow the filesystem:
sudo growpart /dev/xvda 1 && sudo xfs_growfs -d /
```

🔒 **Tip:** Enable **EBS encryption** (KMS) for data at rest. Snapshots of an encrypted volume are encrypted too.

---

## 9. Auto Scaling

**Definition:** **EC2 Auto Scaling** automatically adjusts the number of instances in an **Auto Scaling Group (ASG)** to match demand, replacing unhealthy instances and maintaining availability.

### Core pieces
- **Launch Template** — how to launch each instance.
- **Auto Scaling Group (ASG)** — defines **min / desired / max** capacity and the subnets/AZs.
- **Scaling policies** — when to add/remove instances.
- **Health checks** — replace failed instances automatically (EC2 or ELB health checks).

### Scaling policy types
| Policy | How it works | Example |
|--------|--------------|---------|
| **Target tracking** | Keep a metric at a target | "Keep average CPU at 50%" |
| **Step scaling** | Add/remove in steps by alarm severity | +2 if CPU>70%, +4 if CPU>90% |
| **Simple scaling** | One action per alarm (legacy) | +1 if CPU>70% |
| **Scheduled** | Scale at set times | Scale up at 9am, down at 9pm |
| **Predictive** | ML forecasts demand | Pre-scale for known patterns |

### Why it matters
- **High availability:** spread instances across **multiple AZs**; if an AZ or instance dies, ASG launches replacements.
- **Elasticity:** scale out under load, in when idle → pay only for what you need. 💰
- Works with a **load balancer** to distribute traffic to healthy instances.

### CLI
```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name web-asg \
  --launch-template "LaunchTemplateName=web-app-lt,Version=\$Latest" \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "subnet-aaa,subnet-bbb" \
  --target-group-arns arn:aws:elasticloadbalancing:...:targetgroup/web/abc
```

💡 **Exam tip:** ASG = availability + elasticity. Set **min ≥ 2 across ≥ 2 AZs** for HA. Auto Scaling itself is free; you pay only for the instances.

---

## 10. Placement Groups

**Definition:** **Placement Groups** control how EC2 places your instances on the underlying hardware to optimize for performance or availability.

### The three strategies
| Strategy | Layout | Optimizes for | Trade-off |
|----------|--------|---------------|-----------|
| **Cluster** | Pack instances close together in one AZ | Lowest latency, highest throughput (HPC, big data) | Single AZ → less fault isolation |
| **Spread** | Spread instances across distinct hardware/racks | Max availability (critical, small number of instances) | Limited count (7 per AZ) |
| **Partition** | Group instances into partitions on isolated racks | Large distributed systems (HDFS, Cassandra, Kafka) | Up to 7 partitions/AZ |

```
   CLUSTER (low latency)     SPREAD (isolation)      PARTITION (big distributed)
   [i][i][i] same rack       [i] rack1               part1: [i][i]
                             [i] rack2               part2: [i][i]
                             [i] rack3               part3: [i][i]
```

💡 **Exam tip:** Cluster = performance (one AZ). Spread = availability (few critical instances). Partition = large distributed data systems.

---

## 11. User Data

**Definition:** **User Data** is a script that runs **automatically when an instance first boots**, used to bootstrap/configure the instance (install packages, start services, pull code).

### Key facts
- Runs as **root**, **once** at first boot by default (cloud-init).
- Linux scripts start with a shebang: `#!/bin/bash`.
- Size limit 16 KB (base64 before encoding). For big setups, have user data download a script from S3.
- View/debug logs on the instance: `/var/log/cloud-init-output.log`.
- Retrieve from inside the instance via the metadata service:
  ```bash
  curl http://169.254.169.254/latest/user-data
  ```

### Example: bootstrap a web server
```bash
#!/bin/bash
dnf update -y
dnf install -y nginx
systemctl enable --now nginx
echo "<h1>Deployed via User Data on $(hostname)</h1>" > /usr/share/nginx/html/index.html
```

### Bake vs bootstrap (recap)
- **User Data (bootstrap):** flexible, slower boot, good for dynamic config.
- **Custom AMI (bake):** fast, consistent boot, immutable; ideal for Auto Scaling at scale.
- Common pattern: a baked AMI **plus** small user-data for last-mile config.

💡 **Tip:** Make user-data **idempotent** and log progress; a failing user-data script is a top cause of "instance launched but app isn't up."

---

## ✅ Module 1 Recap
You can now explain: EC2 lifecycle · AMIs (and custom/golden images) · instance type families & naming · Launch Templates (vs configs) · stateful Security Groups · key pairs & SSH access · Elastic IPs (and their cost trap) · EBS volume types, snapshots, EBS vs instance store · Auto Scaling (ASG + policies) · placement groups (cluster/spread/partition) · user data bootstrapping.

➡️ Next: [02-ec2-architecture.md](02-ec2-architecture.md)

# Module 10 — 100 EC2 Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, and technically correct.

---

## Fundamentals (1–12)
**1. What is Amazon EC2?** Resizable virtual servers in AWS; you choose OS/CPU/RAM/storage/network, launch in minutes, pay per use. It's IaaS.

**2. EC2 instance lifecycle states?** pending → running → stopping → stopped → terminated (also rebooting, hibernated). Terminated is permanent.

**3. Stop vs terminate?** Stop pauses compute billing (EBS still billed), keeps the instance; terminate deletes it and (by default) its root volume.

**4. Reboot vs stop/start?** Reboot keeps the same host, IP, and instance ID. Stop/start may move to a new host and changes the public IP (unless EIP).

**5. How is EC2 billed?** Per second (Linux, 60s minimum) or per hour, depending on OS/purchase option; plus EBS, data transfer out, EIP, etc.

**6. What's the difference between EC2 and a traditional server?** EC2 is virtual, on-demand, elastic, pay-as-you-go, and globally available in minutes; no hardware to buy/maintain.

**7. What is an instance type?** A hardware profile (vCPU, RAM, network, storage) like t3.micro or m7g.large.

**8. Where does an instance run physically?** In a subnet within one Availability Zone in a Region, inside your VPC.

**9. What is the instance metadata service?** An endpoint at 169.254.169.254 giving instance info (IP, role creds, user data). Use IMDSv2 for security.

**10. How do you give an instance AWS permissions safely?** Attach an **IAM role** — provides temporary, rotating credentials; never store static keys on disk.

**11. What tenancy options exist?** Shared (default), Dedicated Instance, Dedicated Host.

**12. Can you change instance type later?** Yes — stop the instance, change type, start. (Resizing root volume separately.)

---

## AMI (13–20)
**13. What is an AMI?** A template (OS + config + optional software) used to launch instances.

**14. What's in an AMI?** Root volume snapshot, launch permissions, and block device mapping.

**15. Are AMIs Region-specific?** Yes; copy an AMI to another Region to use it there.

**16. Why build a custom/golden AMI?** Faster, consistent boots; essential for identical Auto Scaling instances.

**17. Bake vs bootstrap?** Bake = pre-install into AMI (fast, immutable). Bootstrap = install at boot via user data (flexible, slower). Often combined.

**18. How do you create an AMI?** From a configured instance via `create-image` (or console). It snapshots the volumes.

**19. AMI cost?** You pay for the underlying EBS snapshot storage.

**20. How to share an AMI?** Set launch permissions to specific accounts or make it public (encrypted AMIs need shared KMS keys).

---

## Instance Types (21–28)
**21. Explain the instance families.** T/M general purpose, C compute, R/X/z memory, I/D/H storage, P/G/Inf/Trn accelerated (GPU/ML).

**22. How do you read `c7g.xlarge`?** c = compute family, 7 = generation, g = Graviton/ARM, xlarge = size.

**23. What is Graviton?** AWS ARM CPUs (`g` suffix) — ~20% cheaper, great performance/watt for compatible workloads.

**24. What are burstable (T) instances?** They accrue CPU credits when idle and spend them when busy; ideal for low/variable CPU, but throttle under sustained load (or use Unlimited mode).

**25. When choose memory-optimized?** Databases, caches, in-memory analytics where RAM is the bottleneck.

**26. When compute-optimized?** CPU-bound work: batch, HPC, gaming servers, high-traffic app servers.

**27. How do you size an instance?** Profile the workload, start small, load-test, watch CloudWatch, then rightsize (Compute Optimizer).

**28. Scale up vs scale out?** Up = bigger instance (vertical); out = more instances (horizontal, via ASG). Out is more resilient.

---

## Launch Templates (29–33)
**29. What is a Launch Template?** A versioned blueprint of all launch parameters (AMI, type, key, SG, user data, storage, tags).

**30. Launch Template vs Launch Configuration?** Templates are newer, versioned, feature-rich, and work with ASG/Spot Fleet/manual launches; configs are legacy and immutable.

**31. Why version launch templates?** To update/roll back configuration safely and pin versions for stability.

**32. How do ASGs use them?** An ASG references a template + version ($Latest/$Default/pinned) to launch identical instances.

**33. Can one template launch Spot and On-Demand?** Yes, via mixed-instances policy in the ASG.

---

## Security Groups (34–41)
**34. What is a Security Group?** A stateful, instance-level virtual firewall with allow-only rules for inbound/outbound traffic.

**35. Stateful meaning?** If inbound is allowed, the response is automatically allowed out — no return rule needed.

**36. SG vs NACL?** SG = stateful, instance-level, allow-only. NACL = stateless, subnet-level, allow+deny, ordered rules.

**37. Best practice for SSH?** Allow port 22 only from your IP (/32), or use SSM Session Manager (no open port).

**38. How to let an app server reach a DB securely?** DB SG allows 3306 only from the app server's SG (SG-to-SG reference), not a wide CIDR.

**39. Can multiple SGs attach to one instance?** Yes; the effective rules are the union of all allows.

**40. Do SG changes need a reboot?** No — they apply immediately.

**41. Default outbound rule?** Allow all outbound by default.

---

## Key Pairs & SSH (42–50)
**42. What is a key pair?** Public/private keys for SSH; AWS keeps the public key, you keep the private `.pem`.

**43. What if you lose the private key?** AWS can't recover it; use EC2 Instance Connect/SSM, or attach the volume to another instance to add a new key.

**44. Why `chmod 400` the key?** SSH refuses keys that are world-readable for security.

**45. Default SSH users?** Amazon Linux ec2-user, Ubuntu ubuntu, Debian admin, CentOS centos.

**46. EC2 Instance Connect vs SSM Session Manager?** Instance Connect pushes a temporary key to port 22; SSM needs no open port and gives full audit logging — best for production.

**47. How to copy files to an instance?** scp or rsync over SSH.

**48. How to debug SSH failures?** `ssh -vvv`, check SG/22 from your IP, correct user/key, instance has public IP + route, status checks pass.

**49. What is an SSH tunnel?** Port forwarding (e.g., `-L 3306:localhost:3306`) to reach a remote service locally over SSH.

**50. How to manage SSH access for a team without sharing keys?** Use SSM Session Manager + IAM, or per-user keys in authorized_keys; centralize with IAM/Identity Center.

---

## Elastic IP (51–55)
**51. What is an Elastic IP?** A static public IPv4 you allocate and can attach/remap to instances.

**52. Why not rely on the auto-assigned public IP?** It changes on stop/start; EIP is stable for DNS/allowlists.

**53. EIP cost model?** Free while attached to a running instance; charged when idle/unattached (and all public IPv4 are now billed). Release unused ones.

**54. How does EIP help failover?** Remap it to a healthy standby instance quickly.

**55. EIP vs ALB for public entry?** For multi-instance/HA, front with an ALB and point DNS at it; use EIPs for single fixed-IP needs (NAT, allowlisted egress).

---

## EBS & Storage (56–66)
**56. What is EBS?** Persistent block storage volumes attached to instances, independent of instance life.

**57. EBS vs instance store?** EBS persists and is movable; instance store is ephemeral (lost on stop/terminate), faster for scratch.

**58. EBS volume types?** gp3/gp2 (general SSD), io1/io2 (provisioned IOPS), st1 (throughput HDD), sc1 (cold HDD).

**59. Default recommended type?** gp3 — cheaper and faster baseline than gp2, with independently scalable IOPS/throughput.

**60. Are volumes AZ-bound?** Yes; a volume attaches only to instances in its AZ. Move via snapshot.

**61. What are snapshots?** Incremental, point-in-time backups stored in S3; restore to new volumes or copy across Regions.

**62. How to resize a volume?** Modify size in AWS, then grow the partition/filesystem (growpart + resize2fs/xfs_growfs).

**63. How to encrypt EBS?** Enable encryption (KMS) at creation; snapshots/derived volumes inherit encryption.

**64. Does a stopped instance incur EBS cost?** Yes — storage is billed regardless of instance state.

**65. RAID/multiple volumes?** You can attach several volumes and stripe (RAID 0) for throughput, but prefer larger gp3/io2 first.

**66. How to back up automatically?** Use Data Lifecycle Manager (DLM) or AWS Backup for scheduled snapshots with retention.

---

## Auto Scaling (67–76)
**67. What is EC2 Auto Scaling?** It adjusts instance count in an ASG to match demand and replaces unhealthy instances.

**68. Components of Auto Scaling?** Launch Template + ASG (min/desired/max + subnets) + scaling policies + health checks.

**69. Scaling policy types?** Target tracking, step, simple, scheduled, predictive.

**70. What is target tracking?** Keeps a metric at a target (e.g., 50% CPU) by scaling automatically.

**71. How does ASG ensure HA?** Spreads instances across multiple AZs and relaunches failed ones.

**72. ELB vs EC2 health checks in ASG?** EC2 checks instance status; ELB checks app health (HTTP). ELB checks catch app-level failures.

**73. Cooldown / warm-up?** Periods that prevent rapid repeated scaling and account for instance boot/app readiness.

**74. Does Auto Scaling cost extra?** No; you pay only for the instances it runs.

**75. How to scale a stateless web tier?** Put instances behind an ALB in an ASG across AZs with target tracking on CPU/requests.

**76. Min/desired/max meaning?** Floor count, current target count, and ceiling the ASG won't exceed.

---

## Placement Groups & Networking (77–82)
**77. What are placement groups?** Controls for how instances are placed on hardware: cluster, spread, partition.

**78. Cluster placement group?** Packs instances close in one AZ for lowest latency/highest throughput (HPC).

**79. Spread placement group?** Places instances on distinct hardware for max availability (few critical instances).

**80. Partition placement group?** Groups instances into isolated partitions for large distributed systems (HDFS, Cassandra, Kafka).

**81. Public vs private subnet for EC2?** Public has a route to the Internet Gateway; private uses a NAT Gateway for outbound only.

**82. What is an ENI?** Elastic Network Interface — the virtual NIC connecting an instance to the VPC; SGs attach here.

---

## User Data, Deployment, Web Stack (83–100)
**83. What is user data?** A boot-time script (runs once as root by default) to bootstrap an instance.

**84. Where are user-data logs?** /var/log/cloud-init-output.log.

**85. How to make user data idempotent?** Guard steps with checks so re-runs don't break things; log progress.

**86. Why put Nginx in front of Node?** Static serving, TLS termination, reverse proxy, buffering, security — don't expose Node directly.

**87. Why use PM2?** Keeps Node alive, restarts on crash, clusters across CPUs, manages logs, and (with startup+save) survives reboots.

**88. How does PM2 survive reboots?** `pm2 startup` registers a systemd service; `pm2 save` snapshots the process list to resurrect.

**89. How do you deploy a React app on EC2?** Build (`npm run build`), copy the static output to Nginx's root, configure SPA fallback `try_files /index.html`.

**90. How do you deploy a Node API?** Pull code, `npm install --production`, set env vars/secrets, run under PM2 bound to localhost, proxy via Nginx.

**91. How does Node connect to MySQL?** Via a connection pool (mysql2) using host/user/password/db from env; localhost for same-box, RDS endpoint otherwise.

**92. How do you secure the database?** Never open 3306 publicly; localhost or SG-to-SG only; strong creds; encryption; managed backups (RDS).

**93. How do you add HTTPS?** Certbot/Let's Encrypt with the Nginx plugin for a free auto-renewing cert, or an ACM cert on an ALB.

**94. How do you map a domain?** Allocate an EIP, create an A record (or ALB alias) in Route 53/registrar pointing to it, set server_name in Nginx.

**95. What causes a 502 vs 504?** 502 = upstream (Node) unreachable/crashed; 504 = upstream too slow (timeout). Check PM2/logs/query performance.

**96. How do you handle secrets in production?** Env vars from SSM Parameter Store/Secrets Manager (or chmod 600 .env), never in source control.

**97. How do you zero-downtime deploy?** `pm2 reload` (cluster), build new static then swap, blue/green or rolling via ASG/ALB.

**98. How do you monitor an EC2 app?** CloudWatch metrics/alarms (CPU, mem via agent, 5xx, disk), PM2 monit, log aggregation.

**99. How do you reduce EC2 cost?** Rightsize, Graviton, Savings Plans/Spot, gp3, stop non-prod, delete orphaned volumes/EIPs, CloudFront, Auto Scaling.

**100. Walk me through a full deployment.** Provision EC2 (SG 22/80/443, key, EIP) → update + create deploy user + swap → install Node/PM2/Nginx/MySQL → deploy Node under PM2 (localhost:5000) → build & copy React to Nginx root → configure Nginx (static + /api proxy) → connect MySQL securely → point domain (Route 53 A → EIP) → Certbot HTTPS + redirect → add CloudWatch alarms, snapshots, budgets, and pm2 startup/save.

---

➡️ Next: [11-50-production-scenarios.md](11-50-production-scenarios.md)

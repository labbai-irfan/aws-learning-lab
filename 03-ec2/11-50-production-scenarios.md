# Module 11 — 50 Production Scenarios (with Solutions)

> Real "what would you do in production" situations. Read the scenario, decide, then check the **Solution**. These mirror on-call incidents, architecture reviews, and senior interviews.

---

### Availability & Scaling
**1.** Traffic spikes every evening and the single EC2 maxes out CPU.
→ **Put it behind an ALB in an Auto Scaling Group across ≥2 AZs with target-tracking on CPU.** Scales out at peak, in at night; also survives instance failure.

**2.** You need the app to survive a full AZ outage.
→ **Run instances in multiple AZs (ASG) + RDS Multi-AZ + ALB across AZs.** No single-AZ dependency.

**3.** New instances from the ASG come up but serve errors for a minute.
→ **Add an ELB health check + warm-up/grace period; bake the app into a custom AMI** so instances are ready faster.

**4.** During deploys, users see downtime.
→ **Zero-downtime deploy:** `pm2 reload` (cluster), or rolling/blue-green via ASG + ALB target groups.

**5.** Auto Scaling launches the wrong (old) configuration.
→ **Update the Launch Template version and set the ASG to $Latest;** refresh instances (instance refresh).

**6.** You need to handle a known Monday 9am surge.
→ **Scheduled scaling** to pre-scale before 9am, plus target tracking for the rest.

**7.** Batch jobs are expensive on On-Demand and can restart safely.
→ **Run them on Spot Instances** (ASG mixed policy) for up to ~90% savings.

**8.** A stateful app can't be load-balanced easily.
→ **Externalize state** (sessions in Redis/ElastiCache, files in S3, data in RDS) so instances become stateless and scalable.

---

### Connectivity & Access
**9.** Engineer lost the SSH key and is locked out.
→ **Use EC2 Instance Connect or SSM Session Manager;** or detach the root volume, attach to a helper instance, add a new public key, reattach.

**10.** SSH suddenly times out after a reboot.
→ **Public IP changed on stop/start — attach an Elastic IP** and update DNS/allowlists.

**11.** Security audit flags SSH open to 0.0.0.0/0.
→ **Restrict 22 to corporate IP/VPN, or remove SSH entirely and use SSM Session Manager** (no open port, full audit).

**12.** Multiple admins need access without sharing one key.
→ **SSM Session Manager + IAM** (per-user, logged), or per-user keys in authorized_keys.

**13.** App on EC2 needs to read S3 securely.
→ **Attach an IAM role to the instance** — no static keys; credentials auto-rotate.

**14.** A vendor needs a fixed egress IP to allowlist you.
→ **Route outbound through a NAT with an Elastic IP** (or a NAT instance with an EIP) and give them that IP.

---

### Storage & Data
**15.** Disk fills up and the app crashes.
→ **Clean logs (`pm2 flush`, `journalctl --vacuum`), then grow the gp3 volume + `growpart`/`xfs_growfs`; add CloudWatch disk alarm.**

**16.** You need point-in-time backups of the data volume.
→ **Automated EBS snapshots via Data Lifecycle Manager / AWS Backup with retention.**

**17.** You must move a volume's data to another AZ.
→ **Snapshot the volume, create a new volume from the snapshot in the target AZ, attach.**

**18.** Compliance requires encryption at rest.
→ **Enable EBS encryption (KMS); snapshots and copies inherit it.** For existing unencrypted volumes, snapshot → copy with encryption → restore.

**19.** Database needs guaranteed high IOPS.
→ **Use io2 (Block Express) provisioned IOPS volumes,** or move to RDS with provisioned IOPS.

**20.** Logs need durable, cheap long-term storage.
→ **Ship logs to S3 (lifecycle to Glacier) or CloudWatch Logs;** don't keep them only on the instance.

---

### Web / Nginx / Node
**21.** Nginx returns 502 Bad Gateway.
→ **Check `pm2 list`/logs — Node is down or on the wrong port; fix proxy_pass; on AL/RHEL set `httpd_can_network_connect`.**

**22.** React routes return 404 on refresh.
→ **Add SPA fallback `try_files $uri /index.html;` in Nginx.**

**23.** Node app dies whenever you log out of SSH.
→ **Run it under PM2 (or systemd); `pm2 startup` + `pm2 save`** so it persists and auto-starts.

**24.** App uses only one CPU core under load.
→ **PM2 cluster mode (`-i max`)** to use all cores.

**25.** Large file uploads fail at the proxy.
→ **Increase `client_max_body_size` in Nginx and any body-size limits in Node.**

**26.** API is slow (504 timeouts) under load.
→ **Profile DB queries/add indexes, add caching, raise `proxy_read_timeout`, and scale out.**

**27.** Static assets aren't cached, increasing load/cost.
→ **Add Nginx cache headers + gzip, and front with CloudFront.**

**28.** CORS errors between React and the API.
→ **Serve both behind the same domain via Nginx (`/` static, `/api` proxy)** so requests are same-origin; otherwise set proper CORS headers.

---

### Database
**29.** App can't reach RDS ("timeout").
→ **RDS security group must allow 3306 from the EC2's SG;** verify subnet routing and that RDS is in the right VPC.

**30.** "Too many connections" errors.
→ **Use a connection pool with a sane limit; fix connection leaks; scale RDS or add a proxy (RDS Proxy).**

**31.** Single-box MySQL is a reliability risk.
→ **Migrate to Amazon RDS Multi-AZ** for managed backups, patching, and automatic failover.

**32.** Need a read-heavy app to scale reads.
→ **Add RDS read replicas and route reads to them.**

**33.** DB credentials are hard-coded in code.
→ **Move to SSM Parameter Store/Secrets Manager (or chmod 600 .env); rotate the leaked creds.**

---

### Security
**34.** Instance was compromised via an exposed port.
→ **Isolate (restrict SG), snapshot for forensics, terminate, relaunch from a clean AMI, rotate creds, review CloudTrail.**

**35.** Secrets accidentally committed to Git.
→ **Rotate them immediately, purge from history, move to Secrets Manager, add pre-commit scanning.**

**36.** You must ensure no instance uses static AWS keys.
→ **Use IAM roles everywhere; deny long-lived keys via SCP/policies; audit with IAM Access Analyzer.**

**37.** Enforce HTTPS only.
→ **301 redirect 80→443 in Nginx (or ALB listener rule); HSTS header; valid cert with auto-renew.**

**38.** Patch management across many instances.
→ **Use SSM Patch Manager / maintenance windows;** bake patched AMIs and roll via ASG.

---

### SSL & Domain
**39.** Certbot fails to issue a cert.
→ **Ensure the domain's A record already points to the server and port 80 is open;** retry; check rate limits.

**40.** Certificate expired and site shows warnings.
→ **`certbot renew`; verify the renew timer is active;** for ALB use ACM (auto-managed).

**41.** Migrating to a load balancer for HTTPS.
→ **Use a free ACM cert on the ALB (TLS terminates there); instances serve HTTP internally.**

**42.** Domain changes take too long to propagate.
→ **Lower the DNS TTL ahead of the change; verify with `dig`/`nslookup`.**

---

### Performance & Cost
**43.** Burstable t3 instance keeps throttling.
→ **Move to a fixed-performance M/C type, or enable T Unlimited** if bursts are short.

**44.** Monthly bill jumped unexpectedly.
→ **Cost Explorer group by service/usage type; find oversized/forgotten resources; set Budgets.**

**45.** Charged for Elastic IPs you forgot.
→ **Release unattached EIPs and unused public IPv4.**

**46.** Non-prod runs 24/7 wasting money.
→ **Schedule stop/start (Instance Scheduler / Lambda+EventBridge) for nights/weekends.**

**47.** Steady production fleet costs too much On-Demand.
→ **Buy Savings Plans/Reserved for the baseline; Spot for burst capacity; consider Graviton.**

**48.** Data transfer costs are high.
→ **Cache with CloudFront, keep chatty traffic in-AZ, use VPC endpoints to avoid NAT/egress.**

---

### Operations / DR
**49.** Need to recreate the entire stack reliably.
→ **Codify with infrastructure as code (CloudFormation/Terraform) + a golden AMI + Launch Template;** avoid manual setup.

**50.** Region-wide outage disaster recovery.
→ **Copy AMIs/snapshots to a second Region, replicate the DB (cross-Region read replica/backups), and have Route 53 failover routing** to the DR Region.

---

## Pattern Summary (memorize these reflexes)
```
"Highly available"        → multi-AZ ASG + ALB + RDS Multi-AZ
"Scale with demand"       → Auto Scaling (target tracking)
"Cheapest interruptible"  → Spot
"Steady baseline savings" → Savings Plans / Reserved / Graviton
"No open SSH port"        → SSM Session Manager
"Service AWS access"      → IAM role (no static keys)
"502"                     → upstream Node/PM2 down
"504"                     → upstream too slow
"DB unreachable"          → SG-to-SG rule on 3306
"Survive reboot"          → pm2 startup + save / systemd
"Cost spike"              → Cost Explorer + Budgets + cleanup
"DR across Regions"       → copy AMIs/snapshots + Route 53 failover
```

---

➡️ Next: build it for real → [Capstone Project](project/README.md)

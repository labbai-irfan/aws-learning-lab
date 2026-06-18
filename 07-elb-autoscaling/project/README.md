# Project — Highly-Available Auto-Scaling Web Tier

> Capstone: turn a single server into a **self-healing, multi-AZ, auto-scaling** web tier behind an ALB with HTTPS. This is the production shape every real app eventually needs.

**You'll build:**
```
Route 53 (ALIAS) → ACM HTTPS → ALB (2 public subnets, 2 AZs)
                                   │ HTTP:80 → redirect → HTTPS:443
                                   ▼  forward, health /api/health
                          Target Group ──► ASG (min 2, max 6, 2 AZs)
                              EC2 (AZ-a)   EC2 (AZ-b)   ... scales on CPU
                                          │
                                  RDS MySQL Multi-AZ (private subnets)
```

**Prerequisites:** the [Phase 03 capstone app](../../03-ec2/project/README.md) (or any app exposing `/api/health`), a VPC with ≥2 public + ≥2 private subnets across 2 AZs ([Phase 04](../../04-vpc-networking/README.md)), AWS CLI v2. Read [01](../01-elb-core-concepts.md) + [06 Auto Scaling](../06-auto-scaling.md) first.

---

## Steps (high level)
1. **AMI:** bake an AMI from your working app instance (or use user-data to install it on boot).
2. **Launch Template** referencing the AMI, instance type, SG (allow 80/443 from the ALB SG only), and an instance profile.
3. **Target group** (`/api/health`, matcher 200) + **ALB** in the 2 public subnets; HTTPS:443 listener with an **ACM** cert, HTTP:80 → redirect to 443.
4. **ASG** across the 2 private subnets, attached to the target group, `min 2 / desired 2 / max 6`, **health-check type ELB**, grace 300s.
5. **Target-tracking** policy: CPU 50% (and/or ALB `RequestCountPerTarget`).
6. **Route 53** ALIAS A record → the ALB.
7. **RDS Multi-AZ** in private subnets; app SG → DB SG on 3306 only.

```bash
# target group + ALB + listeners
aws elbv2 create-target-group --name web-tg --protocol HTTP --port 80 \
  --vpc-id <vpc> --health-check-path /api/health --matcher HttpCode=200
aws elbv2 create-load-balancer --name web-alb --type application \
  --subnets <pub-a> <pub-b> --security-groups <alb-sg>
# ASG attached to the target group (see 06-auto-scaling.md for the full commands)
aws autoscaling create-auto-scaling-group --auto-scaling-group-name web-asg \
  --launch-template LaunchTemplateName=web-lt,Version='$Latest' \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "<priv-a>,<priv-b>" --target-group-arns <tg-arn> \
  --health-check-type ELB --health-check-grace-period 300
```

## Acceptance checklist ✅
- [ ] `https://<domain>` loads; HTTP redirects to HTTPS.
- [ ] **Terminate one instance** → ASG launches a replacement; site stays up.
- [ ] **Kill the app** on one instance (fail `/api/health`) → it's deregistered + replaced.
- [ ] **Load test** (e.g., `hey`/`ab`) drives CPU up → ASG scales out; quiet → scales in to min 2.
- [ ] Traffic is served from **both AZs**; losing one AZ's instances keeps the site up.
- [ ] RDS is **not** publicly reachable; only the app SG can reach 3306.

## Stretch goals
- Blue/green with **two target groups** + weighted forwarding (or CodeDeploy — [Phase 12](../../12-cicd/README.md)).
- **Instance refresh** to roll a new AMI with zero downtime.
- Mixed instances policy (On-Demand + **Spot**) for cost.

## Cleanup 💰
Delete the ASG (set desired 0 first), the ALB + target group, the launch template, the RDS instance, and the Route 53 record — **the ALB bills hourly 24/7**.

---
*Back to [ELB & Auto Scaling README](../README.md).*

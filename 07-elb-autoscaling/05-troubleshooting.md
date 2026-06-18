# Module 5 — Troubleshooting Guide

> A symptom-first playbook for ELB problems. Each section: **symptom → likely causes → how to confirm → fix.** Start with the universal first command.

## 🔦 The one command to run first

For almost any ELB issue, check target health and read the **reason**:
```bash
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[].{Id:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Desc:TargetHealth.Description}' \
  --output table
```
The `Reason` field points you straight at the cause:

| Reason | Meaning | Jump to |
|--------|---------|---------|
| `Elb.RegistrationInProgress` | Just registered; wait | §1 |
| `Elb.InitialHealthChecking` | First checks running; wait | §1 |
| `Target.Timeout` | LB can't reach target / target too slow | §2 |
| `Target.ResponseCodeMismatch` | Wrong HTTP status from HC path | §3 |
| `Target.FailedHealthChecks` | Generic HC failure | §1–§3 |
| `Target.NotInUse` | Target not in an enabled AZ / TG not used | §4 |
| `Target.HealthCheckDisabled` | HC disabled on the TG | enable it |
| `Target.DeregistrationInProgress` | Draining (expected on scale-in) | §8 |

Also keep the CloudWatch ELB metrics open: `HealthyHostCount`, `UnHealthyHostCount`, `HTTPCode_ELB_5XX_Count`, `HTTPCode_Target_5XX_Count`, `TargetResponseTime`, `RejectedConnectionCount`.

---

## §1. All targets stay `unhealthy`

**The most common ELB problem.** Walk these in order:

1. **Security group path.** The app instance SG must allow the **health-check port** from the **ALB's security group**.
   ```bash
   # Confirm the app SG allows the ALB SG on the HC port (e.g. 80/8080)
   aws ec2 describe-security-groups --group-ids <app-sg> \
     --query 'SecurityGroups[0].IpPermissions'
   ```
   Fix: `aws ec2 authorize-security-group-ingress --group-id <app-sg> --protocol tcp --port <hc-port> --source-group <alb-sg>`

2. **App actually listening on the HC port.** SSH in: `sudo ss -tlnp | grep <port>`. If nothing's listening, the app/web server isn't up.

3. **HC path returns 200.** From the instance itself: `curl -i http://localhost:<port>/healthz`. If it's a 301/403/404/500, fix the path or the success matcher (§3).

4. **NACLs.** Subnet NACLs must allow the LB↔target traffic **both directions** (NACLs are stateless — allow ephemeral return ports 1024–65535 outbound).

5. **Right VPC/subnets/AZ.** The target group's VPC must match the instances'; the LB must have a subnet enabled in the target's AZ.

6. **Just wait.** `RegistrationInProgress`/`InitialHealthChecking` is normal for 30–90s.

💡 Quickest triage: `curl localhost/healthz` on the box (rules out the app) → if that's 200, it's **almost always the security group**.

---

## §2. `Target.Timeout`

The LB's probe never got a response in time.
- **Connectivity blocked** — SG/NACL/route. Most common: SG not allowing the LB. (See §1.1.)
- **App not listening** on the HC port (or bound to `127.0.0.1` only, not `0.0.0.0`).
- **App genuinely too slow** to answer within `health-check-timeout-seconds`. Confirm with `curl -w '%{time_total}' http://localhost/healthz` on the box; only raise the timeout if the app is legitimately slow.
- **Wrong port** — HC port ≠ the port the app serves.

Fix order: connectivity → listener binding → port → (last) timeout value.

---

## §3. `Target.ResponseCodeMismatch`

The HC path responded, but with a status outside the success matcher.
```bash
# What does the matcher expect?
aws elbv2 describe-target-groups --target-group-arns <tg-arn> --query 'TargetGroups[0].Matcher'
# What does the path actually return?
curl -i http://<instance-ip>:<port>/healthz
```
Common culprits:
- HC path hits `/` which **redirects (301/302)** to HTTPS — matcher only allows 200. Point HC at a non-redirecting path like `/healthz`, or widen matcher.
- Auth middleware returns **401/403** on the HC path. Exempt `/healthz` from auth.
- App returns **404** because the route doesn't exist. Add a real health route.

Fix: add a dedicated `/healthz` returning 200, OR set `--matcher HttpCode=200-399` if appropriate.

---

## §4. ALB returns 503 `Service Unavailable`

503 from the **ALB** almost always means **no healthy targets** in the target group the request mapped to.
```bash
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]'
```
- Empty result → all unhealthy → go to §1.
- Target group has **no registered targets** (e.g. ASG not attached, or scaled to 0).
- The **rule routed to the wrong/empty target group** — check listener rules:
  ```bash
  aws elbv2 describe-rules --listener-arn <listener-arn>
  ```
- During a deploy you drained 100% of targets at once → keep some healthy / use blue-green.

---

## §5. ALB returns 502 `Bad Gateway`

502 = the ALB reached a target but got a **malformed/failed response**.
- App **crashed mid-request** or closed the connection (check app logs).
- **Protocol mismatch** — target group is HTTPS but the app speaks HTTP (or vice versa). Match the target-group protocol to what the app actually serves.
- App **keep-alive timeout shorter than the ALB's** idle timeout (60s default) → ALB reuses a connection the app already closed. Set the app/server keep-alive **longer than 60s** (e.g. Node `server.keepAliveTimeout = 65000`).
- Response headers too large / invalid HTTP.

💡 504 (Gateway Timeout) instead = the target didn't respond within the ALB idle timeout — the app is too slow or hung. Look at `TargetResponseTime` and app threads/DB.

---

## §6. NLB: connections time out even though "the SG allows the LB"

🎯 **NLB preserves the client source IP.** With instance targets, the backend sees the **real client IP**, not the NLB. So the target SG must allow the **client CIDRs**, not an NLB SG.
- Fix: allow the expected client source ranges on the target SG (or `0.0.0.0/0` for a public service).
- Health checks come from the **VPC CIDR / link-local range** — ensure those are allowed too.
- If you used `target-type: ip` with **client-IP preservation disabled**, the targets see the NLB's private IPs instead — then allow the **subnet/NLB ENI CIDRs**. Know which mode you're in:
  ```bash
  aws elbv2 describe-target-group-attributes --target-group-arn <tg-arn> \
    --query "Attributes[?Key=='preserve_client_ip.enabled']"
  ```
- **NLB health-check failures are silent-ish** — always confirm with `describe-target-health`.

---

## §7. Uneven load across targets

- **NLB cross-zone is OFF by default** + unequal target counts per AZ → lopsided load. Enable cross-zone or balance AZ counts (mind inter-AZ cost).
- **Sticky sessions enabled** → clients pinned, some targets hot. Reduce duration or go stateless.
- A few **long-lived connections** (WebSocket/HTTP keep-alive) dominate — L4 balances *connections*, not requests. Consider `least_outstanding_requests` (ALB) or shorter keep-alive.
- One AZ has **fewer healthy targets** — check per-AZ health.

---

## §8. Deploys/scale-in cut off users mid-request

- **Deregistration delay too short.** Raise it to your longest reasonable request:
  ```bash
  aws elbv2 modify-target-group-attributes --target-group-arn <tg-arn> \
    --attributes Key=deregistration_delay.timeout_seconds,Value=60
  ```
- You removed **all** targets at once. Use rolling/blue-green so healthy capacity always remains.
- Long-lived connections (downloads/WebSockets) need a longer drain window — size accordingly.

---

## §9. HTTPS / certificate problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Certificate not found" attaching to listener | Cert in wrong **region** | Request/import ACM cert in the **LB's region** |
| ACM cert stuck `PENDING_VALIDATION` | DNS validation CNAME not created | Add the CNAME ACM provides (Route 53: one-click) |
| Browser shows cert for wrong domain | Missing **SNI** cert for that host | `add-listener-certificates` for each domain |
| Security scan flags TLS 1.0/1.1 | Old **SSL policy** | Switch to `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| Mixed-content / infinite redirect | App doesn't trust `X-Forwarded-Proto` | Make the app read XFP and build HTTPS URLs |
| Cert "expired" surprise | Imported (non-ACM) cert didn't auto-renew | Migrate to **ACM** for auto-renewal |

---

## §10. App sees wrong client IP / breaks behind the LB

- **ALB:** the app sees the ALB's private IP. Read the real client from **`X-Forwarded-For`** (and proto from `X-Forwarded-Proto`, port from `X-Forwarded-Port`). Configure your framework's trusted-proxy setting (`app.set('trust proxy', true)` in Express, `real_ip` in Nginx).
- **Redirect loops** after adding HTTPS: the app builds `http://` URLs because it doesn't know TLS terminated at the ALB. Trust `X-Forwarded-Proto`.
- **NLB:** source IP **is** preserved — if your app now logs client IPs as the LB, check whether `preserve_client_ip` is disabled (ip targets).

---

## §11. Latency / performance

- Check **`TargetResponseTime`** (app slowness) vs ALB processing time. High target time = app/DB problem, not the LB.
- **`RejectedConnectionCount` / surge queue** rising = backend can't keep up → scale out (raise ASG max, lower target-tracking value).
- **Idle timeout** (ALB default 60s) closing long requests → raise it for long polling/large uploads.
- **Cold new instances** erroring under sudden traffic → enable **slow start** + adequate **health-check grace period**.
- NLB adds ~microseconds; if latency is high with NLB, it's the backend, not the LB.

---

## §12. Auto Scaling + ELB integration issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| New instances launch but get no traffic | ASG not attached to target group | `--target-group-arns` on the ASG / `attach-load-balancer-target-groups` |
| ASG kills instances right after launch in a loop | Health-check grace period too short | Raise `--health-check-grace-period` to real boot time |
| LB-unhealthy instances never replaced | ASG `--health-check-type` is `EC2` | Set it to **`ELB`** |
| Scales on CPU but app is I/O-bound and still slow | Wrong scaling signal | Target-track on **`ALBRequestCountPerTarget`** |
| Thrashing (scale out/in repeatedly) | Cooldowns/target value too tight | Widen target value, add cooldown, use step scaling |

```bash
# Confirm the ASG↔target-group link and health type
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <asg> \
  --query 'AutoScalingGroups[0].{TGs:TargetGroupARNs,HC:HealthCheckType,Grace:HealthCheckGracePeriod}'
```

---

## §13. Access logs & deeper debugging

When metrics aren't enough, enable **ALB access logs** (to S3) — every request with timing, target, status, and processing-time breakdown:
```bash
aws elbv2 modify-load-balancer-attributes --load-balancer-arn <alb-arn> \
  --attributes Key=access_logs.s3.enabled,Value=true \
    Key=access_logs.s3.bucket,Value=<log-bucket>
```
Each log line splits time into `request_processing_time | target_processing_time | response_processing_time` — instantly tells you whether the LB or the backend is slow. A `-1` target time usually means the target never responded (connection failed). Query with **Athena** for patterns (top 5xx paths, slow endpoints, client IPs).

💡 Also enable **CloudTrail** to see *who changed* a listener/rule/SG when something "suddenly broke" — config changes are a top root cause.

---

## 🧭 30-second decision tree

```
LB returns error?
 ├─ 503 → no healthy targets → describe-target-health → §1 (SG/HC) or §4 (empty TG)
 ├─ 502 → bad target response → §5 (protocol/keep-alive/crash)
 ├─ 504 → target too slow/hung → §11 (latency) + app logs
 └─ TLS error → §9 (cert region/SNI/policy)

Targets unhealthy?
 ├─ reason Timeout       → §2 (connectivity/port)
 ├─ reason CodeMismatch  → §3 (path/matcher)
 └─ everything unhealthy → §1 (start with SG, then curl localhost/healthz)

Behind NLB and timing out? → §6 (source-IP changes the SG math)  ← check this first for NLB
App sees wrong IP / redirect loop? → §10 (X-Forwarded-For / -Proto)
Uneven load? → §7   Deploys cut off users? → §8   ASG not feeding traffic? → §12
```

---

## ✅ Troubleshooting principles
1. **`describe-target-health` first** — the reason field usually names the cause.
2. **`curl localhost/healthz` on the box** — splits "app broken" from "LB can't reach app."
3. **Security groups are the #1 cause** of unhealthy targets (and the NLB source-IP twist is #2).
4. **Match the layer to the symptom:** 5xx codes + access logs tell you LB-vs-target; metrics tell you scale.
5. **Change one thing, re-check health, repeat** — don't shotgun config edits.

➡️ Back to [README](README.md) · revisit [core concepts](01-elb-core-concepts.md) · drill [scenarios](04-scenarios.md).

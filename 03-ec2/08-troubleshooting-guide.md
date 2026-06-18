# Module 8 — EC2 Troubleshooting Guide

> Symptom → likely causes → diagnostic commands → fix. Organized by layer: connectivity, instance, web/Nginx, Node/PM2, database, performance, cost.

---

## A. Can't SSH into the instance

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Connection timed out` | SG doesn't allow 22 from your IP; no public IP; wrong subnet route | Add inbound SSH from your IP; ensure public IP + IGW route |
| `Permission denied (publickey)` | Wrong username or wrong/missing key | Use correct user (ec2-user/ubuntu); `-i correct-key.pem` |
| `UNPROTECTED PRIVATE KEY` | Key file too open | `chmod 400 key.pem` |
| Was working, now times out | Public IP changed after stop/start | Use an **Elastic IP**; re-check the new IP |
| Locked out (lost key) | No key access | Use **EC2 Instance Connect** or **SSM Session Manager**; or swap root volume |

```bash
ssh -vvv -i key.pem ec2-user@<ip>      # verbose debug
# check your current public IP for the SG rule:
curl ifconfig.me
```
💡 Also confirm the instance is **running** and passed **2/2 status checks** in the console.

---

## B. Instance status check failures

- **System status check failed** → AWS-side/hardware issue → **stop/start** (moves to new host).
- **Instance status check failed** → OS-side (bad fstab, full disk, kernel) → review **system log** / **EC2 Serial Console**.

```bash
aws ec2 get-console-output --instance-id i-0123   # see boot output
```
⚠️ A bad `/etc/fstab` entry can hang boot — that's why we add `nofail` to extra mounts.

---

## C. Website not loading

```
Step 1: Is the instance reachable?      ping / curl ifconfig.me from instance
Step 2: Is Nginx running?               sudo systemctl status nginx
Step 3: Is the SG allowing 80/443?      check inbound rules
Step 4: Does it work locally on box?    curl -I http://localhost
Step 5: DNS resolving to the EIP?       nslookup example.com
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| Browser hangs/timeout | SG missing 80/443 | Add inbound HTTP/HTTPS |
| `curl localhost` works, public doesn't | SG or OS firewall | Open SG; check `ufw`/`firewalld` |
| 502 Bad Gateway | Node/PM2 down or wrong proxy_pass port | `pm2 list`; fix port; SELinux bool |
| 403 Forbidden | Wrong root path / permissions | Fix `root`; `chmod`/`chown` web files |
| 404 on React routes | SPA fallback missing | add `try_files $uri /index.html;` |
| Old content shows | Browser/Nginx cache | hard refresh; clear cache; re-deploy |

```bash
sudo nginx -t                          # config valid?
sudo tail -f /var/log/nginx/error.log  # live errors
sudo ss -tulpn | grep -E ':80|:443'    # is Nginx listening?
```

---

## D. 502 / 504 (Node + PM2 issues)

```bash
pm2 list                 # is "api" online or errored/stopped?
pm2 logs api --lines 100 # crash stack trace
curl http://localhost:5000/health   # does Node respond directly?
sudo ss -tulpn | grep 5000          # is Node actually on 5000?
```
| Cause | Fix |
|-------|-----|
| Node crashed | `pm2 restart api`; fix the error in logs |
| Wrong port in Nginx `proxy_pass` | match the Node port |
| Node bound to wrong host | bind 127.0.0.1:5000 |
| 504 timeout (slow app/DB) | optimize query; raise `proxy_read_timeout` |
| App not restarting on reboot | `pm2 startup` + `pm2 save` |
| SELinux blocks proxy (AL/RHEL) | `sudo setsebool -P httpd_can_network_connect 1` |

---

## E. Database connection problems

```bash
# local MySQL/MariaDB
sudo systemctl status mariadb
mysql -u appuser -p -h 127.0.0.1 appdb     # can you connect?
# RDS
nc -zv mydb.xxx.rds.amazonaws.com 3306     # port reachable?
```
| Symptom | Cause | Fix |
|---------|-------|-----|
| `ECONNREFUSED` | DB not running / wrong host:port | start DB; check `DB_HOST` |
| `Access denied for user` | wrong creds / host grant | fix password; `GRANT ... @'localhost'/@'%'` |
| RDS timeout | SG not allowing 3306 from EC2 SG | add SG-to-SG rule on RDS |
| `Too many connections` | pool too big / leaks | use a pool; lower `connectionLimit`; close conns |
| Works in app, not after reboot | env not loaded | ensure `.env`/PM2 env present |

🔒 If you ever had to open 3306 to debug, **close it** afterward.

---

## F. SSL / HTTPS problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| Certbot fails to issue | DNS not pointing to server yet; 80 blocked | wait for DNS; open port 80 |
| `NET::ERR_CERT_*` | wrong domain / expired cert | reissue for correct `-d`; renew |
| Mixed content warnings | app loads http:// assets | use https:// or relative URLs |
| Cert expired | renew timer not running | `sudo certbot renew`; check timer |
| HTTPS works, HTTP doesn't redirect | no redirect block | add `return 301 https://...` |

```bash
sudo certbot certificates           # list certs + expiry
sudo certbot renew --dry-run        # test renewal
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## G. Performance issues

```bash
top / htop          # CPU & memory hogs
free -h             # is memory exhausted? (swap thrash)
df -h               # disk full? (logs/builds fill /)
iostat -x 1         # disk I/O (sysstat)
pm2 monit           # per-process Node usage
```
| Symptom | Cause | Fix |
|---------|-------|-----|
| High CPU, burstable throttling | T-instance out of credits | switch to M/C type or T Unlimited |
| Out of memory / OOM killer | undersized instance / leak | add swap; bigger type; fix leak |
| Disk full | logs, old builds, snapshots-on-disk | clean logs (`pm2 flush`), `journalctl --vacuum-time=7d`, grow EBS |
| Slow under load | single instance maxed | scale out (ASG + ALB); cache; CDN |
| Slow DB | missing index / N+1 | add indexes; optimize queries; RDS sizing |

**Disk full quick wins:**
```bash
sudo journalctl --vacuum-size=200M
pm2 flush
sudo dnf clean all   # or sudo apt clean
du -sh /var/* | sort -h
```

---

## H. Unexpected cost 💰

| Symptom | Cause | Fix |
|---------|-------|-----|
| Bill higher than expected | instance left running; oversized | stop/terminate; rightsize |
| Charged for Elastic IP | idle/unattached EIP or extra public IPv4 | release unused EIPs |
| Storage charges after terminate | volumes/snapshots not deleted | delete orphaned EBS + snapshots |
| Big data transfer | high egress / inter-AZ chatter | CloudFront; keep traffic in-AZ |
| NAT Gateway costs | running 24/7 + data | review need; use VPC endpoints |

Investigate with **Cost Explorer** (group by service/usage type) and set **Budgets** ([Phase 01 Billing Guide](../01-aws-fundamentals/06-billing-guide.md)).

---

## General Diagnostic Order (memorize)
```
1. Reproduce & note the exact error
2. Layer down: DNS → SG → Nginx → PM2/Node → DB
3. Check the right log for that layer
4. Verify locally on the box (curl localhost) vs externally
5. Change ONE thing, test, repeat
6. Confirm fix survives a reboot
```

## Essential Logs Cheat Sheet
```
Boot/user-data : /var/log/cloud-init-output.log
System         : /var/log/messages (AL) | /var/log/syslog (Ubuntu)
Nginx          : /var/log/nginx/access.log , error.log
Node (PM2)     : pm2 logs api  (or ~/.pm2/logs/)
MySQL/MariaDB  : /var/log/mariadb/ | /var/log/mysql/
systemd unit   : journalctl -u <service> -f
Console (AWS)  : aws ec2 get-console-output --instance-id i-xxx
```

---

➡️ Next: [09-100-mcqs.md](09-100-mcqs.md)

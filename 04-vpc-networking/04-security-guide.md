# Module 4 — VPC Security Guide

Network security in AWS is **layered**. No single control protects you — you stack them so a failure in one is caught by the next (**defense in depth**). This guide covers every layer, the rules that matter, and how to audit yourself.

> 🔒 = security control · ⚠️ = risk · 💡 = best practice

---

## 1. The defense-in-depth stack

```
   Internet
      │
   ┌──▼─────────────────────────────────────────────────────────┐
   │ 1. EDGE        WAF + Shield (DDoS) + CloudFront              │  block bad requests early
   ├─────────────────────────────────────────────────────────────┤
   │ 2. NETWORK     Public/private subnet design + route tables   │  no path = no attack
   ├─────────────────────────────────────────────────────────────┤
   │ 3. SUBNET      NACLs (stateless, allow+deny)                 │  coarse subnet firewall
   ├─────────────────────────────────────────────────────────────┤
   │ 4. INSTANCE    Security Groups (stateful, allow-only)        │  per-resource firewall
   ├─────────────────────────────────────────────────────────────┤
   │ 5. INSPECTION  AWS Network Firewall / IDS-IPS, Flow Logs     │  detect + block payloads
   ├─────────────────────────────────────────────────────────────┤
   │ 6. IDENTITY    IAM, SSM (no SSH), Secrets Manager            │  who/what can act
   ├─────────────────────────────────────────────────────────────┤
   │ 7. DATA        Encryption in transit (TLS) + at rest (KMS)   │  last line
   └─────────────────────────────────────────────────────────────┘
   An attacker must defeat EVERY layer. Each one is independent.
```

---

## 2. Network design = your first firewall

The cheapest, strongest control is **not having a path** to a resource at all.

```
   🔒 Put as little as possible in public subnets:
        Public  → ALB, NAT GW only          (the attack surface)
        Private → app servers (route to NAT)
        Isolated→ databases (NO internet route at all)

   🔒 Default-deny posture:
        - No 0.0.0.0/0 → IGW on app/data subnets
        - No public IPs on app/data instances
        - Databases reachable ONLY from the app SG
```
⚠️ A database in a public subnet with `0.0.0.0/0` open on 3306 is the single most common breach pattern. The fix is **architecture**, not just firewall rules.

---

## 3. Security Groups — do it right

Stateful, instance-level, **allow-only**. Your primary, most-used control.

```
   🔒 SG CHAINING (reference SGs, never hard-code IPs):
        world ──443──► sg-alb ──app port──► sg-app ──db port──► sg-db
        Each tier trusts ONLY the SG in front of it.

   ✅ DO                                  ⚠️ DON'T
   ─────────────────────────────────     ──────────────────────────────────
   Reference source SG by ID             Open 0.0.0.0/0 on 22 / 3389 / 3306
   Scope to exact port + protocol        Use 0.0.0.0/0 "temporarily" (it stays)
   Separate SG per tier/role             One giant "allow everything" SG
   Least-privilege egress where needed   Leave wide-open egress unreviewed
   Use SSM instead of inbound SSH        Keep bastions with public 22
```

💡 **Restrict admin access to your IP / a bastion / SSM only:**
```bash
# good: SSH only from the corporate CIDR
aws ec2 authorize-security-group-ingress --group-id sg-app \
  --protocol tcp --port 22 --cidr 203.0.113.0/24
# better: no SSH at all — use SSM Session Manager (see §6)
```
⚠️ SGs have **no deny rule**. To explicitly block a bad actor, use a **NACL**.

---

## 4. NACLs — the subnet backstop

Stateless, subnet-level, **allow + deny**, numbered. Use them where SGs can't help.

```
   🔒 Good NACL uses:
        - DENY a known-bad IP/CIDR for an ENTIRE subnet (SGs can't deny)
        - Coarse guardrail: e.g. data subnet NACL only permits the app subnet CIDR
        - Compliance "second pair of eyes" on top of SGs

   ⚠️ Stateless gotcha (security-relevant):
        Allowing inbound 443 needs outbound 1024-65535 for replies.
        Over-broad ephemeral allows weaken the NACL — scope the CIDR tightly.
```
💡 Keep NACLs **simple** (a handful of rules). Complex NACLs cause outages and a false sense of security. Let SGs do the fine-grained work.

---

## 5. Inspection & monitoring

You can't secure what you can't see.

| 🔒 Control | What it does |
|-----------|--------------|
| **VPC Flow Logs** | Records ACCEPT/REJECT per flow → detect scans, exfil, misconfig |
| **AWS Network Firewall** | Stateful L3–L7 firewall; domain filtering, IPS rules, central inspection |
| **GuardDuty** | ML threat detection on Flow Logs/DNS/CloudTrail (crypto-mining, recon, exfil) |
| **Traffic Mirroring** | Copy packets to an IDS/IPS appliance for deep inspection |
| **Reachability Analyzer** | Prove whether a path exists between two ENIs |
| **Network Access Analyzer** | Find unintended internet-reachable resources |

💡 **Enterprise pattern:** route all inter-VPC + egress traffic through a **central inspection VPC** (Network Firewall) via Transit Gateway, with **Flow Logs** to S3 and **GuardDuty** enabled org-wide.

**Reading a Flow Log for security:**
```
   ... 198.51.100.7 10.0.2.10 44321 22 6 ... REJECT OK   ← someone scanned SSH; blocked ✅
   ... 10.0.2.10 185.x.x.x 50112 4444 6 ... ACCEPT OK    ← outbound to odd port — investigate ⚠️
```

---

## 6. Identity & access (kill SSH)

```
   🔒 SSM Session Manager instead of SSH/bastion:
        - No port 22 open, no key pairs to leak, no bastion to patch
        - Full IAM control + audit log of every session
        - Works on PRIVATE instances via interface endpoints
          (ssm, ssmmessages, ec2messages) — no internet needed

   🔒 Also:
        - Instance roles (no long-lived keys on hosts)
        - Secrets Manager / Parameter Store for DB creds (not env files)
        - VPC endpoint policies + SG on interface endpoints
```
💡 Removing inbound 22 from your whole fleet eliminates an entire class of attacks (brute force, leaked keys, exposed bastions).

---

## 7. Encryption

```
   IN TRANSIT:  TLS everywhere — ALB→client (ACM cert), app→RDS (require SSL),
                VPC peering/TGW cross-Region traffic is encrypted on the backbone.
   AT REST:     EBS, RDS, S3 with KMS keys.
   PRIVATE PATHS: VPC endpoints keep AWS-service traffic off the internet entirely.
```

---

## 8. Common misconfigurations (audit for these)

```
   ⚠️ TOP VPC SECURITY MISTAKES
   ───────────────────────────────────────────────────────────────
   1. 0.0.0.0/0 inbound on 22 / 3389 / 3306 / 5432 / 6379
   2. Database in a PUBLIC subnet
   3. App/DB instances with public IPs that don't need them
   4. One over-permissive "shared" security group on everything
   5. NACL that accidentally blocks return (ephemeral) traffic → outage
   6. No Flow Logs → blind to scans and exfiltration
   7. Overlapping CIDRs blocking future secure peering
   8. Wide-open egress allowing data exfiltration to anywhere
   9. Long-lived SSH keys + public bastions instead of SSM
   10. Endpoint/peering with no endpoint policy (over-broad service access)
```

---

## 9. Security audit checklist

```
   NETWORK
   □ Databases in isolated subnets, no internet route?
   □ No app/DB instances with public IPs?
   □ Only ALB + NAT in public subnets?

   FIREWALL
   □ SGs reference other SGs (not 0.0.0.0/0) for internal tiers?
   □ No 0.0.0.0/0 on admin ports anywhere?
   □ NACLs used to deny known-bad CIDRs where needed?
   □ Egress restricted on sensitive tiers?

   VISIBILITY
   □ VPC Flow Logs enabled (to S3) on every VPC?
   □ GuardDuty on? Findings triaged?
   □ Reachability / Network Access Analyzer run for exposure?

   ACCESS
   □ SSM Session Manager replacing SSH? No public bastions?
   □ Instance roles + Secrets Manager (no static keys/creds)?
   □ Interface endpoints have tight SGs + endpoint policies?

   CRYPTO
   □ TLS enforced client→ALB and app→DB?
   □ At-rest encryption on EBS/RDS/S3?
```

---

## 🔒 Top 5 takeaways

1. **Architecture is the first firewall** — keep DBs isolated with no internet path.
2. **Chain security groups**, reference by SG-id, never `0.0.0.0/0` on internal/admin ports.
3. **NACLs deny; SGs allow** — use NACLs to block bad CIDRs, SGs for fine-grained allow.
4. **Turn on Flow Logs + GuardDuty** — you can't defend what you can't see.
5. **Kill SSH with SSM** — removes keys, bastions, and port 22 as an attack surface.

**Next:** [05-troubleshooting.md](05-troubleshooting.md).

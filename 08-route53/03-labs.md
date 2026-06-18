# Module 3 — Route 53 Hands-On Labs

> Learn by doing. 🛠️ = action · 💰 = cost · ⚠️ = cleanup. Includes `dig`/`nslookup` verification so you can *see* DNS working.

> **Setup:** AWS account with MFA + a Budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Install AWS CLI v2 (`aws configure` as a least-privilege IAM user). 💰 A hosted zone costs ~$0.50/month; a registered domain costs yearly. Replace `example.com` with a domain you control.

> 💡 **No domain?** You can still do Labs 0, 5, 7, 8 (concepts, dig, health checks) and read the rest. To do real resolution you need a domain (register in Lab 1 or bring your own).

---

## Lab 0 — DNS Detective with dig/nslookup (20 min) 🛠️
Look up real records and read the DNS hierarchy.
```bash
dig example.com                 # A records + answer section
dig example.com A +short        # just the IPs
dig www.example.com CNAME +short
dig example.com MX +short       # mail servers
dig example.com TXT +short      # SPF/verification
dig example.com NS +short       # the authoritative name servers
dig +trace example.com          # walk root → TLD → authoritative
nslookup example.com            # (Windows-friendly)
dig @8.8.8.8 example.com        # query a specific resolver
```
**Learn:** record types, TTLs (the number before IN), the NS delegation chain.

---

## Lab 1 — Register / Bring a Domain (20 min) 🛠️💰
**Option A — Register in Route 53:**
1. 🛠️ Route 53 → **Registered domains → Register domain** → search a name → buy. 💰
2. Route 53 auto-creates a **hosted zone** and sets the NS records.
3. 🛠️ Enable **auto-renew** + **privacy protection**.

**Option B — Bring an external domain:**
1. 🛠️ Create a hosted zone (Lab 2) and copy its 4 **NS** records.
2. 🛠️ At your current registrar, replace the NS with Route 53's 4 NS.
3. 🛠️ Verify delegation: `dig example.com NS +short` should show the Route 53 NS.

---

## Lab 2 — Create a Hosted Zone (15 min) 🛠️
```bash
aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)
ZID=$(aws route53 list-hosted-zones-by-name --dns-name example.com \
  --query 'HostedZones[0].Id' --output text)
echo "Hosted Zone: $ZID"
aws route53 get-hosted-zone --id $ZID --query 'DelegationSet.NameServers'   # the 4 NS
aws route53 list-resource-record-sets --hosted-zone-id $ZID                  # NS + SOA exist
```
**Learn:** public hosted zone, auto-created NS/SOA. ⚠️ Deleting/recreating changes the NS.

---

## Lab 3 — Create A and CNAME Records (25 min) 🛠️
```bash
# A record: www → an IP (e.g., your EC2 Elastic IP)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"www.example.com","Type":"A","TTL":300,
    "ResourceRecords":[{"Value":"203.0.113.10"}]}}]}'

# CNAME: blog → an external host
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"blog.example.com","Type":"CNAME","TTL":300,
    "ResourceRecords":[{"Value":"myblog.hostingprovider.com"}]}}]}'

# verify
dig www.example.com A +short
dig blog.example.com CNAME +short
```
⚠️ Try adding a CNAME at the apex (`example.com`) — it fails. That's why apex needs **Alias** (Lab 4).

---

## Lab 4 — Alias Records to AWS Resources (25 min) 🛠️
Point the apex at CloudFront/ALB/S3 (free, apex-capable).
```bash
# Alias apex → an ALB (use the ALB's canonical hosted zone id + DNS name)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
 "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
   "Name":"example.com","Type":"A",
   "AliasTarget":{"HostedZoneId":"ZXXXXALBZONE",
     "DNSName":"my-alb-123.ap-south-1.elb.amazonaws.com",
     "EvaluateTargetHealth":true}}}]}'
```
> In the **console** this is far easier: choose "Alias", pick the resource type, and Route 53 fills the zone ID. Targets: CloudFront, ALB/NLB, S3 website, API Gateway, another record.
**Learn:** Alias vs CNAME, apex support, EvaluateTargetHealth.

---

## Lab 5 — MX + TXT for Email & Verification (20 min) 🛠️
```bash
# MX: route mail (priority 10)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"example.com","Type":"MX","TTL":3600,
    "ResourceRecords":[{"Value":"10 mail.mailprovider.com"}]}}]}'

# TXT: SPF + a verification string
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"example.com","Type":"TXT","TTL":3600,
    "ResourceRecords":[
      {"Value":"\"v=spf1 include:_spf.mailprovider.com ~all\""},
      {"Value":"\"google-site-verification=abc123\""}]}}]}'

dig example.com MX +short
dig example.com TXT +short
```
**Learn:** email routing (priority), SPF/verification via TXT, quoting.

---

## Lab 6 — Weighted Routing (Canary) (25 min) 🛠️
Split traffic 90/10 between two endpoints.
```bash
# 90% → v1
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
 "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
   "Name":"app.example.com","Type":"A","TTL":60,"SetIdentifier":"v1",
   "Weight":90,"ResourceRecords":[{"Value":"203.0.113.11"}]}}]}'
# 10% → v2 (canary)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
 "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
   "Name":"app.example.com","Type":"A","TTL":60,"SetIdentifier":"v2",
   "Weight":10,"ResourceRecords":[{"Value":"203.0.113.12"}]}}]}'
dig app.example.com +short      # repeat; you'll see the weighted distribution over time
```
**Learn:** routing policies need a unique `SetIdentifier` per record; weights split traffic.

---

## Lab 7 — Health Check + Failover (35 min) 🛠️
Active-passive: primary with a health check, secondary standby.
```bash
# 1) health check on the primary endpoint
HC=$(aws route53 create-health-check --caller-reference $(date +%s) \
  --health-check-config '{"Type":"HTTPS","FullyQualifiedDomainName":"api.example.com",
    "Port":443,"ResourcePath":"/health","RequestInterval":30,"FailureThreshold":3}' \
  --query 'HealthCheck.Id' --output text)
echo "Health check: $HC"

# 2) PRIMARY record (with health check)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch "{
 \"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{
   \"Name\":\"api.example.com\",\"Type\":\"A\",\"TTL\":60,\"SetIdentifier\":\"primary\",
   \"Failover\":\"PRIMARY\",\"HealthCheckId\":\"$HC\",
   \"ResourceRecords\":[{\"Value\":\"203.0.113.21\"}]}}]}"

# 3) SECONDARY record (standby)
aws route53 change-resource-record-sets --hosted-zone-id $ZID --change-batch '{
 "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
   "Name":"api.example.com","Type":"A","TTL":60,"SetIdentifier":"secondary",
   "Failover":"SECONDARY","ResourceRecords":[{"Value":"203.0.113.99"}]}}]}'
```
**Test:** stop the primary endpoint → after the failure threshold, `dig api.example.com +short` returns the **secondary**.
**Learn:** health checks drive failover; lower TTL = faster failover for clients.

---

## Lab 8 — ACM Certificate + HTTPS via DNS Validation (30 min) 🛠️🔒
```bash
# request a wildcard cert (for CloudFront, request in us-east-1!)
aws acm request-certificate --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS --region us-east-1
# ACM returns CNAME validation records → easiest: in ACM console click
# "Create records in Route 53" to auto-add them. Cert then issues + auto-renews.
aws acm list-certificates --region us-east-1
```
**Learn:** DNS validation = add a CNAME → ACM verifies → free auto-renewing cert. See [Module 2 §2](02-architectures.md#2-ssl-architecture).
⚠️ Don't delete the validation CNAMEs (renewal depends on them).

---

## Lab 9 — Full React + API Domain Wiring (45 min) 🛠️
Combine everything (needs Phase 03 ALB and/or Phase 05 CloudFront already deployed):
```
1. ACM cert: example.com + *.example.com (us-east-1 for CloudFront)  [Lab 8]
2. Alias  example.com / www → CloudFront (React on S3)               [Module 2 §3]
3. Alias  api.example.com  → ALB (Node API)                          [Module 2 §4]
4. dig each name; browse https://example.com and curl https://api.example.com/health
```
**Learn:** the real-world end-to-end domain setup for a full-stack app.

---

## 🧹 Cleanup 💰
```bash
# delete records you created (set Action=DELETE with the exact record values)
# delete the health check
aws route53 delete-health-check --health-check-id $HC
# delete the hosted zone (must be empty of non-NS/SOA records first)
aws route53 delete-hosted-zone --id $ZID
# NOTE: a registered domain keeps billing until it expires; disable auto-renew if not needed
```
✅ Confirm the Billing Dashboard trends down (hosted zone charge stops after deletion).

➡️ Next: [04-troubleshooting.md](04-troubleshooting.md)

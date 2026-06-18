# Module 3 — Hands-On Labs

> Build a real, highly-available, auto-scaling web tier behind an ALB — then extend it with HTTPS, stickiness, an NLB, and blue/green. Console steps where it helps; **AWS CLI v2** for everything repeatable.

**Conventions:** 🛠️ = run this · ⚠️ = gotcha · 🔒 = security · 💰 = cost · 💡 = tip
Replace every `<placeholder>` with your own ID. Set a couple of env vars first to keep commands short.

> 💰 **Before you start:** an ALB/NLB bills ~$16/mo **just for existing**. Do the labs in one or two sittings and run the **[teardown](#lab-9--teardown-do-this)** at the end. Set a billing alarm.

```bash
# Pick a region and load common IDs once (edit values for your account)
export AWS_DEFAULT_REGION=ap-south-1
export VPC=<vpc-id>
export SUBNET_PUB_A=<public-subnet-az-a>
export SUBNET_PUB_B=<public-subnet-az-b>
export SUBNET_PRV_A=<private-subnet-az-a>
export SUBNET_PRV_B=<private-subnet-az-b>
```

---

## Lab 0 — Prerequisites checklist

You need:
- [ ] A VPC with **2 public + 2 private subnets across 2 AZs** ([Phase 04 — VPC](../04-vpc-networking/README.md)).
- [ ] AWS CLI v2 configured (`aws sts get-caller-identity` works).
- [ ] A way to launch a small web app on EC2 (we use a 3-line user-data Nginx below — no app needed).
- [ ] (Labs 4–5) A domain you control, ideally in Route 53, for the ACM cert.

💡 If you don't have a VPC yet, the **default VPC** has public subnets in every AZ — fine for Labs 1–3. You just won't have private subnets to hide instances in.

---

## Lab 1 — Two web servers + Security Groups

### 1.1 Create the ALB and instance security groups
```bash
# ALB SG: allow 80/443 from the internet
ALB_SG=$(aws ec2 create-security-group --group-name lab-alb-sg \
  --description "ALB ingress" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# App SG: allow 80 ONLY from the ALB SG (the key security pattern)
APP_SG=$(aws ec2 create-security-group --group-name lab-app-sg \
  --description "App from ALB only" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $APP_SG \
  --protocol tcp --port 80 --source-group $ALB_SG
```
🔒 Note we used `--source-group`, not a CIDR — the app only accepts traffic from the ALB.

### 1.2 Launch two instances in different AZs
User-data installs Nginx and writes the AZ + instance-id into the page and a `/healthz` file, so you can *see* load balancing working.
```bash
cat > userdata.sh <<'EOF'
#!/bin/bash
dnf install -y nginx || yum install -y nginx
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Served by $ID in $AZ" > /usr/share/nginx/html/index.html
echo "ok" > /usr/share/nginx/html/healthz
systemctl enable --now nginx
EOF

for SUBNET in $SUBNET_PUB_A $SUBNET_PUB_B; do
  aws ec2 run-instances --image-id <amazon-linux-2023-ami> \
    --instance-type t3.micro --security-group-ids $APP_SG \
    --subnet-id $SUBNET --user-data file://userdata.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lab-web}]'
done
```
⚠️ Use a current Amazon Linux 2023 AMI for your region (`aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query 'Parameters[0].Value' --output text`).

Grab the two instance IDs:
```bash
INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-web" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text)
echo $INSTANCES
```

---

## Lab 2 — Target Group + Health Checks

### 2.1 Create the target group with a real health check
```bash
TG=$(aws elbv2 create-target-group --name lab-tg-web \
  --protocol HTTP --port 80 --vpc-id $VPC --target-type instance \
  --health-check-protocol HTTP --health-check-path /healthz \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --health-check-interval-seconds 15 --health-check-timeout-seconds 5 \
  --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### 2.2 Register both instances
```bash
for I in $INSTANCES; do
  aws elbv2 register-targets --target-group-arn $TG --targets Id=$I
done
```

### 2.3 Watch them become healthy
```bash
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```
Repeat until both show `healthy` (≈30–45s). If they stay `unhealthy`, jump to [troubleshooting §1](05-troubleshooting.md).

💡 **Lab exercise:** SSH to one instance and `sudo systemctl stop nginx`. Within ~30s its health flips to `unhealthy` and the ALB stops sending it traffic. Start nginx again → it returns to `healthy`. *That's automatic failover.*

---

## Lab 3 — Application Load Balancer (HTTP)

### 3.1 Create the ALB across both AZs
```bash
ALB_ARN=$(aws elbv2 create-load-balancer --name lab-alb \
  --type application --scheme internet-facing \
  --subnets $SUBNET_PUB_A $SUBNET_PUB_B \
  --security-groups $ALB_SG \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' --output text)
echo "http://$ALB_DNS"
```
⚠️ Two subnets in **different AZs** are mandatory — that's what makes it HA.

### 3.2 Add an HTTP listener that forwards to the target group
```bash
aws elbv2 create-listener --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG
```

### 3.3 Test load balancing
```bash
for i in $(seq 1 6); do curl -s http://$ALB_DNS/ ; done
```
You should see responses alternating between the two instance IDs/AZs. 🎉 You have a load-balanced, multi-AZ web tier.

---

## Lab 4 — HTTPS / SSL Termination with ACM

*(Requires a domain. DNS validation via Route 53 is easiest.)*

### 4.1 Request a certificate
```bash
CERT=$(aws acm request-certificate --domain-name app.example.com \
  --validation-method DNS --query CertificateArn --output text)
# Get the CNAME to create:
aws acm describe-certificate --certificate-arn $CERT \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```
Create that CNAME in your DNS (Route 53 console: "Create record in Route 53" button does it instantly). Wait for status `ISSUED`:
```bash
aws acm describe-certificate --certificate-arn $CERT --query 'Certificate.Status'
```

### 4.2 Add an HTTPS:443 listener with the cert
```bash
aws elbv2 create-listener --load-balancer-arn $ALB_ARN \
  --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=$TG
```

### 4.3 Redirect HTTP → HTTPS
Find the HTTP listener ARN and replace its action with a redirect:
```bash
HTTP_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`80\`].ListenerArn" --output text)

aws elbv2 modify-listener --listener-arn $HTTP_LISTENER \
  --default-actions '[{"Type":"redirect","RedirectConfig":{
    "Protocol":"HTTPS","Port":"443","StatusCode":"HTTP_301"}}]'
```

### 4.4 Point your domain at the ALB & test
Create a Route 53 **A / ALIAS** record `app.example.com → lab-alb DNS`. Then:
```bash
curl -I http://app.example.com      # → 301 to https
curl -sI https://app.example.com    # → 200, TLS terminated at the ALB
```
🔒 Confirm the cert and that TLS 1.0/1.1 are rejected: `nmap --script ssl-enum-ciphers -p 443 app.example.com` (or SSL Labs).

---

## Lab 5 — Path-based routing

Add a second target group and route `/api/*` to it.

```bash
# (assume you created TG-api and registered API instances the same way as Lab 2)
HTTPS_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`443\`].ListenerArn" --output text)

aws elbv2 create-rule --listener-arn $HTTPS_LISTENER --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=<tg-api-arn>
```
Now `https://app.example.com/api/...` hits the API fleet; everything else hits the web fleet (default action). 💡 Add `/static/*` → S3 redirect, `admin.example.com` host rule, etc.

---

## Lab 6 — Sticky sessions (and proving statelessness is better)

### 6.1 Turn on duration-based stickiness
```bash
aws elbv2 modify-target-group-attributes --target-group-arn $TG \
  --attributes Key=stickiness.enabled,Value=true \
    Key=stickiness.type,Value=lb_cookie \
    Key=stickiness.lb_cookie.duration_seconds,Value=300
```

### 6.2 Observe the pin
```bash
# -c saves cookies; subsequent requests reuse the AWSALB cookie → same instance
curl -s -c cookies.txt http://$ALB_DNS/
for i in $(seq 1 5); do curl -s -b cookies.txt http://$ALB_DNS/ ; done
```
All five now return the **same** instance. Delete `cookies.txt` and you round-robin again.

💡 **Reflection:** notice load is now uneven and a target loss would drop those users' sessions. In a real app you'd instead store sessions in **ElastiCache/Redis** and turn stickiness **off**. Turn it back off:
```bash
aws elbv2 modify-target-group-attributes --target-group-arn $TG \
  --attributes Key=stickiness.enabled,Value=false
```

---

## Lab 7 — Auto Scaling integration

Replace the hand-registered instances with a self-healing, auto-scaling group.

### 7.1 Launch template (same user-data, private subnets, app SG)
```bash
LT=$(aws ec2 create-launch-template --launch-template-name lab-lt \
  --launch-template-data "{
    \"ImageId\":\"<al2023-ami>\",
    \"InstanceType\":\"t3.micro\",
    \"SecurityGroupIds\":[\"$APP_SG\"],
    \"UserData\":\"$(base64 -w0 userdata.sh)\"
  }" --query 'LaunchTemplate.LaunchTemplateId' --output text)
```

### 7.2 ASG attached to the target group, ELB health checks
```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name lab-asg \
  --launch-template LaunchTemplateId=$LT,Version='$Latest' \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "$SUBNET_PRV_A,$SUBNET_PRV_B" \
  --target-group-arns $TG \
  --health-check-type ELB --health-check-grace-period 120
```
The ASG **auto-registers** its instances into `$TG`. Watch them appear:
```bash
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].TargetHealth.State' --output text
```

### 7.3 Add traffic-based scaling
```bash
aws autoscaling put-scaling-policy --auto-scaling-group-name lab-asg \
  --policy-name tt-req --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification":{
      "PredefinedMetricType":"ALBRequestCountPerTarget",
      "ResourceLabel":"<app/lab-alb/xxxx>/<targetgroup/lab-tg-web/yyyy>"},
    "TargetValue":500.0}'
```
(Get the `ResourceLabel` from `aws elbv2 describe-target-groups` — it's `<alb-suffix>/<tg-suffix>`.)

### 7.4 Prove self-healing
Terminate one instance manually. The ASG detects the missing/unhealthy target and **launches a replacement** in the same AZ, which auto-registers and goes healthy. Zero manual steps.

💡 **Load test (optional):** `ab -n 20000 -c 200 http://$ALB_DNS/` or `hey -z 2m -c 100 http://$ALB_DNS/`, then watch the ASG scale out in the EC2 console.

---

## Lab 8 — (Optional) Network Load Balancer

Stand up an NLB to feel the L4 difference (static IPs, source-IP preservation).

```bash
NLB_ARN=$(aws elbv2 create-load-balancer --name lab-nlb \
  --type network --scheme internet-facing \
  --subnet-mappings SubnetId=$SUBNET_PUB_A SubnetId=$SUBNET_PUB_B \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

TG_TCP=$(aws elbv2 create-target-group --name lab-tg-tcp \
  --protocol TCP --port 80 --vpc-id $VPC --target-type instance \
  --health-check-protocol HTTP --health-check-path /healthz \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 register-targets --target-group-arn $TG_TCP \
  --targets $(for I in $INSTANCES; do echo Id=$I; done)

aws elbv2 create-listener --load-balancer-arn $NLB_ARN \
  --protocol TCP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_TCP
```
⚠️ **Source-IP gotcha:** with NLB instance targets, the backend sees the **client IP**, so the app SG (`$APP_SG`) currently only allows the ALB SG — NLB traffic will be **blocked**. To test the NLB, temporarily allow `0.0.0.0/0` on port 80 (lab only!) or, better, see [troubleshooting §6](05-troubleshooting.md). This is *the* NLB lesson — feel it firsthand.

💡 To get fixed IPs, recreate with `--subnet-mappings SubnetId=...,AllocationId=<eip-alloc-id>` per AZ.

---

## Lab 9 — Teardown (DO THIS)

💰 Delete in dependency order so nothing is "in use":
```bash
# 1. ASG (terminates its instances)
aws autoscaling update-auto-scaling-group --auto-scaling-group-name lab-asg --min-size 0 --desired-capacity 0
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name lab-asg --force-delete

# 2. Listeners, then load balancers
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN   # if created

# 3. Target groups (after LBs are gone)
aws elbv2 delete-target-group --target-group-arn $TG
aws elbv2 delete-target-group --target-group-arn $TG_TCP      # if created

# 4. Any manually-launched instances
aws ec2 terminate-instances --instance-ids $INSTANCES

# 5. Launch template, security groups (app SG before alb SG due to the reference)
aws ec2 delete-launch-template --launch-template-id $LT
aws ec2 delete-security-group --group-id $APP_SG
aws ec2 delete-security-group --group-id $ALB_SG
```
Verify in the console that **no load balancers remain** (that's the recurring charge). ACM certs are free to keep.

---

## 🧪 Stretch challenges
1. **Blue/Green:** create `tg-green`, point a test host-rule at it, then flip the default action's weights 90/10 → 0/100. Roll back instantly by flipping back.
2. **End-to-end TLS:** put a self-signed cert on the instances and switch the target group protocol to HTTPS so the ALB **re-encrypts**.
3. **Internal ALB:** create a second, `--scheme internal` ALB and call it from an instance to simulate a backend tier.
4. **Alarms:** create CloudWatch alarms on `UnHealthyHostCount > 0` and `HTTPCode_ELB_5XX_Count` → SNS email.

➡️ Next: practice with [04-scenarios.md](04-scenarios.md), keep [05-troubleshooting.md](05-troubleshooting.md) handy.

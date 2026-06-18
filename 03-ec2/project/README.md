# Capstone Project — Deploy React + Node.js + MySQL on EC2

> A complete, copy-paste, end-to-end deployment of a full-stack **Todo app**: React front end, Node.js/Express API, MySQL database — served by **Nginx** with **PM2**, secured with **HTTPS (Let's Encrypt)**, on a **custom domain**, all on a single **EC2** instance.

This project ties together every Phase 03 module. By the end you'll have a live, secured web app and the muscle memory to deploy any MERN-style stack.

---

## 📐 Target Architecture

```
   Internet
      │  https://todo.example.com
      ▼
   Route 53 / registrar  ──A record──►  Elastic IP
      │
      ▼
   ┌──────────────────────── EC2 (t3.small, Amazon Linux 2023) ───────────────────────┐
   │  Security Group: 22 (your IP), 80, 443 (all)                                       │
   │                                                                                   │
   │  Nginx :443 (Let's Encrypt TLS, redirects 80→443)                                 │
   │    ├── "/"      → serves React build  (/var/www/todo-frontend)                    │
   │    └── "/api/"  → reverse proxy → Node/Express (PM2) 127.0.0.1:5000               │
   │                                                                                   │
   │  Node API (PM2 cluster) ──► MySQL/MariaDB :3306 (localhost only)                  │
   │  EBS gp3 root volume + swap                                                        │
   └───────────────────────────────────────────────────────────────────────────────────┘
```

> Want production HA later? Evolve to ALB + Auto Scaling + RDS Multi-AZ (see [Module 2](../02-ec2-architecture.md) §3).

---

## ✅ Prerequisites
- AWS account with MFA + a Budget alert ([Phase 01 setup](../../01-aws-fundamentals/05-aws-account-setup-guide.md)).
- A registered domain (optional but recommended for the SSL step).
- This `project/` folder contains sample app code: `backend/` and `frontend/`. You can use it or your own repo.
- 💰 A `t3.small`/`t4g.small` left running ~ $15–17/month. **Stop or terminate when done.**

---

## 🗺️ Steps Overview
1. Launch & secure the EC2 instance
2. Connect and prep the server
3. Install the stack (Node, PM2, Nginx, MariaDB)
4. Set up the MySQL database
5. Deploy the Node.js backend (PM2)
6. Deploy the React frontend (build → Nginx)
7. Configure Nginx (static + API proxy)
8. Map the domain (Elastic IP + DNS)
9. Enable HTTPS (Certbot)
10. Verify, harden, and clean up

---

## Step 1 — Launch & Secure the EC2 Instance

**Option A — Console:** EC2 → Launch instance → Amazon Linux 2023, `t3.small`, new key pair `todo-key`, new security group with the rules below, 30 GB gp3.

**Option B — CLI (from your machine with AWS CLI configured):**
```bash
# 1) key pair
aws ec2 create-key-pair --key-name todo-key \
  --query 'KeyMaterial' --output text > todo-key.pem
chmod 400 todo-key.pem

# 2) security group
SG_ID=$(aws ec2 create-security-group --group-name todo-sg \
  --description "Todo app SG" --query 'GroupId' --output text)
MYIP=$(curl -s ifconfig.me)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22  --cidr ${MYIP}/32
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0

# 3) launch (replace AMI with the latest AL2023 in your Region)
AMI=$(aws ssm get-parameters --names \
  /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)
aws ec2 run-instances --image-id $AMI --instance-type t3.small \
  --key-name todo-key --security-group-ids $SG_ID \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=todo-app},{Key=Project,Value=Capstone}]' \
  --count 1
```

**Allocate & attach an Elastic IP (stable public IP):**
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=todo-app" \
  "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOC
aws ec2 describe-addresses --allocation-ids $ALLOC --query 'Addresses[0].PublicIp' --output text
# ^ note this Elastic IP — call it ELASTIC_IP below
```

---

## Step 2 — Connect & Prep the Server
```bash
ssh -i todo-key.pem ec2-user@ELASTIC_IP

# update + timezone
sudo dnf update -y
sudo timedatectl set-timezone Asia/Kolkata

# add 2 GB swap (helps npm build on small instances)
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

---

## Step 3 — Install the Stack
```bash
# Git
sudo dnf install -y git

# Node.js 20 LTS + PM2
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
node -v && npm -v
sudo npm install -g pm2

# Nginx
sudo dnf install -y nginx
sudo systemctl enable --now nginx

# MariaDB (MySQL-compatible)
sudo dnf install -y mariadb105-server
sudo systemctl enable --now mariadb
```

---

## Step 4 — Set Up the MySQL Database
```bash
# secure the DB (set root password, remove test db/anon users)
sudo mysql_secure_installation

# create the app database + user + table
sudo mysql -u root -p <<'SQL'
CREATE DATABASE IF NOT EXISTS tododb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'todouser'@'localhost' IDENTIFIED BY 'ChangeMe_Strong!123';
GRANT ALL PRIVILEGES ON tododb.* TO 'todouser'@'localhost';
FLUSH PRIVILEGES;
USE tododb;
CREATE TABLE IF NOT EXISTS todos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO todos (title) VALUES ('Deploy React+Node+MySQL on EC2');
SQL
```
🔒 Port 3306 is **not** opened in the Security Group — the DB is reachable only from localhost.

---

## Step 5 — Deploy the Node.js Backend
Use the sample in [`backend/`](backend/) (copy it up) or clone your repo.
```bash
# copy the sample backend from your machine (run locally), OR git clone on the server
# rsync -avz -e "ssh -i todo-key.pem" backend/ ec2-user@ELASTIC_IP:/home/ec2-user/backend/

sudo mkdir -p /var/www && sudo chown -R ec2-user:ec2-user /var/www
cp -r ~/backend /var/www/todo-backend   # or: git clone <repo> /var/www/todo-backend
cd /var/www/todo-backend
npm install --production

# environment file (secrets)
cat > /var/www/todo-backend/.env <<'EOF'
NODE_ENV=production
PORT=5000
DB_HOST=127.0.0.1
DB_USER=todouser
DB_PASSWORD=ChangeMe_Strong!123
DB_NAME=tododb
EOF
chmod 600 /var/www/todo-backend/.env

# run under PM2 (cluster) + survive reboot
pm2 start ecosystem.config.js        # provided in backend/
pm2 startup                          # run the sudo command it prints
pm2 save

# verify
curl http://localhost:5000/api/health      # {"status":"ok"}
curl http://localhost:5000/api/todos       # JSON list
```

---

## Step 6 — Deploy the React Frontend
The sample frontend is in [`frontend/`](frontend/). It calls the API at `/api` (same origin → no CORS).

**Build locally (recommended) and ship the static files:**
```bash
# on your machine
cd frontend
npm install
npm run build            # outputs ./build (CRA) — Vite outputs ./dist
rsync -avz -e "ssh -i ../todo-key.pem" build/ ec2-user@ELASTIC_IP:/home/ec2-user/frontend-build/
```
**On the server, place the build under Nginx root:**
```bash
sudo mkdir -p /var/www/todo-frontend
sudo cp -r ~/frontend-build/* /var/www/todo-frontend/
sudo chown -R nginx:nginx /var/www/todo-frontend
```
> Building on the server instead? `cd /var/www && git clone <repo> fe && cd fe && npm install && npm run build && sudo cp -r build/* /var/www/todo-frontend/` (the swap from Step 2 helps).

---

## Step 7 — Configure Nginx
```bash
sudo tee /etc/nginx/conf.d/todo.conf >/dev/null <<'NGINX'
server {
    listen 80;
    server_name todo.example.com;   # change to your domain or the Elastic IP

    root /var/www/todo-frontend;
    index index.html;

    # gzip
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;

    # React SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # API reverse proxy → Node (PM2)
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

# allow Nginx to proxy to Node (SELinux on AL2023)
sudo setsebool -P httpd_can_network_connect 1

sudo nginx -t && sudo systemctl reload nginx
```
**Test now over HTTP:** open `http://ELASTIC_IP` — the Todo app should load and list todos.

---

## Step 8 — Map the Domain
In Route 53 (or your registrar) add an A record pointing to your Elastic IP:
```
Type  Name                 Value         TTL
A     todo.example.com     ELASTIC_IP    300
```
**Route 53 CLI example:**
```bash
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name example.com \
  --query 'HostedZones[0].Id' --output text)
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"todo.example.com","Type":"A","TTL":300,
    "ResourceRecords":[{"Value":"ELASTIC_IP"}]}}]}'
```
Verify: `nslookup todo.example.com` → returns your Elastic IP.

---

## Step 9 — Enable HTTPS (Let's Encrypt)
> Requires Step 8 done (domain resolves to the server) and port 80 open.
```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d todo.example.com \
  --non-interactive --agree-tos -m you@example.com --redirect
sudo nginx -t && sudo systemctl reload nginx

# auto-renewal check
sudo certbot renew --dry-run
```
Certbot rewrites the Nginx config to serve 443 with the cert and 301-redirect 80→443.

✅ Open `https://todo.example.com` — padlock + working app.

---

## Step 10 — Verify, Harden, Clean Up

**Verify:**
```bash
curl -I https://todo.example.com            # 200, server: nginx
curl https://todo.example.com/api/health    # {"status":"ok"}
pm2 list                                    # api online
sudo systemctl status nginx mariadb         # active
```

**Harden (recap):**
```
[ ] SSH (22) limited to your IP / use SSM
[ ] .env chmod 600 (or move to SSM Parameter Store)
[ ] 3306 not in the Security Group
[ ] HTTPS enforced + auto-renew tested
[ ] pm2 startup + save done
[ ] EBS snapshot scheduled (DLM/AWS Backup)
[ ] CloudWatch alarm on CPU + AWS Budget set
[ ] Tags applied (Project=Capstone)
```

**💰 Clean up when finished (avoid charges):**
```bash
# on the instance, optional: pm2 delete all
# from your machine:
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 release-address --allocation-id $ALLOC          # release the Elastic IP
aws ec2 delete-security-group --group-id $SG_ID          # after instance is gone
aws ec2 delete-key-pair --key-name todo-key
```
Then confirm the Billing Dashboard trends to ~$0.

---

## 🧯 Troubleshooting Quick Links
- App won't load / 502 / DB errors → [Module 8 Troubleshooting](../08-troubleshooting-guide.md)
- Nginx/PM2 details → [Module 6](../06-nginx-and-pm2-setup.md)
- SSL/domain issues → [Module 7 §5–6](../07-production-deployment-guide.md)

## 📂 Project Files
- [`backend/`](backend/) — Express API (`app.js`, `db.js`, `package.json`, `ecosystem.config.js`, `.env.example`)
- [`frontend/`](frontend/) — minimal React app calling `/api/todos`

## 🚀 Stretch Goals
1. Move MySQL → **Amazon RDS Multi-AZ** ([Module 7 §4 Option B](../07-production-deployment-guide.md)).
2. Put an **ALB + Auto Scaling Group** in front (ACM cert on the ALB).
3. Add a **CI/CD pipeline** (GitHub Actions → build → rsync/CodeDeploy).
4. Add **CloudWatch dashboards/alarms** and **CloudFront** for static assets.
5. Bake a **golden AMI** and launch via a **Launch Template**.

---

🎉 You've deployed a real, secured full-stack app on EC2. This is the core skill behind most "deploy our app to AWS" jobs.

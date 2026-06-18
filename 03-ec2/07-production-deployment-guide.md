# Module 7 — Production Deployment Guide

> The complete playbook: deploy a **React** front end and a **Node.js** API on EC2, connect to **MySQL**, add **SSL (HTTPS)**, and map a **custom domain**. This is the conceptual reference; the hands-on, copy-paste version is the [capstone project](project/README.md).

---

## Production Deployment Overview

```
 ┌─ Provision EC2 (right type, SG: 22/80/443, key pair, EIP)
 ├─ Harden & prep (updates, user, swap, Node, Nginx, MySQL)
 ├─ Deploy Node API (clone/build, env, PM2)
 ├─ Deploy React (build, copy static to Nginx root)
 ├─ Configure Nginx (static + /api reverse proxy)
 ├─ Connect MySQL (DB, user, schema, secure)
 ├─ Map domain (Route 53 / registrar A record → EIP)
 └─ Enable SSL (Certbot/Let's Encrypt, auto-renew) → HTTPS
```

---

## 1. Provision & Prepare the Server

```bash
# after SSH in:
sudo dnf update -y                      # (Ubuntu: sudo apt update && sudo apt upgrade -y)
sudo timedatectl set-timezone Asia/Kolkata

# create a deploy user (don't run apps as root)
sudo useradd -m -s /bin/bash deploy && sudo usermod -aG wheel deploy

# add swap (helps small instances during npm build)
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Security Group:** inbound 22 (your IP), 80, 443 (anywhere). See [Module 1 §5](01-ec2-core-concepts.md#5-security-groups).

---

## 2. Node.js Deployment

```bash
# install Node LTS + PM2
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs git
sudo npm install -g pm2

# get the code
sudo mkdir -p /var/www && sudo chown -R $USER /var/www
cd /var/www
git clone https://github.com/you/your-api.git api
cd api
npm install --production
```

**Environment variables** — never hard-code secrets. Use a `.env` (with `dotenv`) or PM2 env:
```bash
cat > /var/www/api/.env <<'EOF'
NODE_ENV=production
PORT=5000
DB_HOST=127.0.0.1
DB_USER=appuser
DB_PASSWORD=StrongPass!123
DB_NAME=appdb
EOF
chmod 600 /var/www/api/.env
```

**Run with PM2 (cluster) + survive reboot:**
```bash
cd /var/www/api
pm2 start app.js --name api -i max
pm2 startup        # run the printed sudo command
pm2 save
pm2 logs api       # verify it's up on :5000
curl http://localhost:5000/health   # expect 200
```

💡 Bind the Node app to `127.0.0.1:5000` (localhost), not `0.0.0.0` — only Nginx should reach it.

---

## 3. React Deployment

**Option A (recommended): build locally/CI, ship the static files.**
```bash
# on your machine or CI
npm install
npm run build        # outputs ./build (CRA) or ./dist (Vite)
# copy to server
rsync -avz -e "ssh -i key.pem" build/ ec2-user@<ip>:/var/www/app/
```

**Option B: build on the server (needs RAM/swap).**
```bash
cd /var/www
git clone https://github.com/you/your-frontend.git frontend
cd frontend && npm install && npm run build
sudo mkdir -p /var/www/app
sudo cp -r build/* /var/www/app/      # or dist/* for Vite
```

**Point the React app at the API** via build-time env (e.g., `REACT_APP_API_URL=/api` or `VITE_API_URL=/api`) so calls go to the same domain through Nginx — avoids CORS.

**Nginx serves it** (see Module 6 config): `root /var/www/app;` with SPA fallback `try_files $uri /index.html;` and `/api/` proxied to Node.
```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## 4. MySQL Connection

### Option A — MySQL on the same EC2 (cheap, simple, for small apps)
```bash
# Amazon Linux 2023
sudo dnf install -y mariadb105-server   # MariaDB (MySQL-compatible)
sudo systemctl enable --now mariadb
sudo mysql_secure_installation          # set root pw, remove test db, etc.

# create app DB + user
sudo mysql -u root -p <<'SQL'
CREATE DATABASE appdb CHARACTER SET utf8mb4;
CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'StrongPass!123';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'localhost';
FLUSH PRIVILEGES;
SQL
```
Node connects to `127.0.0.1:3306`. Keep 3306 **closed** in the Security Group (localhost only). 🔒

### Option B — Amazon RDS MySQL (recommended for production)
- Launch RDS MySQL (Multi-AZ for HA) in a **private subnet**.
- RDS Security Group: allow **3306 only from the EC2's security group**.
- App connects to the RDS endpoint:
```bash
mysql -h mydb.abc123.ap-south-1.rds.amazonaws.com -u appuser -p
```
- Benefits: managed backups, patching, failover, scaling. See Phase 01 for managed-service tradeoffs.

### Node connection snippet (mysql2)
```javascript
const mysql = require('mysql2/promise');
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10
});
module.exports = pool;
```

🔒 **Never** open MySQL (3306) to `0.0.0.0/0`. Use localhost or SG-to-SG rules only.

---

## 5. Domain Mapping

1. **Get a static IP:** allocate an **Elastic IP** and associate it with the instance ([Module 1 §7](01-ec2-core-concepts.md#7-elastic-ip)).
2. **DNS records** (in Route 53 or your registrar):
   ```
   Type  Name              Value            TTL
   A     example.com       <ELASTIC_IP>     300
   A     www.example.com   <ELASTIC_IP>     300
   ```
   (Or `A` to the EIP; if using an ALB, use an **Alias/CNAME** to the ALB DNS name.)
3. **Route 53 (if AWS-hosted domain):** create a Hosted Zone, copy its **NS records** to your registrar, then add the A records above.
4. Set `server_name example.com www.example.com;` in the Nginx config.
5. Verify: `nslookup example.com` resolves to your EIP; `http://example.com` loads.

⚠️ DNS changes can take minutes to hours to propagate (TTL dependent).

---

## 6. SSL Setup (HTTPS with Let's Encrypt)

> Free, auto-renewing certificates via Certbot. Requires the domain to already resolve to the server (Step 5) and ports 80/443 open.

```bash
# Amazon Linux 2023
sudo dnf install -y certbot python3-certbot-nginx
# Ubuntu
sudo apt install -y certbot python3-certbot-nginx

# obtain + auto-configure Nginx for HTTPS
sudo certbot --nginx -d example.com -d www.example.com \
  --non-interactive --agree-tos -m you@example.com --redirect

# certbot edits Nginx to listen 443 with the cert and 301-redirects 80 → 443
sudo nginx -t && sudo systemctl reload nginx
```

**Auto-renewal** (Certbot installs a timer; verify):
```bash
sudo certbot renew --dry-run
systemctl list-timers | grep certbot
```

Resulting Nginx (managed by Certbot) roughly:
```nginx
server {
    listen 443 ssl;
    server_name example.com www.example.com;
    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    root /var/www/app;
    location / { try_files $uri /index.html; }
    location /api/ { proxy_pass http://127.0.0.1:5000/; /* + proxy headers */ }
}
server {                          # redirect HTTP → HTTPS
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}
```

**Alternative — ACM + ALB:** for load-balanced setups, use a **free ACM certificate on the ALB** (TLS terminates at the load balancer); no Certbot needed on the instance.

✅ Verify: `https://example.com` shows the padlock; `curl -I https://example.com` returns 200.

---

## 7. Production Hardening Checklist 🔒
```
[ ] SSH (22) limited to your IP (or use SSM Session Manager)
[ ] App runs as non-root (deploy user) under PM2
[ ] Secrets in .env (chmod 600) or SSM Parameter Store / Secrets Manager
[ ] MySQL/RDS not publicly reachable (localhost or SG-to-SG only)
[ ] Nginx security headers + gzip; client_max_body_size set
[ ] HTTPS enforced (HTTP → 301 HTTPS), auto-renew tested
[ ] EBS encrypted; automated snapshots / RDS backups enabled
[ ] CloudWatch alarms (CPU, disk, 5xx) + AWS Budget
[ ] OS auto-updates / patch plan; pm2 startup + save configured
[ ] IAM role on instance (no static AWS keys on disk)
[ ] Tags applied (Env, Owner, Project)
```

---

## 8. Deployment Flow Diagram
```
Dev push ─► (CI build React + test) ─► artifacts
                                          │
   ssh/rsync or git pull on EC2 ──────────┤
                                          ▼
   /var/www/app (React build)     /var/www/api (Node)
        │                               │
      Nginx :443  ──/──► static    ──/api──► PM2 Node :5000 ─► MySQL/RDS :3306
        ▲
   Route 53 A → EIP ; Certbot TLS
```

---

➡️ Next: [08-troubleshooting-guide.md](08-troubleshooting-guide.md) · or jump to the [Capstone Project](project/README.md)

# Module 6 — Nginx + PM2 Setup

> The two tools that turn a Node app into a production web service: **Nginx** (web server / reverse proxy / static host / TLS) in front, **PM2** (Node process manager) keeping your app alive.

---

## Why these two?

```
   Internet ──► Nginx (port 80/443)
                  ├── serves React static files (fast, gzip, cache)
                  ├── terminates SSL/TLS (HTTPS)
                  └── reverse-proxies /api ──► Node app (PM2) on 127.0.0.1:5000
                                                 └── PM2 keeps Node running,
                                                     restarts on crash, clusters CPUs
```
- **Never expose Node directly** on port 80/443 to the internet. Put Nginx in front.
- **Never run `node app.js` by hand** in production — it dies on logout/crash. Use PM2 (or systemd).

---

## Part A — Nginx

### 1. Install & start
```bash
# Amazon Linux 2023
sudo dnf install -y nginx
# Ubuntu
sudo apt update && sudo apt install -y nginx

sudo systemctl enable --now nginx
sudo systemctl status nginx
curl -I http://localhost          # expect HTTP/1.1 200
```
Config locations: Amazon Linux `/etc/nginx/nginx.conf` + `/etc/nginx/conf.d/*.conf`; Ubuntu `/etc/nginx/sites-available/` (+ symlinks in `sites-enabled/`).

### 2. Serve a React static build
Put your built files in `/var/www/app` (the `npm run build` output).
```nginx
# /etc/nginx/conf.d/app.conf
server {
    listen 80;
    server_name app.example.com;

    root /var/www/app;
    index index.html;

    # React Router (SPA): always fall back to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
```

### 3. Reverse proxy to a Node API
```nginx
# inside the same server { } block
location /api/ {
    proxy_pass http://127.0.0.1:5000/;   # Node app
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    # websockets:
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### 4. Test & reload (always test before reload!)
```bash
sudo nginx -t                 # validate config syntax
sudo systemctl reload nginx   # apply with zero downtime
sudo tail -f /var/log/nginx/error.log
```

### 5. Useful extras
```nginx
# enable gzip (in http {} of nginx.conf)
gzip on;
gzip_types text/plain text/css application/json application/javascript;

# increase upload size
client_max_body_size 20M;
```

⚠️ **SELinux (Amazon Linux/RHEL):** if proxy returns 502, allow Nginx network connections:
```bash
sudo setsebool -P httpd_can_network_connect 1
```

---

## Part B — PM2 (Node Process Manager)

### 6. Install Node + PM2
```bash
# Node.js LTS via NodeSource (works on AL2023 & Ubuntu)
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -   # Amazon Linux
# or for Ubuntu:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs   ||  sudo apt install -y nodejs
node -v && npm -v

sudo npm install -g pm2
pm2 -v
```

### 7. Start your app under PM2
```bash
cd /var/www/api
npm install --production

pm2 start app.js --name api               # simple
# or with the cluster (use all CPU cores):
pm2 start app.js --name api -i max
# or an npm script:
pm2 start npm --name api -- run start
```

### 8. PM2 daily commands
```bash
pm2 list                 # status table
pm2 logs api             # stream logs
pm2 logs api --lines 100
pm2 restart api          # restart
pm2 reload api           # zero-downtime reload (cluster mode)
pm2 stop api
pm2 delete api
pm2 monit                # live dashboard
pm2 describe api         # details
pm2 flush                # clear logs
```

### 9. Survive reboots (critical for production)
```bash
pm2 startup              # prints a sudo command — run it (sets up systemd)
pm2 save                 # snapshot current process list to resurrect on boot
```
Now PM2 (and your app) auto-start after an instance reboot.

### 10. Ecosystem file (recommended for real apps)
```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: "api",
    script: "app.js",
    instances: "max",        // cluster across CPUs
    exec_mode: "cluster",
    env: {
      NODE_ENV: "production",
      PORT: 5000,
      DB_HOST: "127.0.0.1",
      DB_USER: "appuser",
      DB_NAME: "appdb"
    }
  }]
}
```
```bash
pm2 start ecosystem.config.js
pm2 save
```

### 11. PM2 vs systemd vs Docker (quick context)
- **PM2** — easiest for Node, built-in clustering, logs, reload, monitoring. Great default.
- **systemd** — native, no extra dependency; good if you prefer OS-level management.
- **Docker** — package app + deps; best for portability/orchestration (later phase).

---

## How Nginx + PM2 Work Together (recap)
```
1. PM2 runs Node API on 127.0.0.1:5000 (not exposed publicly)
2. Nginx listens on 80/443 (public), serves React build for "/"
3. Nginx proxies "/api" → 127.0.0.1:5000 (Node)
4. PM2 restarts Node on crash; pm2 save+startup survive reboots
5. (Module 7) Certbot adds HTTPS on Nginx :443
```

## Quick Reference
```
Nginx:  sudo nginx -t ; sudo systemctl reload nginx ; tail -f /var/log/nginx/error.log
PM2:    pm2 start app.js --name api -i max ; pm2 save ; pm2 startup ; pm2 logs api
```

---

➡️ Next: [07-production-deployment-guide.md](07-production-deployment-guide.md)

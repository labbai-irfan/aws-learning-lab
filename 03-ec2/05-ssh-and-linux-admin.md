# Module 5 — SSH + Linux Administration

> The operational skills you need to run an EC2 Linux server. Connect securely, then manage packages, services, users, permissions, networking, storage, and logs. Commands shown for **Amazon Linux 2023 (dnf)** and **Ubuntu (apt)**.

---

## Part A — SSH (Secure Shell)

### 1. Connect to your instance
```bash
chmod 400 my-key.pem                       # private key must not be world-readable
ssh -i my-key.pem ec2-user@<public-ip>     # Amazon Linux
ssh -i my-key.pem ubuntu@<public-ip>       # Ubuntu
```
Default users: Amazon Linux `ec2-user` · Ubuntu `ubuntu` · Debian `admin` · CentOS `centos`.

### 2. SSH config shortcut (~/.ssh/config)
```
Host myec2
    HostName 203.0.113.10
    User ec2-user
    IdentityFile ~/.ssh/my-key.pem
```
Then just: `ssh myec2`.

### 3. Common SSH operations
```bash
ssh -i key.pem ec2-user@ip 'uptime'        # run one remote command
scp -i key.pem file.txt ec2-user@ip:/home/ec2-user/   # copy file TO server
scp -i key.pem ec2-user@ip:/var/log/app.log .          # copy file FROM server
rsync -avz -e "ssh -i key.pem" ./build/ ec2-user@ip:/var/www/app/  # sync a dir
ssh -i key.pem -L 3306:localhost:3306 ec2-user@ip      # tunnel remote MySQL to local
```

### 4. Connection methods compared
| Method | Open port? | Keys? | Audit | Best for |
|--------|-----------|-------|-------|----------|
| **SSH + key pair** | 22 open | yes | minimal | classic admin |
| **EC2 Instance Connect** | 22 (push temp key) | no stored key | yes | quick browser access |
| **SSM Session Manager** | **none** | no | full (CloudTrail/logs) | secure production 🔒 |

🔒 **Best practice:** Lock SSH (22) to **your IP only**, or use **SSM Session Manager** (no inbound port at all).

### 5. SSH troubleshooting (quick)
- `Permission denied (publickey)` → wrong username or wrong key. Match user to AMI.
- `Connection timed out` → Security Group not allowing 22 from your IP, or no public IP/route.
- `WARNING: UNPROTECTED PRIVATE KEY` → run `chmod 400 key.pem`.
- Verbose debug: `ssh -vvv -i key.pem ec2-user@ip`.

---

## Part B — Linux Administration

### 6. Sudo & users
```bash
sudo su -                       # become root
whoami                          # current user
sudo adduser deploy             # create user (Ubuntu)
sudo useradd -m deploy          # create user (Amazon Linux)
sudo usermod -aG sudo deploy    # grant sudo (Ubuntu: sudo group)
sudo usermod -aG wheel deploy   # grant sudo (Amazon Linux: wheel group)
sudo passwd deploy              # set password
su - deploy                     # switch user
```
Add an SSH key for a new user:
```bash
sudo mkdir -p /home/deploy/.ssh && sudo nano /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh && sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

### 7. Package management
```bash
# Amazon Linux 2023 / RHEL (dnf)
sudo dnf update -y
sudo dnf install -y nginx git
sudo dnf remove -y nginx
sudo dnf search node

# Ubuntu / Debian (apt)
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx git
sudo apt remove -y nginx
```

### 8. systemd services (start/stop/enable)
```bash
sudo systemctl start nginx       # start now
sudo systemctl stop nginx        # stop
sudo systemctl restart nginx     # restart
sudo systemctl reload nginx      # reload config (no downtime)
sudo systemctl enable nginx      # start on boot
sudo systemctl enable --now nginx# enable + start
sudo systemctl status nginx      # check status
sudo systemctl disable nginx     # don't start on boot
journalctl -u nginx --no-pager   # service logs
journalctl -u nginx -f           # follow logs live
```

### 9. Files, permissions, ownership
```bash
ls -la                  # list with permissions
pwd                     # current dir
cd /var/www             # change dir
mkdir -p /var/www/app   # make dir (and parents)
cp -r src/ dest/        # copy recursively
mv old new              # move/rename
rm -rf dir/             # delete recursively (careful!)
chmod 644 file          # rw-r--r--
chmod 755 script.sh     # rwxr-xr-x (executable)
chown deploy:deploy file# change owner:group
chown -R deploy /var/www/app
```
**Permission digits:** read=4, write=2, execute=1. `755` = owner rwx (7), group rx (5), others rx (5).

### 10. Editing files
```bash
nano /etc/nginx/nginx.conf       # beginner-friendly editor
sudo vi /etc/nginx/nginx.conf    # vim (i=insert, ESC, :wq=save+quit, :q!=quit)
cat file.txt                     # print file
less file.txt                    # page through (q to quit)
head -n 20 file.txt              # first 20 lines
tail -n 50 file.txt              # last 50 lines
tail -f /var/log/nginx/error.log # follow live
grep "ERROR" app.log             # search
grep -ri "timeout" /etc/nginx/   # recursive, case-insensitive
```

### 11. Process & resource monitoring
```bash
top                  # live process/CPU/mem (q to quit)
htop                 # nicer top (install first)
ps aux | grep node   # find a process
kill <pid>           # terminate
kill -9 <pid>        # force kill
free -h              # memory usage
df -h                # disk usage by filesystem
du -sh /var/www/*    # dir sizes
uptime               # load average
nproc                # number of CPUs
```

### 12. Networking
```bash
ip addr                       # interfaces/IPs
curl ifconfig.me              # public IP
ping google.com               # connectivity
curl -I http://localhost      # HTTP headers from local service
ss -tulpn                     # listening ports + processes (replaces netstat)
sudo ss -tulpn | grep :80     # who's on port 80
nslookup app.example.com      # DNS lookup
telnet <db-host> 3306         # test port reachability
```

### 13. EBS volume management (attach extra disk)
```bash
lsblk                                  # list block devices
sudo file -s /dev/xvdf                 # check if formatted ("data" = empty)
sudo mkfs -t xfs /dev/xvdf             # format (only if new/empty!)
sudo mkdir -p /data
sudo mount /dev/xvdf /data             # mount
# persist across reboots:
echo "/dev/xvdf /data xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
# grow after resizing the volume in AWS:
sudo growpart /dev/xvda 1 && sudo xfs_growfs -d /
```

### 14. Logs to know
```
/var/log/cloud-init-output.log   # user-data / boot script output
/var/log/messages (AL) /var/log/syslog (Ubuntu)  # system log
/var/log/nginx/access.log , error.log            # web server
journalctl -u <service>                          # systemd service logs
```

### 15. Firewall note
On EC2, the **Security Group** is your primary firewall. The OS firewall (`firewalld`/`ufw`) is usually **off** by default — if you enable it, it can block traffic the SG allows. Check both when debugging connectivity.

---

## Quick Reference Card
```
Connect:   ssh -i key.pem ec2-user@ip
Update:    sudo dnf update -y   |   sudo apt update && sudo apt upgrade -y
Install:   sudo dnf install -y X|   sudo apt install -y X
Service:   sudo systemctl enable --now X ; systemctl status X
Logs:      journalctl -u X -f ; tail -f /var/log/...
Ports:     sudo ss -tulpn
Disk/Mem:  df -h ; free -h ; lsblk
Proc:      top ; ps aux | grep X ; kill -9 PID
Perms:     chmod 755 file ; chown user:group file
```

---

➡️ Next: [06-nginx-and-pm2-setup.md](06-nginx-and-pm2-setup.md)

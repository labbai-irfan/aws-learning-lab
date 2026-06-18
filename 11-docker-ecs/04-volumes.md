# Module 4 — Volumes

> Containers are **ephemeral** — the writable layer is destroyed with the container. Volumes are how you keep data: databases, uploads, logs. This module covers volume types, when to use each, and the AWS equivalents (EFS) for ECS.

---

## 1. Why Volumes Exist

```
   docker rm db   ──►   the writable layer (and all data in it) is GONE
```

Anything written inside a container that isn't on a volume disappears when the container is removed. For stateless apps (a web API) that's fine — that's the goal. For **stateful** data (MySQL files, user uploads) you must mount storage that outlives the container.

---

## 2. The Three Mount Types

| Type | Syntax | Managed by | Use for |
|---|---|---|---|
| **Named volume** | `-v mydata:/var/lib/mysql` | Docker | DB data, anything you want Docker to own |
| **Bind mount** | `-v /host/path:/app` | You (host path) | Local dev (live code), config files |
| **tmpfs** | `--tmpfs /tmp` | RAM only | Secrets/scratch you never want on disk |

```
   ┌─────────── container ───────────┐
   │  /var/lib/mysql  ───────────────┼──► named volume "dbdata"  (Docker-managed dir)
   │  /app            ───────────────┼──► bind mount  /home/me/code  (your host path)
   │  /tmp            ───────────────┼──► tmpfs (RAM)
   └─────────────────────────────────┘
```

---

## 3. Named Volumes (preferred for data)

```bash
docker volume create dbdata
docker volume ls
docker volume inspect dbdata        # see Mountpoint on host

# attach to a MySQL container — data survives container removal
docker run -d --name db \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=hrms \
  -v dbdata:/var/lib/mysql \
  mysql:8.0

docker rm -f db                     # remove the container...
docker run -d --name db -v dbdata:/var/lib/mysql ... mysql:8.0  # ...data is still there
```
💡 Docker creates the volume automatically if it doesn't exist when you `-v name:/path`.

---

## 4. Bind Mounts (preferred for local dev)

Live-reload your code without rebuilding the image:
```bash
docker run -d --name api \
  -v "$(pwd)":/app \              # your source → container
  -v /app/node_modules \         # keep container's node_modules (anonymous vol)
  -p 5000:5000 \
  node:20-alpine \
  sh -c "cd /app && npm run dev"
```
⚠️ Bind mounts depend on the **host path existing**. They're great for dev, poor for portability — don't rely on them in production clusters.

---

## 5. Backup, Restore, Migrate

```bash
# backup a named volume to a tarball
docker run --rm -v dbdata:/data -v "$(pwd)":/backup alpine \
  tar czf /backup/dbdata-backup.tgz -C /data .

# restore into a (new) volume
docker run --rm -v dbdata:/data -v "$(pwd)":/backup alpine \
  sh -c "cd /data && tar xzf /backup/dbdata-backup.tgz"
```

---

## 6. Cleanup (careful)

```bash
docker volume prune          # ⚠️ removes ALL volumes not used by a container
docker volume rm dbdata      # remove a specific one (must be unused)
```
⚠️ `docker volume prune` and `docker system prune --volumes` can delete your database. Make sure data volumes are attached or backed up first.

---

## 7. The AWS Picture — Storage on ECS

On ECS, the host isn't yours to manage (especially on Fargate), so volumes map to AWS storage:

| Local Docker | ECS / AWS |
|---|---|
| Named volume (local disk) | Task **ephemeral storage** (20–200 GB, gone when task stops) |
| Persistent shared data | **Amazon EFS** mounted into the task (survives, shared across tasks/AZs) |
| Database | **Don't** run DB in a container in prod — use **Amazon RDS** |
| Block storage | **EBS volumes** attached to Fargate tasks (newer feature) |

```
   ECS Task ──mountPoints──► EFS Access Point ──► EFS filesystem (multi-AZ, durable)
```

Best practice in this course's HRMS capstone:
- **Stateless services** (auth, employee, payroll, frontend) → no volumes; restartable anywhere.
- **Shared uploads** (employee documents/photos) → **EFS**.
- **Relational data** → **Amazon RDS (MySQL)**, not a container.
- **Cache/session** → **ElastiCache (Redis)**, not a container volume.

🔒 Pushing state out of containers is what makes services freely scalable and replaceable — the core of the microservices model in [Module 6](06-container-architecture.md).

➡️ Next: [05-networks.md](05-networks.md) — how containers talk to each other and the world.

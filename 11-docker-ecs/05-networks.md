# Module 5 — Networks

> How containers reach each other, the host, and the internet. Covers the built-in network drivers, DNS-based service discovery, port publishing, Docker Compose networking, and the ECS `awsvpc` mode you'll use on AWS.

---

## 1. The Network Drivers

| Driver | Scope | Behavior | Use for |
|---|---|---|---|
| **bridge** (default) | Single host | Private virtual network; containers get internal IPs; reach outside via NAT | Most local multi-container apps |
| **host** | Single host | Container shares the host's network stack (no isolation, no `-p`) | Max performance, low-level tools |
| **none** | Single host | No networking at all | Fully isolated batch jobs |
| **overlay** | Multi-host (Swarm) | Network spanning multiple Docker hosts | Swarm clusters |
| **awsvpc** | ECS | Each task gets its **own ENI + VPC IP** | ECS/Fargate (Module 7) |

---

## 2. The Default Bridge vs a User-Defined Bridge

On the **default** bridge, containers can only reach each other by IP. On a **user-defined** bridge, Docker runs an embedded DNS server so containers resolve each other **by name** — this is what you want.

```bash
docker network create hrms-net           # user-defined bridge

docker run -d --name db    --network hrms-net mysql:8.0
docker run -d --name auth  --network hrms-net hrms-auth:1.4.2

# inside "auth", the hostname "db" resolves to the db container's IP:
docker exec auth sh -c "getent hosts db"
# auth connects with DB_HOST=db  (no IPs, no links needed)
```

```
            ┌──────────── hrms-net (bridge) ────────────┐
 internet ──┤  auth (10.x)  ── name:db ──►  db (10.x)    │
   :443 ────┤  frontend (10.x) ── name:auth ──► auth     │
            └────────────────────────────────────────────┘
                        │  NAT for outbound
                        ▼
                     host eth0
```
💡 **Service discovery by name** is the single biggest reason to always create your own network instead of using the default bridge.

---

## 3. Publishing Ports

`EXPOSE` in a Dockerfile only **documents** a port. To actually reach a container from the host you must **publish** with `-p`:

```bash
docker run -d -p 8080:80 nginx     # host:8080 → container:80
docker run -d -p 127.0.0.1:5000:5000 hrms-auth   # bind to localhost only (safer)
docker run -d -P nginx             # publish all EXPOSEd ports to random host ports
docker port <container>            # see the mapping
```
⚠️ Containers on the **same** user-defined network talk to each other on the container port directly (e.g. `db:3306`) — you do **not** need to publish internal ports to the host. Only publish what the outside world should reach. 🔒 Don't `-p 3306:3306` your database to the world.

---

## 4. Inspecting Networks

```bash
docker network ls                       # bridge, host, none, + yours
docker network inspect hrms-net         # subnet, gateway, connected containers
docker network connect hrms-net api     # attach a running container
docker network disconnect hrms-net api
docker network prune                    # remove unused networks
```

---

## 5. Docker Compose Networking (multi-service made easy)

Compose creates a network automatically and names every service as a DNS name. This is how you run the whole HRMS locally before ECS.

```yaml
# docker-compose.yml
services:
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: hrms
    volumes: [ "dbdata:/var/lib/mysql" ]

  auth:
    build: ./auth-service
    environment:
      DB_HOST: db            # ← resolves to the db service by name
      DB_NAME: hrms
    depends_on: [ db ]
    ports: [ "5001:5000" ]

  frontend:
    build: ./frontend
    ports: [ "8080:80" ]
    depends_on: [ auth ]

volumes:
  dbdata:
```
```bash
docker compose up -d        # builds + starts everything on one network
docker compose ps
docker compose logs -f auth
docker compose down         # stop + remove (add -v to drop volumes)
```
💡 No manual `docker network create` — Compose makes `<project>_default` and wires DNS for you.

---

## 6. The AWS Picture — `awsvpc` Mode

On ECS (especially Fargate), each task uses the **`awsvpc`** network mode: the task gets its **own Elastic Network Interface (ENI)** and a **private IP inside your VPC** — just like an EC2 instance. That means:

- Tasks are reached/secured with **VPC Security Groups**, not `-p`.
- Containers in the **same task** share `localhost` (talk over `127.0.0.1`).
- Containers in **different** tasks talk via the **ALB** or **ECS Service Connect / Cloud Map** DNS.

```
   VPC (10.0.0.0/16)
   ┌──────────────────────────────────────────────┐
   │  ALB (public subnet) :443                      │
   │    │  forwards by path                         │
   │    ▼                                            │
   │  Task: frontend (ENI 10.0.2.11)  ─SG allows 80 │
   │  Task: auth     (ENI 10.0.2.12)  ─SG allows 5000
   │  Task: payroll  (ENI 10.0.2.13)                │
   │            │                                    │
   │            ▼ (private)                          │
   │  RDS (10.0.3.x) · ElastiCache · EFS            │
   └──────────────────────────────────────────────┘
```

| Local Docker | ECS `awsvpc` |
|---|---|
| user-defined bridge + DNS names | Service Connect / Cloud Map DNS |
| `-p host:container` | ALB target group → task port |
| container-to-container by name | task-to-task via ALB or Service Connect |
| firewall by not publishing | **Security Groups** per task ENI |

---

## ✅ Module 5 Checklist
```
[ ] Always use a user-defined bridge for multi-container apps (DNS by name)
[ ] Know EXPOSE documents, -p publishes
[ ] Only publish what the outside needs (never the DB)
[ ] Can run the whole stack with docker compose up
[ ] Understand awsvpc gives each ECS task its own VPC IP + SG
```

➡️ Next: [06-container-architecture.md](06-container-architecture.md) — container & microservices architecture.

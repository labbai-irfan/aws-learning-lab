# Module 1 — Docker Fundamentals

> What containers are, why they beat "works on my machine," the architecture under the hood, and the 12 commands you'll use every day.

---

## 1. The Problem Docker Solves

Before containers, deploying an app meant: install the right OS, the right runtime version, the right libraries, set the right env vars — on **every** machine. Drift between dev, staging, and prod caused the classic *"but it works on my machine."*

A **container** packages your app **with** its runtime, libraries, and config into one portable unit. The same image runs identically on your laptop, a teammate's machine, CI, EC2, and Fargate.

| | Virtual Machine | Container |
|---|---|---|
| Isolates via | Full guest OS + hypervisor | OS namespaces + cgroups (shares host kernel) |
| Size | GBs | MBs–tens of MBs |
| Boot time | Seconds–minutes | Milliseconds |
| Density per host | Tens | Hundreds–thousands |
| Use it for | Strong isolation, different kernels | Packaging & scaling app processes |

```
   VIRTUAL MACHINES                     CONTAINERS
 ┌──────┐ ┌──────┐ ┌──────┐        ┌──────┐ ┌──────┐ ┌──────┐
 │ App  │ │ App  │ │ App  │        │ App  │ │ App  │ │ App  │
 │ Libs │ │ Libs │ │ Libs │        │ Libs │ │ Libs │ │ Libs │
 │GuestOS│ │GuestOS│ │GuestOS│       └──────┘ └──────┘ └──────┘
 └──────┘ └──────┘ └──────┘        ┌──────────────────────────┐
 ┌──────────────────────────┐      │   Docker Engine          │
 │      Hypervisor          │      ├──────────────────────────┤
 ├──────────────────────────┤      │   Host OS (shared kernel)│
 │      Host OS             │      ├──────────────────────────┤
 ├──────────────────────────┤      │      Hardware            │
 │      Hardware            │      └──────────────────────────┘
 └──────────────────────────┘
```

💡 Containers don't replace VMs — on AWS your containers usually run **on** VMs (EC2) or on Fargate's managed VMs. You just stop caring about that layer.

---

## 2. Docker Architecture

```
   docker CLI  ──REST API──►  Docker Daemon (dockerd)  ──►  containerd  ──►  runc ──► your container
   (client)                   (server, on host)              (runtime)        (spawns process)
                                     │
                                     ├── pulls images from a REGISTRY (Docker Hub, ECR)
                                     ├── builds images from a Dockerfile
                                     └── manages volumes & networks
```

- **Docker CLI** — what you type (`docker run`, `docker build`).
- **Docker daemon (`dockerd`)** — long-running server that does the work.
- **Image** — read-only template (Module 2).
- **Container** — a running (or stopped) instance of an image (Module 3).
- **Registry** — stores images. Public: Docker Hub. Private on AWS: **ECR** (Module 9).

The Linux primitives doing the isolation:
- **Namespaces** — what a process can *see* (its own PIDs, network, mounts, hostname).
- **cgroups** — what a process can *use* (CPU, memory limits).
- **Union filesystem (overlayfs)** — stacks image layers + a writable container layer.

---

## 3. Install & Verify

```bash
# (local) verify Docker is installed and the daemon is running
docker --version
docker info            # shows server version, storage driver, # of containers/images
docker run hello-world # pulls a tiny image and prints a success message
```
⚠️ On Linux, `docker` needs root or membership in the `docker` group: `sudo usermod -aG docker $USER` then log out/in. On Windows/Mac use **Docker Desktop**.

---

## 4. The Everyday Commands

```bash
# IMAGES
docker pull nginx:1.27           # download an image
docker images                    # list local images
docker rmi nginx:1.27            # remove an image
docker build -t myapp:1.0 .      # build from ./Dockerfile

# CONTAINERS
docker run -d -p 8080:80 --name web nginx:1.27   # run detached, map port
docker ps                        # running containers
docker ps -a                     # include stopped ones
docker logs -f web               # tail logs
docker exec -it web sh           # shell into a running container
docker stop web && docker rm web # stop then remove

# SYSTEM
docker stats                     # live CPU/mem per container
docker system df                 # disk used by images/containers/volumes
docker system prune -a           # ⚠️ reclaim space: removes unused images/containers
```

💡 Mnemonic: **build → run → ps → logs → exec → stop → rm**. That loop is 90% of daily Docker.

---

## 5. Your First Real Container

```bash
# (local) run a Node app inline to feel the workflow
mkdir hello && cd hello
cat > server.js <<'JS'
const http = require('http');
http.createServer((_, res) => res.end('Hello from a container!\n'))
    .listen(3000, () => console.log('listening on 3000'));
JS
cat > Dockerfile <<'DOCKER'
FROM node:20-alpine
WORKDIR /app
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
DOCKER

docker build -t hello:1.0 .
docker run -d -p 3000:3000 --name hello hello:1.0
curl http://localhost:3000        # Hello from a container!
docker logs hello                 # listening on 3000
docker rm -f hello                # cleanup
```

You just built an image, ran it, served traffic, and tore it down — the entire inner loop.

---

## 6. How This Maps to AWS

| Local Docker concept | AWS equivalent |
|---|---|
| `docker run` one container | An ECS **Task** |
| Keeping it running / scaling | ECS **Service** |
| The host running containers | ECS **Cluster** (Fargate or EC2) |
| `docker push` to a registry | Push to **ECR** |
| `docker-compose.yml` | **Task Definition** (+ multiple services) |
| `-v` volume | EFS / bind / Docker volume on the task |
| `-e` env / `--env-file` | Task def `environment` / **Secrets Manager** |

Master Docker locally first (Modules 1–5), then everything in ECS (Modules 7–12) is "the same idea, managed for you."

---

## ✅ Module 1 Checklist
```
[ ] Can explain container vs VM in one sentence
[ ] docker run hello-world works
[ ] Built and ran my own image
[ ] Know the build→run→ps→logs→exec→stop→rm loop
[ ] Understand image vs container vs registry
```

➡️ Next: [02-images.md](02-images.md) — Dockerfiles, layers, and small production images.

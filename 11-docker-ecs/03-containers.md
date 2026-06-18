# Module 3 — Containers

> A container is a running (or stopped) instance of an image: an isolated process with its own filesystem, network, and resource limits. This module covers the lifecycle, the `run` flags that matter, exec/logs/inspect, and resource control.

---

## 1. Container Lifecycle

```
   docker create ──► created
        │
   docker start ──► RUNNING ──docker pause──► paused ──unpause──► RUNNING
        │              │
   docker run        docker stop (SIGTERM→SIGKILL)
   (create+start)      │
                       ▼
                    exited ──docker start──► RUNNING
                       │
                  docker rm ──► gone
```

- `docker run` = `create` + `start` in one step.
- `docker stop` sends **SIGTERM**, waits (default 10s), then **SIGKILL**. Your app should handle SIGTERM for graceful shutdown.
- A stopped container still exists (and keeps its writable layer) until `docker rm`.

---

## 2. The `run` Flags That Matter

```bash
docker run \
  -d \                          # detached (background)
  --name auth \                 # stable name (else random: "wizardly_curie")
  -p 5000:5000 \                # hostPort:containerPort
  -e NODE_ENV=production \      # env var
  --env-file ./.env \           # bulk env from file
  -v hrms-data:/app/data \      # named volume (Module 4)
  --network hrms-net \          # attach to a network (Module 5)
  --restart unless-stopped \    # auto-restart policy
  --memory 512m --cpus 0.5 \    # resource limits (Module 6 / cgroups)
  --health-cmd "curl -f http://localhost:5000/health || exit 1" \
  --health-interval 30s \
  hrms-auth:1.4.2
```

| Flag | Why |
|---|---|
| `-d` | Run in background; omit for foreground/interactive |
| `-it` | Interactive + TTY (for shells: `docker run -it alpine sh`) |
| `--rm` | Auto-remove on exit (great for one-off jobs/tests) |
| `-p` | Publish a port to the host |
| `--restart` | `no` / `on-failure` / `unless-stopped` / `always` |
| `--memory`/`--cpus` | Hard resource limits (prevents noisy-neighbor) |

💡 `-p 5000:5000` — left is the **host** port, right is the **container** port. `-p 8080:80` maps host 8080 → container 80.

---

## 3. Inspecting & Interacting

```bash
docker ps                       # running
docker ps -a                    # all, incl. exited (see exit codes)
docker logs -f --tail 100 auth  # follow last 100 log lines
docker exec -it auth sh         # shell inside a running container
docker exec auth env            # run a one-off command
docker inspect auth             # full JSON: IP, mounts, env, state
docker inspect -f '{{.State.Status}}' auth          # just the status
docker inspect -f '{{.NetworkSettings.IPAddress}}' auth
docker top auth                 # processes inside
docker port auth                # published port mappings
docker diff auth                # files changed vs the image
```

⚠️ Containers should log to **stdout/stderr** (not files inside the container). Docker/ECS capture stdout and forward it (CloudWatch Logs on ECS — Module 10). Logging to a file inside the container means logs vanish when the container dies.

---

## 4. Exit Codes — Read Them

```bash
docker ps -a    # STATUS column shows "Exited (137) 2 minutes ago"
```
| Code | Meaning |
|---|---|
| `0` | Clean exit (your process finished/returned 0) |
| `1` / `2` | App error (uncaught exception, bad config) |
| `125` | Docker daemon error (bad `run` flag) |
| `126` | Command not executable |
| `127` | Command not found (wrong path in CMD/ENTRYPOINT) |
| `137` | **SIGKILL** — usually **OOM** (out of memory) or `docker kill` |
| `139` | SIGSEGV (segfault) |
| `143` | SIGTERM (stopped normally) |

💡 `137` is the one you'll meet most on ECS — it means the container exceeded its memory limit. Raise the limit or fix the leak (Module 13).

---

## 5. Graceful Shutdown (do this in your app)

```js
// Node example — handle SIGTERM so docker/ECS stop is clean
const server = app.listen(5000);
process.on('SIGTERM', () => {
  console.log('SIGTERM received, draining connections...');
  server.close(() => { /* close DB pool */ process.exit(0); });
});
```
Without this, the platform waits the timeout then SIGKILLs you mid-request. On ECS this controls how deployments and scale-in drain traffic.

---

## 6. One-Off & Debug Containers

```bash
# throwaway shell to poke at a network/image
docker run --rm -it --network hrms-net alpine sh
# inside: apk add curl; curl http://auth:5000/health

# run a command against the same image without changing the service
docker run --rm hrms-auth:1.4.2 node -e "console.log(process.version)"
```

---

## 7. Cleanup

```bash
docker stop $(docker ps -q)        # stop all running
docker rm $(docker ps -aq)         # remove all containers
docker container prune             # remove all stopped containers
docker rm -f auth                  # force-remove a running one
```

---

## ✅ Module 3 Checklist
```
[ ] Know the lifecycle (create→start→stop→rm)
[ ] Comfortable with -d, -p, -e, --rm, --restart, --memory
[ ] Can exec into a container and read its logs
[ ] Can read exit codes (especially 137 = OOM)
[ ] App handles SIGTERM for graceful shutdown
[ ] Logs go to stdout/stderr, not files inside
```

➡️ Next: [04-volumes.md](04-volumes.md) — keeping data when containers die.

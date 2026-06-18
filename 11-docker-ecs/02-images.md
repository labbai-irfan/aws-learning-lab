# Module 2 — Images

> An image is an immutable, layered, tagged filesystem + metadata. This module covers the Dockerfile instruction set, layer caching, multi-stage builds, tagging, and shrinking images for production.

---

## 1. What an Image Is

An image is a stack of **read-only layers** plus a JSON **manifest/config** (entrypoint, env, exposed ports, etc.). Each Dockerfile instruction that changes the filesystem creates a new layer. Layers are content-addressed (SHA digests) and **shared** between images — pull `node:20` once and ten apps based on it reuse those layers.

```
   myapp:1.0
   ┌─────────────────────────────┐  ← writable layer added at RUN time (container only)
   │ CMD ["node","server.js"]    │  (metadata, no fs change)
   │ COPY . .            (layer) │
   │ RUN npm ci          (layer) │
   │ COPY package*.json  (layer) │
   │ WORKDIR /app        (layer) │
   │ FROM node:20-alpine (base)  │  ← shared with every node:20-alpine image
   └─────────────────────────────┘
```

---

## 2. Dockerfile Instructions You Need

| Instruction | Purpose | Example |
|---|---|---|
| `FROM` | Base image | `FROM node:20-alpine` |
| `WORKDIR` | Set/create working dir | `WORKDIR /app` |
| `COPY` / `ADD` | Copy files in (`ADD` also untars/URLs — prefer `COPY`) | `COPY . .` |
| `RUN` | Execute at **build** time | `RUN npm ci --omit=dev` |
| `ENV` | Set env var | `ENV NODE_ENV=production` |
| `ARG` | Build-time variable | `ARG VERSION` |
| `EXPOSE` | Document a port (doesn't publish) | `EXPOSE 3000` |
| `USER` | Drop to non-root | `USER node` |
| `ENTRYPOINT` | Fixed executable | `ENTRYPOINT ["node"]` |
| `CMD` | Default args (overridable) | `CMD ["server.js"]` |
| `HEALTHCHECK` | Container self-test | `HEALTHCHECK CMD curl -f localhost:3000/health` |

💡 `ENTRYPOINT` + `CMD`: ENTRYPOINT is the program, CMD is the default args. `docker run img foo` overrides CMD only.

---

## 3. Layer Caching — Order Matters

Docker caches each layer. If a layer's inputs are unchanged, it's reused; once one layer is invalidated, **every layer after it rebuilds**. So put rarely-changing steps first.

```dockerfile
# ❌ SLOW — any source change re-runs npm install
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm ci
CMD ["node","server.js"]

# ✅ FAST — deps cached unless package.json changes
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./     # changes rarely
RUN npm ci                # cached layer reused on code-only edits
COPY . .                  # changes often → only this + below rebuild
CMD ["node","server.js"]
```

⚠️ Use a **`.dockerignore`** so `COPY . .` doesn't bloat the image / bust cache:
```
node_modules
.git
.env
npm-debug.log
dist
*.md
```

---

## 4. Multi-Stage Builds (the production trick)

Build with a heavy toolchain, ship only the artifacts. Smaller image = faster pulls, smaller attack surface.

```dockerfile
# ---- build stage: has compilers, dev deps ----
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build              # produces /app/dist

# ---- runtime stage: tiny, only what runs ----
FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# nginx base already has the right CMD
```
A React app goes from ~1.2 GB (full node) to ~25 MB (nginx-alpine + static files).

For a Node API:
```dockerfile
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
USER node
EXPOSE 5000
CMD ["node","dist/server.js"]
```

---

## 5. Tags & Naming

Format: `[registry/]repository:tag`. No tag → defaults to `:latest`.

```bash
docker build -t hrms-auth:1.4.2 .
docker tag hrms-auth:1.4.2 hrms-auth:latest

# tag for ECR (Module 9)
docker tag hrms-auth:1.4.2 \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/hrms-auth:1.4.2
```
⚠️ **Never deploy `:latest` to production.** It's a moving target — you can't tell what's running or roll back deterministically. Use immutable tags (semver or the git SHA): `hrms-auth:1.4.2`, `hrms-auth:git-9f3c1a`.

---

## 6. Inspecting & Sharing Images

```bash
docker history myapp:1.0       # layer-by-layer size — find the fat layer
docker image inspect myapp:1.0 # full JSON metadata
docker save myapp:1.0 -o myapp.tar   # export to a tarball
docker load -i myapp.tar             # import elsewhere

docker login                   # to Docker Hub
docker push youruser/myapp:1.0 # share publicly (use ECR for private — Module 9)
```

---

## 7. Image Hygiene Checklist (production)
```
[ ] Slim base (alpine / distroless / -slim)
[ ] Multi-stage: no compilers/dev deps in the final image
[ ] .dockerignore present (node_modules, .git, .env)
[ ] Pinned base tag (node:20-alpine, not node:latest)
[ ] Runs as non-root (USER)
[ ] Immutable, meaningful tags (semver / git SHA)
[ ] HEALTHCHECK defined
[ ] Scanned for CVEs (docker scout / ECR scan — Module 9)
[ ] Secrets NOT baked in (no .env, no keys in layers)
```
🔒 Secrets in a layer are **permanently** in the image even if a later layer deletes them — anyone with the image can extract them. Inject secrets at runtime (Module 10 / Secrets Manager).

➡️ Next: [03-containers.md](03-containers.md) — running, inspecting, and managing containers.

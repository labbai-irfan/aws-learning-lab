# Module 3 — EC2 Instance Selection Guide

> How to pick the right instance type for a workload — the question every architect and interviewer asks. Includes a decision framework, family cheat sheet, sizing examples, and Graviton/Spot guidance.

---

## The 5-Step Selection Framework

```
1. WORKLOAD PROFILE  → CPU-bound? Memory-bound? I/O-bound? GPU? Balanced?
2. SIZE              → How many vCPU / GB RAM at peak? (measure, don't guess)
3. ARCHITECTURE      → x86 (Intel/AMD) or ARM (Graviton, cheaper)?
4. PURCHASE MODEL    → On-Demand / Reserved / Savings Plan / Spot?
5. VALIDATE          → Launch, load-test, watch CloudWatch, rightsize.
```

---

## Step 1 — Match Workload to Family

| If your workload is... | Pick family | Examples |
|------------------------|-------------|----------|
| Balanced / general web app, dev/test | **T** (burstable) or **M** | t3/t4g, m5/m7g |
| CPU-heavy (batch, encoding, gaming, HPC) | **C** (compute) | c6g, c7g |
| Memory-heavy (databases, caches, analytics, in-memory) | **R / X / z** (memory) | r6g, r7g, x2 |
| Disk I/O-heavy (NoSQL, data warehouse, big local disk) | **I / D / H** (storage) | i4i, d3 |
| ML / GPU / graphics | **P / G / Inf / Trn** | p4, g5, inf2 |

💡 **Memory aid:** **C**ompute, **R**AM, **I**/O, **G**PU; **T/M** = general.

---

## Step 2 — Size It (don't over-provision)

| Size | Typical vCPU | Typical RAM | Good for |
|------|--------------|-------------|----------|
| nano/micro | 2 (burst) | 0.5–1 GB | tiny sites, learning (Free Tier t2/t3.micro) |
| small/medium | 2 | 2–4 GB | small apps, low-traffic APIs |
| large | 2 | 8 GB | typical production web/app node |
| xlarge–2xlarge | 4–8 | 16–32 GB | busy apps, small DBs |
| 4xlarge+ | 16+ | 64 GB+ | heavy DBs, big workloads |

⚠️ **Start smaller, scale out/up after measuring.** Over-provisioning is the #1 EC2 cost waste.

---

## Step 3 — x86 vs Graviton (ARM)

- **Graviton** (`t4g`, `m7g`, `c7g`, `r7g`) = AWS-designed ARM CPUs: ~**20% cheaper** and often better performance per watt.
- ✅ Use Graviton for: Node.js, Java, Python, Go, Nginx, containers, most modern Linux workloads (recompile/repull ARM images).
- ⚠️ Avoid if: you depend on x86-only binaries/legacy software.

💰 **Tip:** For a Node + Nginx + MySQL stack, `t4g`/`m7g` (Graviton) is usually the best price/performance.

---

## Step 4 — Purchase Model (recap from Phase 01)

| Model | Use when | Savings |
|-------|----------|---------|
| **On-Demand** | Short-term, spiky, unknown | baseline |
| **Reserved / Savings Plans** | Steady 24/7 baseline, 1–3 yr | up to ~72% |
| **Spot** | Interruptible/batch/stateless workers | up to ~90% |
| **Dedicated Hosts** | Licensing/compliance | most $$$ |

💡 **Pattern:** Savings Plan for the baseline ASG capacity + Spot for burst/batch capacity.

---

## Step 5 — Validate & Rightsize
- Launch, run a realistic load test.
- Watch **CloudWatch**: CPUUtilization, memory (needs CloudWatch agent), network, EBS IOPS.
- Use **Compute Optimizer** / Cost Explorer **rightsizing** recommendations.
- Adjust: scale **up** (bigger type) for single-thread limits; scale **out** (more instances) for throughput.

---

## Worked Examples

**A) Small React + Node + MySQL learning app (the capstone)**
- Traffic: low. Choice: **t3.small / t4g.small** (2 vCPU, 2 GB). Free-tier-adjacent, burstable.
- Why: balanced, cheap, bursts for occasional load.

**B) Production REST API, steady 24/7, moderate traffic**
- Choice: **m7g.large** behind an ALB in an ASG (min 2, multi-AZ) + Savings Plan.
- Why: balanced compute/memory, Graviton savings, HA + elasticity.

**C) In-memory analytics / Redis-heavy cache**
- Choice: **r7g.xlarge** (memory optimized).
- Why: large RAM is the bottleneck, not CPU.

**D) Nightly video transcoding (interruptible)**
- Choice: **c7g** on **Spot** in an ASG.
- Why: CPU-bound + restartable → cheapest compute via Spot.

**E) ML model training**
- Choice: **p4 / g5** GPU instances; consider Spot for checkpointed training.

---

## Burstable (T) Instances — read before choosing t-series
- Earn **CPU credits** when idle; spend when busy. Great for variable/low CPU.
- ⚠️ Sustained high CPU exhausts credits → throttling, or **T Unlimited** mode bills for surplus CPU.
- If your app is consistently busy, a fixed-performance **M/C** type is cheaper/more predictable than a throttled/Unlimited T.

---

## Quick Decision Tree
```
GPU/ML needed? ──yes──► P/G/Inf/Trn
   │ no
Memory the bottleneck? ──yes──► R/X/z
   │ no
CPU the bottleneck? ──yes──► C
   │ no
High local disk I/O? ──yes──► I/D/H
   │ no
Low/variable traffic? ──yes──► T (burstable)
   │ no
Steady balanced load ──► M (general purpose)
Then: prefer Graviton (g) if compatible; choose purchase model by pattern.
```

---

## Common Mistakes
- ⚠️ Picking a huge instance "to be safe" → wasted money. Start small, scale.
- ⚠️ Using burstable T for sustained CPU → throttling/surprise Unlimited charges.
- ⚠️ Ignoring Graviton → leaving ~20% savings on the table.
- ⚠️ Scaling **up** when you should scale **out** (ASG) for resilience.

---

➡️ Next: [04-cost-calculation.md](04-cost-calculation.md)

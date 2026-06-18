# 11 — EFS & FSx (Shared File Storage) — Breadth Top-Up

> S3 is **object** storage. This module covers AWS's **file** storage (mountable filesystems) — a common SAA exam comparison. Use it to answer "S3 vs EBS vs EFS vs FSx".

**By the end you can:** pick the right storage type for a workload, and know what EFS and the FSx family are for.

---

## 1. The three storage types
| Type | Service | Mental model | Access |
|---|---|---|---|
| **Object** | **S3** | Key + value + metadata, flat, web-scale | HTTP API |
| **Block** | **EBS** | A raw disk for one instance (OS, DBs) | Attached to 1 EC2 (1 AZ) |
| **File** | **EFS / FSx** | A shared filesystem many clients mount | NFS / SMB mount |

💡 Exam: "shared filesystem mounted by many EC2/containers" → **EFS** (Linux/NFS) or **FSx** (Windows/specialized). "Single-instance disk" → **EBS**. "Store/serve files over HTTP at scale" → **S3**.

---

## 2. Amazon EFS (Elastic File System)
- **NFS** shared filesystem for **Linux**; mounted by many EC2 instances / ECS / Lambda **simultaneously**, across **multiple AZs**.
- **Elastic** — grows/shrinks automatically; pay for what you use.
- **Throughput modes:** Bursting (default) or Elastic/Provisioned.
- **Storage classes:** Standard and **EFS-IA / Archive** (lifecycle policies move infrequent files to cheaper tiers).
- **Use for:** shared content/uploads across a fleet, CMS, home directories, lift-and-shift NFS apps, container shared volumes.
- 🔒 Encryption at rest (KMS) + in transit (TLS); access via security groups + (optional) **EFS Access Points** + IAM.

```
   EC2 (AZ-a) ─┐
   EC2 (AZ-b) ─┼─ mount ─► [ EFS filesystem ]  (multi-AZ, elastic, NFS)
   ECS task   ─┘
```
⚠️ EFS is pricier per GB than S3/EBS — use it when you genuinely need a **shared POSIX filesystem**, not as a cheap bucket.

---

## 3. Amazon FSx (managed third-party filesystems)
| FSx flavor | For |
|---|---|
| **FSx for Windows File Server** | SMB shares, Active Directory, Windows apps |
| **FSx for Lustre** | High-performance computing (HPC), ML, big-data; integrates with S3 |
| **FSx for NetApp ONTAP** | Enterprise NAS features (snapshots, dedup, multi-protocol) |
| **FSx for OpenZFS** | ZFS workloads, low-latency, snapshots |

💡 Exam: "Windows/SMB + Active Directory" → **FSx for Windows**. "HPC/ML, fastest throughput, S3-linked" → **FSx for Lustre**.

---

## 4. Quick decision
```
Need HTTP object store, web scale          → S3
Need a disk for ONE instance (OS/DB)        → EBS
Need a shared Linux/NFS filesystem          → EFS
Need shared Windows/SMB + AD                → FSx for Windows
Need HPC/ML high-throughput scratch         → FSx for Lustre
```

## 5. Exam triggers 💡
- "Multiple EC2 across AZs need the same files, read/write" → **EFS**.
- "Migrate a Windows app using SMB shares" → **FSx for Windows**.
- "ML training needs sub-ms, S3-backed scratch storage" → **FSx for Lustre**.
- "Cheapest for infrequently accessed shared files" → **EFS-IA / Archive** via lifecycle.
- "Single instance database volume" → **EBS** (not EFS).

---
*Back to [S3 README](README.md). Related: [03 EC2 EBS](../03-ec2/01-ec2-core-concepts.md).*

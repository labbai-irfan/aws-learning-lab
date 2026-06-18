# Phase 05 — Amazon S3 Complete Learning Repository

> A hands-on, architecture-focused course on **Amazon S3 (Simple Storage Service)** — from your first bucket to designing file-upload, media, backup, and HRMS storage systems, and building a **secure React + Node + S3 file-upload app** using pre-signed URLs.

Authored as a structured program by an **AWS Storage Architect**. Builds on [Phase 01 — AWS Fundamentals](../01-aws-fundamentals/README.md) and [Phase 03 — EC2](../03-ec2/README.md). Every module has explanations, diagrams, real commands, and practice questions.

---

## 🎯 Who This Is For
- Anyone who finished Phases 01 & 03 and wants to master cloud storage.
- Developers building **file upload / media / backup** features.
- Candidates preparing for **AWS Solutions Architect / Developer Associate** and backend interviews.

**Prerequisites:** An AWS account with MFA + a billing budget ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)). Basic command line + Node.js comfort helps for the project.

---

## 🗺️ Learning Path

| # | Module | File | Time |
|---|--------|------|------|
| 0 | Start Here (this file) | [README.md](README.md) | 15 min |
| 1 | S3 Core Concepts (all topics) | [01-s3-core-concepts.md](01-s3-core-concepts.md) | 4 hrs |
| 2 | Architectures (Upload / Media / Backup / HRMS) | [02-architectures.md](02-architectures.md) | 1.5 hrs |
| 3 | Cost Optimization | [03-cost-optimization.md](03-cost-optimization.md) | 1 hr |
| 4 | Security Guide | [04-security-guide.md](04-security-guide.md) | 1.5 hrs |
| 5 | Troubleshooting | [05-troubleshooting.md](05-troubleshooting.md) | 1 hr |
| 6 | Labs (hands-on) | [06-labs.md](06-labs.md) | 4 hrs |
| 7 | 100 MCQs | [07-100-mcqs.md](07-100-mcqs.md) | 2 hrs |
| 8 | 100 Interview Questions | [08-100-interview-questions.md](08-100-interview-questions.md) | 2 hrs |
| 9 | 50 Scenario Questions | [09-50-scenario-questions.md](09-50-scenario-questions.md) | 2 hrs |
| 10 | **Capstone Project:** Secure file upload (React + Node + S3) | [project/README.md](project/README.md) | 6+ hrs |

**Total:** ~25 hours.

---

## 📚 Topics Covered

**Core building blocks** (Module 1)
- Buckets · Objects · Storage Classes · Versioning · Lifecycle Policies · Replication · Static Website Hosting · Pre-Signed URLs · Access Policies · Encryption · CloudFront Integration

**Architecture & operations**
- File Upload Architecture · Media Storage Architecture · Backup Architecture · HRMS File Storage Architecture (Module 2)
- Cost Optimization (Module 3) · Security Guide (Module 4) · Troubleshooting (Module 5)

**Practice**
- Labs · 100 MCQs · 100 interview questions · 50 scenario questions · 1 capstone project

---

## ⚡ S3 Mental Model (60-second overview)

```
   REGION
   └── BUCKET  (globally-unique name, lives in one Region)
        ├── OBJECT  s3://bucket/photos/2026/cat.jpg
        │     ├── Key:        photos/2026/cat.jpg   (the full "path")
        │     ├── Value:      the bytes (up to 5 TB)
        │     ├── Metadata:   content-type, custom tags
        │     ├── Version ID: (if versioning enabled)
        │     └── Storage class: Standard / IA / Glacier / ...
        │
        ├── Access:     Block Public Access + Bucket Policy + IAM + ACL (legacy)
        ├── Encryption: SSE-S3 (default) / SSE-KMS / SSE-C / client-side
        ├── Lifecycle:  transition to cheaper class / expire old versions
        ├── Versioning: keep every version (protect from overwrite/delete)
        ├── Replication: copy to another bucket/Region (CRR/SRR)
        ├── Website:    serve static HTML directly
        └── Pre-signed URL: time-limited, credential-free upload/download
                              └── CloudFront in front for global low-latency CDN
```

**In words:** S3 stores **objects** (files + metadata) inside **buckets** (Region-scoped, globally-unique names). It's object storage (not a filesystem) — flat key space, "folders" are just key prefixes. You pick a **storage class** for cost/access tradeoffs, protect data with **versioning/encryption/access policies**, automate tiering with **lifecycle rules**, copy across Regions with **replication**, serve files via **static hosting/CloudFront**, and grant temporary access with **pre-signed URLs**.

---

## 🔑 S3 in One Line per Topic

| Topic | One-liner |
|-------|-----------|
| **Bucket** | Region-scoped container with a globally-unique name |
| **Object** | A file (key + bytes + metadata), up to 5 TB |
| **Storage Classes** | Cost vs access-speed tiers (Standard → Glacier Deep Archive) |
| **Versioning** | Keep every version; protects against overwrite/delete |
| **Lifecycle** | Auto-transition/expire objects to save money |
| **Replication** | Auto-copy objects to another bucket (CRR/SRR) |
| **Static Hosting** | Serve a website straight from a bucket |
| **Pre-Signed URL** | Time-limited URL to upload/download without credentials |
| **Access Policies** | Block Public Access + bucket policy + IAM control who does what |
| **Encryption** | At-rest (SSE-S3/KMS/C) + in-transit (TLS) |
| **CloudFront** | CDN that caches S3 content at the edge globally |

---

## 🛠️ What You'll Build (Capstone)

A secure, scalable file-upload system where files go **directly from the browser to S3** (the server never proxies the bytes):
```
   React  ──(1) ask for upload URL──►  Node API ──(generates)──► Pre-Signed PUT URL
     │                                    (IAM creds stay on server)
     └──(2) PUT file directly to S3 ─────────────────────────────► Private S3 bucket
                                                                       │
   React ◄──(3) pre-signed GET URL / CloudFront ◄── download/serve ────┘
```
Full step-by-step in [project/README.md](project/README.md).

---

## 📌 Conventions
- 🛠️ = run this · 💰 = cost note · ⚠️ = gotcha · 🔒 = security · 💡 = tip
- `s3://bucket/key` = an object path · CLI examples use AWS CLI v2 / SDK v3

---

## 📖 Official References
- S3 docs: https://docs.aws.amazon.com/s3/
- S3 storage classes: https://aws.amazon.com/s3/storage-classes/
- S3 pricing: https://aws.amazon.com/s3/pricing/
- S3 security best practices: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html

---

*Start with [01-s3-core-concepts.md](01-s3-core-concepts.md).* 🚀

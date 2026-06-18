# AWS Mastery Roadmap — Repository Audit & Improvement Plan

> ✅ **SPRINT 1 IMPLEMENTED (2026-06-17).** Folders have since been renumbered to the corrected linear order (`01-…` through `13-…`), all cross-links updated, broken README links fixed, and a root [README.md](README.md) + [STANDARDS.md](STANDARDS.md) added. **This document is preserved as the original "before" audit** — the `phase-N-…` folder names referenced below reflect the pre-implementation state. See [README.md](README.md) for the current structure and the [Improvement Roadmap](#final--improvement-roadmap) for remaining (Sprint 2–3) work.

> **Auditor role:** Principal AWS Solutions Architect · Senior DevOps Lead · Curriculum Designer · Repository Maintainer
> **Audit date:** 2026-06-17
> **Scope:** 13 phase folders · ~150 files · full structure, sequencing, gaps, standards, certification & HRMS alignment
> **Verdict:** Strong, high-quality content with **excellent depth** — but undermined by **numbering collisions, broken README links, structural inconsistency, and an incorrect dependency order**. Fixable in ~3 focused sprints.

---

## 0. Executive Summary — Scorecard

| Dimension | Score | One-line verdict |
|---|---|---|
| Content quality (per file) | 🟢 9/10 | Diagrams, real commands, cost notes, scenarios — genuinely production-grade |
| Folder/numbering integrity | 🔴 3/10 | 4 duplicate phase numbers; no root README |
| Learning-order correctness | 🟠 5/10 | RDS-before-VPC and CI/CD-before-ECS are dependency inversions |
| Structural consistency | 🔴 4/10 | 4 different internal layouts; `project/` vs `projects/` vs `aws/labs/docs` |
| Documentation accuracy | 🟠 5/10 | Serverless + Phase-9 READMEs link to **non-existent files** |
| Certification coverage | 🟠 7/10 | CP & SAA strong; DVA & DevOps-Pro have real gaps |
| HRMS project alignment | 🟢 8/10 | Already HRMS-aware (security + capstone) — needs an index |

**Top 5 must-fix items (in order):**
1. Create a **root `README.md`** — the repo has no entry point.
2. Resolve **4 duplicate phase numbers** (two `phase-3`, two `phase-5`, two `phase-6`, two `phase-8`).
3. Fix **broken README links** in `phase-3-serverless` and `phase-9-advanced-aws` (they reference files that were never created).
4. Correct **dependency order**: VPC before RDS; Docker/ECS before CI/CD.
5. Standardize the **content checklist** every phase must satisfy (MCQs, interview, cheatsheet, cert-map missing in several phases).

---

# PHASE 1 — FULL AUDIT REPORT

## 1.1 Repository-wide findings

| # | Current State | Problem | Why It's Wrong | Recommended Fix |
|---|---|---|---|---|
| R1 | No file at repo root | No `README.md` index | A learner opening the repo has no map, no start point, no ordering. The whole "phase" design is invisible. | Create root `README.md` with the master roadmap table, prerequisites graph, and links into each phase. |
| R2 | `phase-3-s3` **and** `phase-3-serverless`; `phase-5-cloudwatch` **and** `phase-5-vpc`; `phase-6-route53` **and** `phase-6-security`; `phase-8-cicd` **and** `phase-8-docker-ecs` | 4 duplicate phase numbers | Numbering is the navigation contract. Two `phase-5`s makes "do phase 5 next" ambiguous and breaks any sort order. | Renumber to a single linear sequence (see Phase 5 of this report). |
| R3 | `phase-2-ec2/project/`, `phase-3-s3/project/` (singular) vs `phase-3-serverless/projects/` (plural) vs `phase-8-cicd` (no project folder, uses `aws/`+`labs/`+`docs/`) | Inconsistent internal layout | A standardized repo lets a learner predict where things live. Four different layouts force re-learning navigation every phase. | Adopt one standard layout (Phase 6). Pick `project/` (singular) for single capstone, `projects/` only where there are genuinely multiple. |
| R4 | No global naming standard file | Implicit, drifting conventions | Files are sometimes `07-100-mcqs.md`, sometimes there's no MCQ file at all; `troubleshooting.md` vs `troubleshooting-guide.md` vs `troubleshooting-handbook.md`. | Add `CONTRIBUTING.md` / `STANDARDS.md` defining the canonical file set + naming (Phase 6). |
| R5 | No `LICENSE`, no `.gitignore`, repo is **not a git repository** | Not version-controlled | `node_modules`, `.env`, and Terraform state risk being committed; no history/rollback; can't collaborate or publish to GitHub. | `git init`, add `.gitignore` (node, terraform, env, OS), add `LICENSE` (MIT/CC-BY for learning content). |
| R6 | No cross-phase **glossary** or **services index** | Hard to look up a service | Services are taught in-phase only (e.g., SQS appears in serverless *and* phase-9). No single "where is X taught?" index. | Add `GLOSSARY.md` + `SERVICES-INDEX.md` at root. |

## 1.2 Per-phase audit

### phase-1-aws-fundamentals 🟢 (Reference-quality)
- **Current:** README + 14 numbered files (notes, diagrams, real-world, migration, account setup, billing, 100 MCQs, 100 interview, 50 scenarios, revision, certification, common mistakes, hands-on, mini-projects).
- **Problem:** No `project/` code folder; "revision-notes" doubles as a cheatsheet but isn't named as one.
- **Why it matters:** Minor — this is the gold-standard phase other phases should imitate.
- **Fix:** Rename/duplicate `10-revision-notes.md` intent into a `CheatSheet`; otherwise **use this phase as the template**.

### phase-2-ec2 🟢
- **Current:** README + 11 files + full-stack `project/` (backend, frontend, PM2, nginx). Excellent.
- **Problem:** No cheatsheet; no certification-mapping file; numbering jumps are fine.
- **Fix:** Add `12-cheatsheet.md` and a short "SAA/SysOps relevance" callout.

### phase-3-s3 🟢
- **Current:** README + 9 files + `project/` (presigned-URL uploader).
- **Problem:** No cheatsheet, no cert-map. Otherwise complete.
- **Fix:** Add cheatsheet + cert-map.

### phase-3-serverless 🔴 (Documentation broken)
- **Current:** README + files `01–07`, `10-interview`, `11-troubleshooting` + `projects/01–03`.
- **Problem 1:** README's structure block lists **`08-security-design.md`, `09-cost-optimization.md`, a whole `code-examples/` tree, and `projects/04-api-backend/` — none of which exist.**
- **Problem 2:** Numbering gap (`07` → `10`) with no `08`/`09`. No MCQ file. No labs file. No cheatsheet/cert-map.
- **Problem 3:** **Duplicate phase number with `phase-3-s3`.**
- **Why it's wrong:** README is a contract; broken links destroy trust and break navigation. The gap implies "missing/deleted" content.
- **Fix:** Either create the four missing artifacts (08, 09, code-examples, project 04) **or** correct the README to match reality. Renumber phase. Add MCQs + labs.

### phase-4-rds 🟢 (Reference-quality)
- **Current:** README + 14 files (core, engines, prod-arch, migration, prisma, backup/DR, scaling, security, monitoring, troubleshooting, labs, 100 MCQs, 100 interview, 50 scenarios) + `project/` (Prisma + schema).
- **Problem:** No cheatsheet/cert-map. **Sits at phase-4 but depends on VPC (phase-5)** — see Phase 2 of this report.
- **Fix:** Reorder after VPC; add cheatsheet.

### phase-5-cloudwatch 🟢
- **Current:** README + 15 files + `project/` (dashboard.json, alarms.sh, instrumentation). Very complete.
- **Problem:** **Duplicate phase number with `phase-5-vpc`.** No cheatsheet/cert-map.
- **Fix:** Renumber (monitoring belongs *after* compute/network/LB, ~phase 9).

### phase-5-vpc 🟠
- **Current:** README + 9 files + `project/` (Terraform VPC).
- **Problem:** **Duplicate phase number with cloudwatch.** Positioned *after* RDS/EC2 although both depend on networking. No cheatsheet/cert-map.
- **Fix:** Move VPC **earlier** (right after IAM/EC2 basics, before RDS/ELB).

### phase-6-route53 🟠 (Thin)
- **Current:** README + 6 files (core, architectures, labs, troubleshooting, interview, scenarios).
- **Problem:** **Duplicate phase number with security.** No MCQ file, no cost-optimization file, no security file, no `project/`.
- **Fix:** Add MCQs + a small project (health-check failover); renumber.

### phase-6-security 🟠 (Misplaced + thin on practice)
- **Current:** README + 9 files (core, attack scenarios, audits, least-privilege, prod checklist, HRMS security, troubleshooting, incident response, interview).
- **Problem:** **Duplicate phase number.** No MCQ file, no labs file, no `project/`. **IAM/security fundamentals appear at phase-6 but are needed from day one.**
- **Why it's wrong:** Every other service (EC2, S3, RDS) is taught with security as an afterthought because the security *basics* come too late.
- **Fix:** **Split** — pull "IAM & security basics" forward to ~phase 2; keep advanced security (audits, incident response, attack scenarios) later. Add MCQs + labs.

### phase-7-elb 🟠 (Thinnest of the "service" phases)
- **Current:** README + 5 files (core, architectures, labs, scenarios, troubleshooting).
- **Problem:** No MCQ file, no interview file, no `project/`, no cost file (though README has a cost note). Auto Scaling is referenced but has no dedicated module.
- **Fix:** Add MCQs + interview + an Auto-Scaling-Group module + a small project (ALB + ASG + multi-AZ).

### phase-8-cicd 🟢 (Excellent but non-standard layout)
- **Current:** README + `.github/workflows/` (5 pipelines) + `aws/` (codebuild, codedeploy, codepipeline, blue-green, canary, ecs, scripts) + `docs/` (5 guides incl. interview) + `labs/` (5 labs) + Dockerfile.
- **Problem:** **Duplicate phase number with docker-ecs.** Completely different layout (no numbered notes, no MCQ file, interview is inside `docs/`). **Depends on Docker/ECS knowledge that is taught in the *sibling* phase-8.**
- **Fix:** Place **after** Docker/ECS. Add an MCQ file; keep the `labs/`+`docs/` layout but document it as the "tooling-phase" variant.

### phase-8-docker-ecs 🟢
- **Current:** README + 13 files (Docker fundamentals → images/containers/volumes/networks → ECS/Fargate/ECR/taskdefs/services/clusters → troubleshooting) + `project/` (4 microservices + compose + ECS taskdefs).
- **Problem:** **Duplicate phase number.** No MCQ, no interview, no scenarios file.
- **Fix:** Renumber **before** CI/CD; add MCQs + interview.

### phase-9-advanced-aws 🔴 (Documentation broken)
- **Current:** README + 15 files (CloudFront, ElastiCache, SQS/SNS, Terraform, CloudFormation, WAF/Shield, Organizations, enterprise/multi-region/scalability/security/devops/SaaS architecture, case studies, troubleshooting).
- **Problem 1:** README lists **`16-200-interview-questions.md`, `17-200-mcqs.md`, and a `project/` HRMS capstone — none exist.**
- **Problem 2:** `03-sqs-sns.md` **duplicates** SQS/SNS already taught in `phase-3-serverless`.
- **Why it's wrong:** Broken links again; the flagship "capstone" the README advertises is absent.
- **Fix:** Build the missing interview/MCQ/capstone, or correct the README. De-duplicate SQS/SNS (teach once, cross-link).

---

# PHASE 2 — LEARNING-ORDER VALIDATION

## 2.1 Numbering mistakes (hard errors)

| Collision | Folders | Result |
|---|---|---|
| `phase-3` ×2 | `phase-3-s3`, `phase-3-serverless` | Ambiguous "phase 3" |
| `phase-5` ×2 | `phase-5-cloudwatch`, `phase-5-vpc` | Ambiguous "phase 5" |
| `phase-6` ×2 | `phase-6-route53`, `phase-6-security` | Ambiguous "phase 6" |
| `phase-8` ×2 | `phase-8-cicd`, `phase-8-docker-ecs` | Ambiguous "phase 8" |
| `phase-4` skipped after serverless | — | No `phase-4` issue, but the s3/serverless split orphaned the count |

## 2.2 Dependency mistakes (pedagogical errors)

| Inversion | Why it's wrong | Correct order |
|---|---|---|
| **RDS (4) before VPC (5)** | RDS requires **DB subnet groups, private subnets, security groups** — all VPC concepts. You cannot properly secure RDS without VPC first. | VPC → RDS |
| **CI/CD (8-cicd) before/with Docker-ECS (8)** | `phase-8-cicd` ships `appspec-ecs.yml`, `lab-04-blue-green-ecs`, ECS task-defs — it **assumes ECS fluency**. | Docker/ECS → CI/CD |
| **Security (6) taught late** | IAM, key pairs, security groups, least-privilege are used from EC2 (phase 2) onward, but the security *foundations* arrive at phase 6. | IAM/Security **basics** → everything; advanced security later |
| **CloudWatch (5) before ELB/ASG (7)** | Monitoring is most meaningful once you have scaling fleets and LBs to watch. Not strictly wrong, but better after the compute/network/LB tier. | EC2/VPC/ELB → CloudWatch |
| **Route 53 (6) standalone-early** | DNS is best taught **with** ELB/CloudFront (alias records point at them). | ELB → Route 53 (or just before) |

## 2.3 Missing prerequisite topics
- **Auto Scaling Groups** — referenced everywhere (EC2, ELB, CI/CD) but no dedicated module.
- **IAM deep-dive as a first-class early phase** — currently folded into a late "security" phase.
- **DynamoDB** — required for serverless *and* the DVA exam; only mentioned, never taught.
- **CLI / SDK / CloudShell setup** — assumed from phase 2 but never formally introduced.

## 2.4 Corrected learning path (summary — full version in Phase 5)

```
Fundamentals → IAM/Security Basics → EC2 → VPC/Networking → S3 → RDS →
ELB + Auto Scaling → Route 53 → CloudWatch/Monitoring → Serverless →
Docker → ECS/Fargate → CI/CD → Advanced AWS → IaC (Terraform/CFN) →
Production Architecture (HRMS capstone) → Advanced Security/DR
```

---

# PHASE 3 — REBUILD STRUCTURE

## 3.1 The standardized phase template (target)

```
NN-phase-name/
├── README.md                      ← roadmap, prereqs, mental model, cost note
├── notes/
│   ├── 01-beginner-notes.md
│   ├── 02-intermediate-notes.md
│   └── 03-advanced-notes.md
├── architecture/
│   └── architecture.md            ← ASCII + decision diagrams
├── labs/
│   ├── lab-01.md
│   ├── lab-02.md
│   └── lab-03.md
├── project/                       ← single capstone  (projects/ only if >1)
│   ├── README.md
│   └── <code>
├── interview/
│   ├── beginner.md
│   ├── intermediate.md
│   └── advanced.md
├── practice/
│   ├── mcqs.md                    ← 100 MCQs
│   └── scenarios.md               ← 50 scenario questions
├── troubleshooting/
│   └── common-issues.md
├── cheatsheets/
│   └── cheatsheet.md
└── certification/
    ├── cloud-practitioner.md      ← only where relevant
    └── saa.md
```

## 3.2 Architect's recommendation (important — read before migrating)

> **Do NOT blindly migrate the existing flat numbered files into deep subfolders.** The current `01-...md … 14-...md` flat convention is actually **good for linear self-study** (open folder, read top to bottom). Deep nesting adds click-friction for a learning repo.

**Recommended hybrid standard:** keep **flat, numbered files** inside each phase, but enforce a **mandatory content checklist** (every phase must contain each category below, in this numbering band):

| Band | Category | Canonical filename |
|---|---|---|
| 01–0x | Core + topic notes | `01-<topic>-core-concepts.md`, … |
| then | Architecture | `NN-architectures.md` |
| then | Cost optimization | `NN-cost-optimization.md` |
| then | Security | `NN-security-guide.md` |
| then | Labs | `NN-labs.md` |
| then | Troubleshooting | `NN-troubleshooting.md` |
| then | Cheatsheet | `NN-cheatsheet.md` |
| then | 100 MCQs | `NN-100-mcqs.md` |
| then | 100 Interview Qs | `NN-100-interview-questions.md` |
| then | 50 Scenarios | `NN-50-scenario-questions.md` |
| then | Certification map | `NN-certification-notes.md` |
| last | Capstone | `project/` (or `projects/`) |

Subfolders (`labs/`, `docs/`) are acceptable **only** for tooling-heavy phases (CI/CD) where assets dominate. The 3.1 template is the "ideal"; the checklist above is the **pragmatic standard I recommend you actually adopt.**

---

# PHASE 4 — GAP ANALYSIS

Legend: ✅ present · ⚠️ partial/misnamed · ❌ missing

| Phase | Core Notes | Arch | Cost | Security | Labs | Trouble-shoot | Cheat-sheet | 100 MCQ | Interview | 50 Scenario | Cert Map | Project |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 1 Fundamentals | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 2 EC2 | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| S3 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Serverless | ⚠️ | ✅ | ❌* | ❌* | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ⚠️ (3/4) |
| 4 RDS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| CloudWatch | ✅ | ⚠️ | ❌ | ⚠️ | ✅ | ✅ | ❌ | ✅ | ✅ | ⚠️ | ❌ | ✅ |
| VPC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Route 53 | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Security | ✅ | ⚠️ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ⚠️ | ❌ | ❌ |
| ELB | ✅ | ✅ | ⚠️ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| CI/CD | ✅ | ✅ | ❌ | ✅ | ✅ | ⚠️ | ❌ | ❌ | ⚠️ | ⚠️ | ❌ | ⚠️ |
| Docker/ECS | ✅ | ✅ | ❌ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Advanced AWS | ✅ | ✅ | ⚠️ | ✅ | ❌ | ✅ | ❌ | ❌* | ❌* | ❌ | ❌ | ❌* |

`*` = **advertised in README but file does not exist** (broken link).

## 4.1 Missing AWS services / concepts (taught nowhere, but expected)

| Missing topic | Needed for | Suggested home |
|---|---|---|
| **DynamoDB** (deep dive) | Serverless, DVA exam | New module in Serverless |
| **Auto Scaling Groups** (dedicated) | EC2/ELB, SAA | ELB phase |
| **IAM** (dedicated early deep-dive) | Everything, all exams | New early phase |
| **Cognito** | DVA, app auth (HRMS login) | Serverless / Security |
| **KMS / Secrets Manager / Parameter Store** (deep) | DVA, SAA, security | Security phase |
| **X-Ray / distributed tracing** | DVA, DevOps | CloudWatch / Serverless |
| **EFS / FSx** | SAA storage breadth | S3/Storage phase |
| **Elastic Beanstalk / App Runner** | DVA, quick deploys | EC2 / Containers |
| **Systems Manager (SSM)** | DevOps-Pro, ops | New ops module |
| **Athena / Glue / Kinesis** | Data/analytics breadth (SAA) | Advanced AWS |
| **Transit Gateway / Direct Connect / VPN** (deep) | SAA networking | VPC / Advanced |
| **AWS Config / GuardDuty / Security Hub / Inspector** | Security Specialty, DevOps | Security phase |

---

# PHASE 5 — BEGINNER → ADVANCED FLOW (final corrected sequence)

## 5.1 Recommended sequence (16 phases) + rationale

| New # | Phase | Why here | Maps from existing |
|---|---|---|---|
| 01 | AWS Fundamentals | Bedrock concepts, account, billing | `phase-1-aws-fundamentals` |
| 02 | IAM & Security Basics | Needed by **every** later phase; least-privilege from day 1 | **split from** `phase-6-security` |
| 03 | EC2 (Compute) | First real resource; uses default VPC | `phase-2-ec2` |
| 04 | VPC & Networking | Foundation for RDS/ELB/everything private | `phase-5-vpc` |
| 05 | S3 (Storage) | Independent, easy win, used by CI/CD & static sites | `phase-3-s3` |
| 06 | RDS (Databases) | **Now** has VPC prereq satisfied | `phase-4-rds` |
| 07 | ELB + Auto Scaling | Needs EC2+VPC; introduces HA | `phase-7-elb` (+ new ASG module) |
| 08 | Route 53 (DNS) | Alias records point at ELB/CloudFront | `phase-6-route53` |
| 09 | CloudWatch & Monitoring | Most useful once fleets/LBs exist | `phase-5-cloudwatch` |
| 10 | Serverless (Lambda/API GW/+DynamoDB) | Alternative compute paradigm | `phase-3-serverless` |
| 11 | Docker | Container fundamentals | `phase-8-docker-ecs` (split) |
| 12 | ECS / Fargate / ECR | Containers on AWS | `phase-8-docker-ecs` (split) |
| 13 | CI/CD | **Now** ECS prereq satisfied | `phase-8-cicd` |
| 14 | Advanced AWS (CloudFront, ElastiCache, SQS/SNS, WAF/Shield, Org) | Breadth, edge, messaging | `phase-9-advanced-aws` (split) |
| 15 | IaC — Terraform & CloudFormation | Codify everything learned | `phase-9-advanced-aws` (split) |
| 16 | Production Architecture (HRMS capstone) + Advanced Security/DR | Tie it all together | `phase-9` arch modules + HRMS |

## 5.2 Is there a *better* sequence than the user's draft? — Yes, three refinements

1. **Move VPC to #04 (before S3/RDS), not #06.** The user's draft had S3 (04) and RDS (05) *before* VPC (06). RDS genuinely depends on VPC — keeping the original order repeats the current dependency bug.
2. **Insert "IAM & Security Basics" at #02 by *splitting* the existing security phase.** Don't teach all of security late; teach *foundations* early, *advanced* (audits, incident response, DR) at #16.
3. **Keep Docker (#11) and ECS (#12) as two explicit steps**, then CI/CD (#13). This makes the Docker→ECS→CI/CD dependency chain explicit instead of hiding it inside one `phase-8`.

## 5.3 Old → New rename map

```
phase-1-aws-fundamentals   → 01-aws-fundamentals
phase-6-security (basics)  → 02-iam-security-basics      [SPLIT]
phase-2-ec2                → 03-ec2
phase-5-vpc                → 04-vpc-networking
phase-3-s3                 → 05-s3-storage
phase-4-rds                → 06-rds-databases
phase-7-elb                → 07-elb-autoscaling
phase-6-route53            → 08-route53-dns
phase-5-cloudwatch         → 09-cloudwatch-monitoring
phase-3-serverless         → 10-serverless
phase-8-docker-ecs (docker)→ 11-docker                    [SPLIT]
phase-8-docker-ecs (ecs)   → 12-ecs-fargate               [SPLIT]
phase-8-cicd               → 13-cicd
phase-9-advanced-aws (svc) → 14-advanced-aws              [SPLIT]
phase-9-advanced-aws (iac) → 15-iac-terraform-cfn         [SPLIT]
phase-9-advanced-aws (arch)→ 16-production-architecture   [SPLIT]
phase-6-security (advanced)→ 16 (DR/sec annex)            [SPLIT]
```

---

# PHASE 6 — STANDARDIZATION

## 6.1 Naming standard
- **Folders:** `NN-kebab-case` where `NN` is a **zero-padded, unique, linear** index (`01`–`16`).
- **Files:** `NN-kebab-case.md`, numbered in the **canonical band order** (see Phase 3.2).
- **One canonical name per category** — pick and enforce:
  - troubleshooting → `NN-troubleshooting.md` (not `-guide` / `-handbook`)
  - MCQs → `NN-100-mcqs.md`
  - interview → `NN-100-interview-questions.md`
  - scenarios → `NN-50-scenario-questions.md`
  - cheatsheet → `NN-cheatsheet.md`
- **Code project:** `project/` (singular) for one capstone; `projects/NN-name/` only when ≥2.

## 6.2 Numbering standard
- No duplicate phase numbers, ever.
- No gaps inside a phase (the `07 → 10` jump in serverless is a defect).
- README's "Learning Path" table **must** list only files that exist (CI test below).

## 6.3 README standard (every phase)
Each phase README must contain, in order: **title + one-line summary → who it's for + prerequisites (linked) → learning-path table (verified links) → topics covered → 60-second mental model (ASCII) → what you'll build → conventions legend → cost note → official references → "start here" pointer.** Phases 1, 2, 7 already model this perfectly — clone their shape.

## 6.4 Learning-objectives standard
Open every phase with a **"By the end you can…"** bullet list (3–6 measurable outcomes) and a **prerequisites line** linking the prior phase. Several phases have the prereq line; few have explicit objectives.

## 6.5 Proposed automated guard (cheap, high value)
Add a tiny CI check (GitHub Action) that:
- fails if any README links to a non-existent file (would have caught serverless + phase-9),
- fails on duplicate `NN-` phase prefixes,
- warns if a phase is missing a checklist category.

---

# PHASE 7 — MISSING-CONTENT PLAN (prioritized, NOT yet generated)

> Per instructions, this is a **plan**, not generated files. Priority: **P0 = blocks navigation/trust**, **P1 = certification/completeness**, **P2 = polish**.

## 7.1 Missing FILES — by priority

**P0 — Integrity (do first, ~1 day)**
- [ ] Root `README.md` (master roadmap + prereq graph)
- [ ] Fix `phase-3-serverless/README.md` broken links (08, 09, code-examples, project 04)
- [ ] Fix `phase-9-advanced-aws/README.md` broken links (16, 17, project)
- [ ] `.gitignore`, `LICENSE`, `STANDARDS.md`, `git init`

**P1 — Certification & completeness (~1–2 weeks)**
- [ ] Serverless: `08-security-design.md`, `09-cost-optimization.md`, `12-100-mcqs.md`, `labs.md`
- [ ] Phase-9: `16-200-interview-questions.md`, `17-200-mcqs.md`, HRMS `project/`
- [ ] ELB: `06-100-mcqs.md`, `07-100-interview-questions.md`, `08-autoscaling.md`, `project/`
- [ ] Docker/ECS: `14-100-mcqs.md`, `15-100-interview-questions.md`, `16-scenarios.md`
- [ ] Route 53: `07-100-mcqs.md`, `08-cost.md`, `project/` (failover routing)
- [ ] Security: `NN-100-mcqs.md`, `NN-labs.md`, `project/`
- [ ] **New** `02-iam-security-basics/` phase (split from security)
- [ ] **New** `DynamoDB`, `Cognito`, `KMS/Secrets`, `X-Ray`, `Auto Scaling` modules
- [ ] Per-phase `NN-certification-notes.md` (SAA/DVA/CP mapping)

**P2 — Polish (~ongoing)**
- [ ] `NN-cheatsheet.md` in every phase (only Phase 1's revision-notes exists)
- [ ] Root `GLOSSARY.md`, `SERVICES-INDEX.md`
- [ ] De-duplicate SQS/SNS between serverless and phase-9 (teach once, cross-link)

## 7.2 Missing FOLDERS
`02-iam-security-basics/` · `phase-3-serverless/code-examples/` (or remove from README) · `project/` for ELB, Route 53, Security · `phase-9 project/`.

## 7.3 Missing PROJECTS
- ELB: ALB + ASG + multi-AZ self-healing web tier.
- Route 53: latency/failover routing with health checks.
- Security: IAM least-privilege + GuardDuty lab.
- Serverless: project 04 (API + Cognito + Aurora Serverless) advertised but absent.
- Phase-9: the HRMS multi-account Terraform/CFN capstone (advertised but absent).

## 7.4 Missing LABS
Serverless (no labs file) · Security (no labs file) · Docker/ECS labs are partial · Auto Scaling lab.

## 7.5 Missing INTERVIEW / TROUBLESHOOTING sections
- Interview files missing: ELB, Docker/ECS, Phase-9 (advertised), serverless-MCQ.
- Troubleshooting present in most; standardize the filename and add to Fundamentals (`12-common-mistakes` ≈ troubleshooting — rename/align).

---

# PHASE 8 — PRODUCTION / CERTIFICATION READINESS

| Certification | Readiness | Strong areas (present) | Key gaps to close |
|---|:--:|---|---|
| **AWS Cloud Practitioner (CLF-C02)** | **88%** | Fundamentals, billing, global infra, shared responsibility, EC2/S3/RDS basics, cert notes, 100 MCQs | Support plans, Trusted Advisor, Artifact, broad service name-recognition; add a CP-specific final mock |
| **Solutions Architect Associate (SAA-C03)** | **78%** | EC2, VPC, S3, RDS, ELB, Route 53, CloudWatch, serverless, CloudFront, ElastiCache, multi-region/DR, security | DynamoDB depth, EFS/FSx, Aurora depth, Kinesis/Athena/Glue, Transit Gateway/DX/VPN depth, decoupling patterns, **per-phase SAA mapping + a full 65-Q mock** |
| **Developer Associate (DVA-C02)** | **64%** | Lambda, API GW, SQS/SNS, Step Functions, CI/CD (CodeBuild/Deploy/Pipeline), event-driven patterns | **DynamoDB (critical)**, Cognito, X-Ray, KMS/encryption SDK, SAM, Elastic Beanstalk, parameter/secrets, caching strategies |
| **DevOps Engineer Professional (DOP-C02)** | **58%** | CI/CD strategies (rolling/BG/canary), IaC (TF+CFN), containers, CloudWatch, Organizations, multi-account | Systems Manager, AWS Config + conformance, advanced EventBridge automation, incident-response automation, OpsWorks/Beanstalk deploys, **Pro-level scenario depth** |
| **(Bonus) Security Specialty** | ~50% | Attack scenarios, audits, least-privilege, incident response, WAF/Shield | KMS deep, GuardDuty/Security Hub/Inspector/Detective, Macie, detective controls, data protection depth |

**Overall:** The repo is **exam-ready for Cloud Practitioner now**, **~80% for SAA** (close the service-breadth + add mocks), and needs targeted builds for **DVA (DynamoDB/Cognito/X-Ray)** and **DevOps-Pro (SSM/Config/automation)**.

---

# PHASE 9 — HRMS PROJECT ALIGNMENT

**Your stack:** React + TypeScript + Vite (frontend) · Node.js + Express + Prisma (backend) · MySQL (DB).

The repository is **already HRMS-aware** (`phase-6-security/06-hrms-security-design.md`, RDS Prisma project, Phase-9 HRMS capstone). Here is the explicit map:

| Phase | What it contributes to your HRMS | Production service(s) you'll end up using |
|---|---|---|
| 01 Fundamentals | Account, budgets, region choice for HRMS | Organizations, Budgets, Cost Explorer |
| 02 IAM/Security basics | Dev/CI roles, least-privilege for the app | IAM roles, MFA, policies |
| 03 EC2 | First deploy of Express API + Vite build (single box) | EC2, EBS, key pairs |
| 04 VPC | Private subnets for MySQL, public for LB | VPC, subnets, SGs, NAT |
| 05 S3 | Employee documents, payslip PDFs, avatars, **Vite static hosting** | S3, presigned URLs |
| 06 RDS | **Your MySQL → RDS MySQL with Prisma** (migration + connection pooling already covered) | RDS MySQL Multi-AZ, RDS Proxy |
| 07 ELB + ASG | HA for the Express API; HTTPS termination | ALB, ACM, Auto Scaling |
| 08 Route 53 | `hrms.yourdomain.com`, API/app subdomains, failover | Route 53, alias records |
| 09 CloudWatch | API latency/error alarms, log aggregation, payroll-job monitoring | CloudWatch, Logs, Alarms, SNS |
| 10 Serverless | Async jobs: payroll runs, email/notifications, report generation | Lambda, EventBridge, SQS, SNS |
| 11 Docker | Containerize React + Express + Prisma for parity | Docker, ECR |
| 12 ECS/Fargate | Run HRMS containers serverlessly, scale per service | ECS Fargate, ECR, task defs |
| 13 CI/CD | Auto-build/test/deploy on push; blue-green for zero-downtime payroll periods | GitHub Actions/CodePipeline, CodeDeploy |
| 14 Advanced AWS | CloudFront for the Vite SPA + assets; ElastiCache for sessions; SQS for payroll queue; WAF for the login page | CloudFront, ElastiCache Redis, SQS, WAF |
| 15 IaC | Reproducible HRMS infra as Terraform/CFN | Terraform, CloudFormation |
| 16 Production Architecture | The full multi-account HRMS blueprint (the capstone) | All of the above, wired together |

**Recommended HRMS production target architecture (from the repo's own capstone):**
```
Route 53 → CloudFront (Vite SPA + S3) ─┐
                                        ├→ ALB → ECS Fargate (Express+Prisma) → RDS MySQL Multi-AZ
WAF/Shield ─────────────────────────────┘            │            │
                                          ElastiCache Redis   SQS (payroll) → Lambda workers
                              CloudWatch + SNS alerts · CI/CD via CodePipeline · Terraform IaC
```

**Suggested addition:** a root `HRMS-TRACK.md` that lists, for each phase, the *exact* HRMS task to do (e.g., "Phase 06: migrate your local `hrms` MySQL schema to RDS via Prisma `migrate deploy`").

---

# FINAL — IMPROVEMENT ROADMAP

## Sprint 1 — Integrity (1–2 days) 🔴 *do these first*
1. Create root `README.md` (master roadmap, prereq graph, links).
2. Fix broken README links in serverless + phase-9 (create stubs **or** correct the tables).
3. Resolve 4 duplicate phase numbers via the rename map (§5.3).
4. `git init` + `.gitignore` + `LICENSE` + `STANDARDS.md`.
5. Add the CI link-checker + duplicate-prefix guard (§6.5).

## Sprint 2 — Reorder & standardize (3–5 days) 🟠
6. Apply the corrected 16-phase order (§5.1); split Security→(basics/advanced), Docker/ECS→(docker/ecs), Phase-9→(svc/iac/arch).
7. Backfill the **content checklist** gaps that block exams: ELB MCQ/interview/ASG, Docker/ECS MCQ/interview, Route 53 MCQ, Security MCQ/labs, serverless MCQ/labs.
8. Normalize filenames (troubleshooting/cheatsheet/cert-map) and add learning-objective headers.

## Sprint 3 — Depth & certification (1–2 weeks) 🟢
9. Build missing service modules: **DynamoDB, Auto Scaling, IAM deep-dive, Cognito, KMS/Secrets, X-Ray**.
10. Build the advertised-but-missing **HRMS capstone** (Phase-9 `project/`) and serverless project 04.
11. Add per-phase `certification-notes.md` (CP/SAA/DVA mapping) + one full mock exam per target cert.
12. Add `GLOSSARY.md`, `SERVICES-INDEX.md`, `HRMS-TRACK.md`; de-duplicate SQS/SNS.

## Final recommended repository structure (target end-state)

```
aws-mastery-roadmap/
├── README.md                     ← master roadmap (NEW, P0)
├── STANDARDS.md  GLOSSARY.md  SERVICES-INDEX.md  HRMS-TRACK.md   (NEW)
├── LICENSE  .gitignore  .github/workflows/repo-guard.yml         (NEW)
│
├── 01-aws-fundamentals/
├── 02-iam-security-basics/       ← split from old security
├── 03-ec2/
├── 04-vpc-networking/
├── 05-s3-storage/
├── 06-rds-databases/
├── 07-elb-autoscaling/
├── 08-route53-dns/
├── 09-cloudwatch-monitoring/
├── 10-serverless/                ← + DynamoDB, Cognito, X-Ray
├── 11-docker/
├── 12-ecs-fargate/
├── 13-cicd/
├── 14-advanced-aws/              ← CloudFront, ElastiCache, SQS/SNS, WAF
├── 15-iac-terraform-cfn/
└── 16-production-architecture/   ← HRMS capstone + advanced security/DR

   (every phase folder follows the §3.2 checklist:
    notes → architecture → cost → security → labs → troubleshooting →
    cheatsheet → 100-mcqs → 100-interview → 50-scenarios → cert-map → project/)
```

---

### What's genuinely good here (so you don't lose it in the rewrite)
Phases 1, 2, 4, 5-cloudwatch, 8-docker-ecs, 8-cicd, and 9 contain **real, production-grade material** — ASCII architecture, copy-paste CLI, cost math, DLQ/idempotency patterns, blue-green/canary pipelines, Terraform. The problem is **packaging and sequencing, not substance.** Fix the integrity + order issues first; the content already clears a high bar.

*Generated as a repository audit. No source learning files were modified — this report is additive.*

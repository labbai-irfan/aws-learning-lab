# Deployment Strategies — Deep Dive

> How you ship new code matters as much as the code itself. This guide compares the major strategies, when to use each, and how AWS implements them.

## Table of Contents
1. [Why strategy matters](#1-why-strategy-matters)
2. [Recreate](#2-recreate)
3. [Rolling](#3-rolling)
4. [Blue/Green](#4-bluegreen)
5. [Canary](#5-canary)
6. [Linear / ramped](#6-linear--ramped)
7. [Shadow / dark launch](#7-shadow--dark-launch)
8. [A/B testing (feature-based)](#8-ab-testing)
9. [Decision guide](#9-decision-guide)
10. [AWS service support matrix](#10-aws-service-support-matrix)

---

## 1. Why strategy matters

Every deployment is a risk: the new version might be slower, buggy, or
incompatible. A deployment strategy controls **how much blast radius** a bad
release gets and **how fast you can recover**. The three levers:

- **Downtime** — are users impacted while you deploy?
- **Blast radius** — what % of users hit the new version before you know it's good?
- **Rollback speed** — how fast can you get back to the known-good version?

---

## 2. Recreate

**How:** Stop all old instances, then start all new ones.

```
v1 v1 v1   ──►   (all down)   ──►   v2 v2 v2
```

- ❌ **Downtime** during the gap.
- ✅ Simple; only one version runs at a time (no compatibility concerns).
- **Use for:** dev/test, batch jobs, apps where a maintenance window is fine.

---

## 3. Rolling

**How:** Replace instances in **batches**. Old and new run side by side during the roll.

```
v1 v1 v1 v1  ─►  v2 v1 v1 v1  ─►  v2 v2 v1 v1  ─►  v2 v2 v2 v2
```

- ✅ **No downtime**, no extra capacity needed.
- ⚠️ Two versions live at once → **DB/API must be backward compatible**.
- ⚠️ Rollback = roll forward again (slower than a flip).
- **AWS:** ASG rolling update, ECS rolling update (`minimumHealthyPercent` /
  `maximumPercent`), CodeDeploy `OneAtATime` / `HalfAtATime` / `AllAtOnce`.

**ECS knobs:**
| Setting | Meaning |
|---------|---------|
| `minimumHealthyPercent: 100` | never drop below desired count (needs `maximumPercent > 100`) |
| `maximumPercent: 200` | can temporarily double tasks for a fast roll |

---

## 4. Blue/Green

**How:** Stand up a **complete second environment** (green) alongside the live one
(blue). Validate green, then **flip all traffic** at once. Keep blue around for
instant rollback.

```
Blue (v1) ◄── 100% traffic
Green (v2)     0% traffic   ──flip──►   Green (v2) ◄── 100% traffic
                                        Blue (v1) kept for rollback
```

- ✅ **Zero downtime**, **instant rollback** (flip back to blue).
- ✅ Full testing of green before any real traffic.
- 💲 Temporarily needs **2× capacity**.
- ⚠️ Stateful resources (DBs) are shared — schema must support both versions.
- **AWS:** CodeDeploy Blue/Green for ECS & Lambda, ALB target-group swap,
  Elastic Beanstalk swap-URLs.

➡️ Full guide: [blue-green-deployment.md](blue-green-deployment.md)

---

## 5. Canary

**How:** Route a **small slice** (e.g. 5–10%) of traffic to the new version.
Watch metrics. If healthy, **ramp to 100%**; if not, **abort** and pull the slice.

```
Stable (v1) ◄── 90%
Canary (v2) ◄── 10%   ──(metrics OK)──►   v2 ◄── 100%
                      ──(metrics bad)─►   v2 removed, back to v1
```

- ✅ **Smallest blast radius** — only a fraction of users hit a bad release.
- ✅ Real production traffic validates the release.
- ⚠️ Needs good **observability + automated metric gates** to be safe.
- ⚠️ Two versions live → backward compatibility required.
- **AWS:** CodeDeploy `Canary10Percent5Minutes` (ECS/Lambda),
  API Gateway canary release, ALB weighted target groups, Route 53 weighted records.

➡️ Full guide: [canary-deployment.md](canary-deployment.md)

---

## 6. Linear / ramped

A **canary variant**: shift traffic in equal increments on a fixed schedule.

- `LambdaLinear10PercentEvery1Minute` → +10% each minute → 100% after 10 min.
- Good middle ground: gradual exposure without a manual ramp.

---

## 7. Shadow / dark launch

Mirror real production traffic to the new version **without** returning its
responses to users. Compare behavior/performance silently.

- ✅ Zero user risk; great for testing performance under real load.
- ⚠️ Complex; beware **side effects** (don't let shadow writes hit prod DB/email).

---

## 8. A/B testing

Route traffic by **user attribute** (cookie, header, geo) rather than by
percentage, to test a *feature* hypothesis (not just safety). Often done with
feature flags (LaunchDarkly, AppConfig) rather than infra.

---

## 9. Decision guide

```
Need a maintenance window OK?           → Recreate
Stateless app, no extra cost budget?    → Rolling
Need instant rollback, can pay 2× temp? → Blue/Green
High traffic, risk-averse, good metrics?→ Canary
Want gradual auto-ramp?                 → Linear
Testing perf with zero user risk?       → Shadow
Testing a product hypothesis?           → A/B (feature flags)
```

---

## 10. AWS service support matrix

| Strategy | EC2/ASG | ECS | Lambda | Elastic Beanstalk | API Gateway |
|----------|:------:|:---:|:------:|:-----------------:|:-----------:|
| Recreate | ✅ | ✅ | ✅ | ✅ | — |
| Rolling | ✅ | ✅ | — | ✅ | — |
| Blue/Green | ✅ (CodeDeploy) | ✅ (CodeDeploy) | ✅ (alias) | ✅ (swap) | — |
| Canary | ⚠️ (weighted TG) | ✅ (CodeDeploy) | ✅ (CodeDeploy) | ⚠️ | ✅ (canary) |
| Linear | — | ✅ | ✅ | — | — |

**Key takeaway:** CodeDeploy is the AWS-native engine for Blue/Green and Canary
on ECS and Lambda; for EC2 fleets you typically combine ASG rolling updates or
CodeDeploy in-place with weighted ALB target groups.

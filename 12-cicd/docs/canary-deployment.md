# Canary Deployment — Complete Guide

> Release to a small subset of traffic first. Watch the metrics. Ramp up if healthy; abort if not. Named after the "canary in a coal mine."

## Table of Contents
1. [Concept](#1-concept)
2. [Canary vs Blue/Green](#2-canary-vs-bluegreen)
3. [CodeDeploy canary configs](#3-codedeploy-canary-configs)
4. [Canary on ECS](#4-canary-on-ecs)
5. [Canary on Lambda](#5-canary-on-lambda)
6. [Canary with ALB weighted target groups](#6-canary-with-alb-weighted-target-groups)
7. [Metric gates & automated rollback](#7-metric-gates--automated-rollback)
8. [Pros, cons & pitfalls](#8-pros-cons--pitfalls)
9. [Checklist](#9-checklist)

---

## 1. Concept

Instead of switching everyone at once, send a **small percentage** of live
traffic to the new version (the *canary*). Monitor error rate, latency, and
business metrics. If they stay within bounds, **increase the percentage** until
100%. If anything degrades, **route traffic back** to the stable version.

```
t=0   v1: 100%   v2:   0%   (deploy canary)
t=1   v1:  90%   v2:  10%   (watch metrics 5 min)
t=2   v1:   0%   v2: 100%   (promote)        ── or ──   abort → v1: 100%
```

**Analogy:** Before opening a new bridge to all traffic, you let a few cars
across and watch it hold. Only then do you open all lanes.

---

## 2. Canary vs Blue/Green

| | Blue/Green | Canary |
|--|-----------|--------|
| Traffic switch | 100% at once (flip) | Gradual % ramp |
| Blast radius | All users instantly | Small slice first |
| Extra capacity | Full 2× environment | Just the canary fleet |
| Rollback | Flip back to blue | Stop shift / pull canary |
| Needs | Test before cutover | Strong live metric gates |
| Best when | Need instant total rollback | Need minimal exposure to bad code |

They combine well: **Blue/Green infra + canary traffic shifting** = CodeDeploy's
`ECSCanary10Percent5Minutes`.

---

## 3. CodeDeploy canary configs

Predefined deployment configs (you can also create custom ones):

| Config | Behavior |
|--------|----------|
| `Canary10Percent5Minutes` | 10% for 5 min, then 100% |
| `Canary10Percent15Minutes` | 10% for 15 min, then 100% |
| `Linear10PercentEvery1Minute` | +10% each minute |
| `Linear10PercentEvery3Minutes` | +10% every 3 min |
| `AllAtOnce` | 100% immediately (no canary) |

Prefix is `CodeDeployDefault.ECS*` for ECS and `CodeDeployDefault.Lambda*` for Lambda.

---

## 4. Canary on ECS

Use the Blue/Green setup (two target groups + listener) but pick a **canary
deployment config**:

```bash
aws deploy update-deployment-group \
  --application-name my-app \
  --current-deployment-group-name my-app-bg \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes
```

CodeDeploy registers green, sends 10% via the prod listener (weighted), waits 5
minutes (running `AfterAllowTraffic` hooks / watching alarms), then shifts the
remaining 90%.

---

## 5. Canary on Lambda

The cleanest canary in AWS — alias weighted routing is built in.

```bash
# Manually: 10% to v2, 90% to v1
aws lambda update-alias \
  --function-name my-api --name live \
  --function-version 2 \
  --routing-config '{"AdditionalVersionWeights": {"1": 0.9}}'
```

With CodeDeploy + `LambdaCanary10Percent5Minutes`, this ramp is automated, and
the pre/post-traffic hooks gate it. See
[../aws/canary/canary-lambda-pipeline.yml](../aws/canary/canary-lambda-pipeline.yml)
and [../aws/canary/pre-traffic-hook.js](../aws/canary/pre-traffic-hook.js).

---

## 6. Canary with ALB weighted target groups

For plain EC2/ECS without CodeDeploy, do it yourself with **weighted forward**:

```bash
aws elbv2 modify-listener --listener-arn "$LISTENER" \
  --default-actions '[{
    "Type":"forward",
    "ForwardConfig":{"TargetGroups":[
      {"TargetGroupArn":"'"$TG_V1"'","Weight":90},
      {"TargetGroupArn":"'"$TG_V2"'","Weight":10}
    ]}
  }]'
```

Increase the v2 weight over time. (Route 53 weighted records do the same at DNS
level, but DNS TTL caching makes traffic shifting slower and less precise.)

---

## 7. Metric gates & automated rollback

Canary is only safe if **bad metrics automatically abort it.** Wire CloudWatch
alarms into the CodeDeploy deployment group:

```bash
aws deploy update-deployment-group \
  --application-name my-app \
  --current-deployment-group-name my-app-bg \
  --alarm-configuration enabled=true,alarms=[{name=High5xxRate},{name=HighLatencyP99}] \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM
```

Good canary signals:
- **5xx error rate** (ALB `HTTPCode_Target_5XX_Count`)
- **p99 latency** (`TargetResponseTime`)
- **Lambda errors / throttles**
- **Business KPI** (checkout success, signups) via custom metrics

For richer analysis, **CloudWatch Synthetics canaries** continuously probe
endpoints and feed alarms.

---

## 8. Pros, cons & pitfalls

| ✅ Pros | ⚠️ Cons / Pitfalls |
|--------|---------------------|
| Smallest blast radius | Needs solid observability to be safe |
| Real prod traffic validates | Two versions live → compat required |
| Gradual confidence | Low-traffic apps: 10% may be too few requests to judge |
| Auto-rollback on alarm | Sticky sessions can skew which users hit canary |

**Pitfall:** if traffic is low, a 10% canary might see almost no requests in 5
minutes — your metrics are statistically meaningless. Either lengthen the bake
time or use synthetic traffic.

---

## 9. Checklist

- [ ] Stable + canary versions both deployable behind a weighted router
- [ ] CloudWatch alarms defined for error rate **and** latency
- [ ] Alarms attached to the CodeDeploy deployment group
- [ ] Auto-rollback enabled on `DEPLOYMENT_STOP_ON_ALARM`
- [ ] Bake time long enough to gather meaningful metrics
- [ ] DB/API backward compatible across versions
- [ ] Pre/post-traffic validation hooks return correct status
- [ ] Dashboards ready to eyeball during the ramp

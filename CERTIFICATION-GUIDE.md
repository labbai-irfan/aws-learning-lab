# AWS Certification Study Guide

> Maps each exam's **official domains** to the exact phases/files in this repo, with a readiness estimate and the gaps to close. Use it to build a focused study plan instead of reading everything.

| Exam | Code | This repo's readiness | Best for |
|---|---|---|---|
| Cloud Practitioner | CLF-C02 | **~88%** | Beginners, breadth, non-engineers |
| Solutions Architect Associate | SAA-C03 | **~80%** | Designing AWS systems |
| Developer Associate | DVA-C02 | **~78%** | Building apps on AWS |
| DevOps Engineer Professional | DOP-C02 | **~62%** | CI/CD, IaC, ops at scale |

Legend: ✅ well covered · 🟡 partial · ❌ gap to fill.

---

## 1. AWS Certified Cloud Practitioner (CLF-C02)

| Domain (weight) | Covered by | Status |
|---|---|---|
| **Cloud Concepts (24%)** | [01 Fundamentals](01-aws-fundamentals/01-beginner-notes.md) — cloud models, AWS value, Well-Architected | ✅ |
| **Security & Compliance (30%)** | [02 IAM/Security](02-iam-security/README.md), [01 shared responsibility](01-aws-fundamentals/01-beginner-notes.md) | ✅ |
| **Cloud Technology & Services (34%)** | [03 EC2](03-ec2/README.md), [05 S3](05-s3/README.md), [06 RDS](06-rds/README.md), [04 VPC](04-vpc-networking/README.md), [09 CloudWatch](09-cloudwatch/README.md) | ✅ |
| **Billing, Pricing & Support (12%)** | [01 Billing guide](01-aws-fundamentals/06-billing-guide.md) | 🟡 (add Support Plans, Trusted Advisor, Artifact) |

**Study path:** Phase 01 in full → skim 02/03/05/06 cores → [01 MCQs](01-aws-fundamentals/07-100-mcqs.md) + [cert notes](01-aws-fundamentals/11-certification-notes.md).
**Gaps to close:** AWS Support plans, Trusted Advisor, Health Dashboard, Artifact, more service name-recognition breadth. **Verdict: exam-ready with a short top-up.**

---

## 2. AWS Certified Solutions Architect – Associate (SAA-C03)

| Domain (weight) | Covered by | Status |
|---|---|---|
| **Design Secure Architectures (30%)** | [02 IAM/Security](02-iam-security/README.md), [04 VPC security](04-vpc-networking/04-security-guide.md), [05 S3 security](05-s3/04-security-guide.md), [13 WAF/Shield](13-advanced-aws/06-waf-shield.md) | ✅ |
| **Design Resilient Architectures (26%)** | [07 ELB+ASG](07-elb-autoscaling/02-architectures.md), [06 RDS Multi-AZ/replicas](06-rds/03-production-architecture.md), [08 Route 53 failover](08-route53/02-architectures.md), [13 multi-Region/DR](13-advanced-aws/09-multi-region-dr.md) | ✅ |
| **Design High-Performing Architectures (24%)** | [13 CloudFront](13-advanced-aws/01-cloudfront.md)/[ElastiCache](13-advanced-aws/02-elasticache-redis.md), [10 Serverless](10-serverless/README.md)/[DynamoDB](10-serverless/08-dynamodb.md), [07 Auto Scaling](07-elb-autoscaling/06-auto-scaling.md) | ✅ |
| **Design Cost-Optimized Architectures (20%)** | [03 EC2 cost](03-ec2/04-cost-calculation.md), [05 S3 classes](05-s3/03-cost-optimization.md), [06 RDS cost](06-rds/07-scaling-and-cost-optimization.md) | ✅ |

**Study path:** Phases 03→13 in order, focusing on each phase's **architectures** + **cheat sheet** + MCQs.
**Gaps to close:** breadth services — **EFS/FSx**, **Kinesis/Athena/Glue**, **Storage Gateway/DataSync**, deeper **Transit Gateway/Direct Connect**, **Aurora/DynamoDB** depth. Then a full 65-question timed mock. **Verdict: ~80%, close breadth + drill mocks.**

---

## 3. AWS Certified Developer – Associate (DVA-C02)

| Domain (weight) | Covered by | Status |
|---|---|---|
| **Development with AWS Services (32%)** | [10 Lambda](10-serverless/01-lambda-core-concepts.md)/[API GW](10-serverless/02-api-gateway.md)/[DynamoDB](10-serverless/08-dynamodb.md)/[SQS/SNS/EventBridge/Step Functions](10-serverless/README.md) | ✅ |
| **Security (26%)** | [10 Cognito](10-serverless/09-cognito.md), [02 IAM/KMS/Secrets](02-iam-security/README.md) | ✅ |
| **Deployment (24%)** | [12 CI/CD](12-cicd/README.md) (CodeBuild/Deploy/Pipeline, SAM-style), [11 ECR/ECS](11-docker-ecs/README.md) | 🟡 (add SAM + Elastic Beanstalk specifics) |
| **Troubleshooting & Optimization (18%)** | [09 X-Ray](09-cloudwatch/16-x-ray.md)/[CloudWatch](09-cloudwatch/README.md), [10 troubleshooting](10-serverless/11-troubleshooting.md) | ✅ |

**Study path:** Phase 10 in full (incl. DynamoDB + Cognito) → Phase 12 → [09 X-Ray](09-cloudwatch/16-x-ray.md) → [02 KMS/Secrets](02-iam-security/12-cheatsheet.md).
**Gaps to close:** **SAM**, **Elastic Beanstalk**, deeper encryption-SDK/KMS for developers, API Gateway caching/throttling specifics. **Verdict: ~78% — DynamoDB/Cognito/X-Ray now covered; add SAM + Beanstalk.**

---

## 4. AWS Certified DevOps Engineer – Professional (DOP-C02)

| Domain (weight) | Covered by | Status |
|---|---|---|
| **SDLC Automation (22%)** | [12 CI/CD](12-cicd/README.md) (pipelines, blue/green, canary) | ✅ |
| **Configuration Mgmt & IaC (17%)** | [13 Terraform](13-advanced-aws/04-terraform.md)/[CloudFormation](13-advanced-aws/05-cloudformation.md), [09 Systems Manager](09-cloudwatch/17-systems-manager.md) | ✅ |
| **Resilient Cloud Solutions (15%)** | [07 ASG](07-elb-autoscaling/06-auto-scaling.md), [13 multi-Region/DR](13-advanced-aws/09-multi-region-dr.md) | ✅ |
| **Monitoring & Logging (15%)** | [09 CloudWatch + X-Ray](09-cloudwatch/README.md) | ✅ |
| **Incident & Event Response (14%)** | [02 incident response](02-iam-security/08-incident-response-examples.md), [09 EventBridge/alarms](09-cloudwatch/06-events.md) | 🟡 |
| **Security & Compliance (17%)** | [02 IAM/GuardDuty/Config/Security Hub](02-iam-security/README.md) | ✅ |

**Study path:** Phases 11→12→13 + 09 + 02, emphasizing automation and IaC.
**Gaps to close (Pro-level depth):** **AWS Config** conformance packs + auto-remediation, advanced **EventBridge** automation, **CodeDeploy** deep config, OpsWorks/Beanstalk deploys. (**Systems Manager** is now covered — [09/17](09-cloudwatch/17-systems-manager.md).) **Verdict: ~62% — strong CI/CD + IaC + SSM base; needs Config automation depth.**

---

## Cross-exam gap backlog (build these to raise scores)
1. **DynamoDB** ✅ done · **Cognito** ✅ done · **X-Ray** ✅ done · **Auto Scaling** ✅ done.
2. **Systems Manager (SSM)** ✅ done — [09/17](09-cloudwatch/17-systems-manager.md).
3. **EFS/FSx, Kinesis/Athena/Glue, Storage Gateway/DataSync** — SAA breadth. ❌
4. **SAM + Elastic Beanstalk** — DVA deployment. ❌
5. **AWS Config conformance + auto-remediation** — DevOps Pro. ❌
6. One **full timed mock** per target cert. ❌

---

## How to use this guide
1. Pick a target exam and read only the rows above.
2. Follow each domain's links; do that phase's **notes → labs → cheat sheet → MCQs/interview**.
3. Close the listed gaps (external study where the repo is 🟡/❌).
4. Take a full timed practice exam; review weak domains.

*Official exam guides:* [CLF-C02](https://aws.amazon.com/certification/certified-cloud-practitioner/) · [SAA-C03](https://aws.amazon.com/certification/certified-solutions-architect-associate/) · [DVA-C02](https://aws.amazon.com/certification/certified-developer-associate/) · [DOP-C02](https://aws.amazon.com/certification/certified-devops-engineer-professional/)

*See also: [README.md](README.md) · [SERVICES-INDEX.md](SERVICES-INDEX.md) · [REPOSITORY-AUDIT-AND-ROADMAP.md](REPOSITORY-AUDIT-AND-ROADMAP.md).*

# SAM & Elastic Beanstalk — Managed Deployment Options

> Two AWS "easy button" deployment tools the **Developer Associate** exam expects: **AWS SAM** (serverless IaC) and **Elastic Beanstalk** (PaaS for web apps). Know what each is and when to reach for it versus raw CloudFormation/ECS.

---

## 1. AWS SAM (Serverless Application Model)
A **CloudFormation extension** with shorthand for serverless resources — far less YAML than raw CFN.

```yaml
# template.yaml — a whole API + function + table in ~15 lines
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Resources:
  Api:
    Type: AWS::Serverless::Function          # Lambda + event sources
    Properties:
      Handler: index.handler
      Runtime: nodejs20.x
      Events:
        Get: { Type: HttpApi, Properties: { Path: /employees, Method: get } }
      Policies: [ DynamoDBCrudPolicy: { TableName: !Ref Table } ]   # scoped IAM
  Table:
    Type: AWS::Serverless::SimpleTable
```

**Workflow:**
```bash
sam build            # package code + deps
sam local invoke     # test the function locally (Docker)
sam local start-api  # run the API locally
sam deploy --guided  # deploy via CloudFormation
```
- `AWS::Serverless::Function|Api|SimpleTable|StateMachine` expand into full CloudFormation.
- Built-in **IAM policy templates** (e.g., `DynamoDBCrudPolicy`) keep roles least-privilege.
- **SAM Accelerate / `sam sync`** for fast iterative deploys; integrates with CodePipeline/CodeBuild.
- 💡 Exam: "fastest way to define + locally test + deploy a serverless app as IaC" → **SAM**. (CDK is the code-based alternative.)

---

## 2. AWS Elastic Beanstalk (PaaS)
Upload your code; Beanstalk provisions and manages the **EC2, ALB, Auto Scaling, and health** for you. You keep control of the resources (unlike fully-serverless).

- **Platforms:** Node.js, Python, Java, .NET, PHP, Go, Ruby, Docker.
- **Environment** = the running app + its AWS resources (web tier or worker tier).
- **`.ebextensions/`** = config files to customize the environment (packages, env vars, options).
- **Deployment policies:** All-at-once, **Rolling**, Rolling with additional batch, **Immutable**, Blue/Green (via environment swap / CNAME swap).
- Free service — you pay only for the underlying resources.
- 💡 Exam: "deploy a web app without managing the infrastructure, but still want EC2/ALB under the hood" → **Elastic Beanstalk**.

---

## 3. When to use what
```
Serverless app (Lambda/API/DynamoDB), IaC + local test   → SAM
Traditional web app, hands-off infra, keep EC2/ALB        → Elastic Beanstalk
Containers, fine-grained control                          → ECS/Fargate (Phase 11)
Full custom infra, multi-service, any cloud               → CloudFormation / Terraform (Phase 13)
Single container, simplest web deploy                     → App Runner
```

## 4. Exam triggers 💡
- "Define + `local invoke` + deploy a Lambda/API as code" → **SAM**.
- "Deploy a Django/Node app, AWS manages capacity + health, minimal config" → **Elastic Beanstalk**.
- "Blue/green for Beanstalk" → **swap environment URLs (CNAME swap)**.
- "Least-privilege Lambda IAM with minimal YAML" → **SAM policy templates**.

## 5. Gotchas ⚠️
- SAM **is** CloudFormation under the hood — drift/stack rules apply.
- Beanstalk gives convenience but **less control**; for complex infra prefer CloudFormation/Terraform or ECS.
- `.ebextensions` ordering and option settings are a common source of failed deploys.

---
*Back to [CI/CD README](../README.md) · [deployment strategies](deployment-strategies.md) · [cheat sheet](cheatsheet.md). Related: [Phase 10 Serverless](../../10-serverless/README.md), [Phase 13 IaC](../../13-advanced-aws/05-cloudformation.md).*

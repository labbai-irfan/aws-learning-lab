# AWS Services Index — "Where is service X taught?"

> Look up any AWS service and jump straight to the phase that covers it. Services taught in more than one place list the **primary** phase first.

Phases: [01 Fundamentals](01-aws-fundamentals/) · [02 IAM/Security](02-iam-security/) · [03 EC2](03-ec2/) · [04 VPC](04-vpc-networking/) · [05 S3](05-s3/) · [06 RDS](06-rds/) · [07 ELB/ASG](07-elb-autoscaling/) · [08 Route 53](08-route53/) · [09 CloudWatch](09-cloudwatch/) · [10 Serverless](10-serverless/) · [11 Docker/ECS](11-docker-ecs/) · [12 CI/CD](12-cicd/) · [13 Advanced](13-advanced-aws/)

---

## Compute
| Service | Primary phase | Key file |
|---|---|---|
| **EC2** | [03 EC2](03-ec2/README.md) | [01-ec2-core-concepts.md](03-ec2/01-ec2-core-concepts.md) |
| **EC2 Auto Scaling (ASG)** | [07 ELB/ASG](07-elb-autoscaling/README.md) | [06-auto-scaling.md](07-elb-autoscaling/06-auto-scaling.md) |
| **Lambda** | [10 Serverless](10-serverless/README.md) | [01-lambda-core-concepts.md](10-serverless/01-lambda-core-concepts.md) |
| **ECS / Fargate** | [11 Docker/ECS](11-docker-ecs/README.md) | [07-ecs.md](11-docker-ecs/07-ecs.md), [08-fargate.md](11-docker-ecs/08-fargate.md) |
| **App Runner** (overview) | [10 Serverless](10-serverless/README.md) | [09-cognito.md](10-serverless/09-cognito.md) context |

## Networking & Content Delivery
| Service | Primary phase | Key file |
|---|---|---|
| **VPC, subnets, route tables** | [04 VPC](04-vpc-networking/README.md) | [01-vpc-core-concepts.md](04-vpc-networking/01-vpc-core-concepts.md) |
| **NAT Gateway / IGW / endpoints** | [04 VPC](04-vpc-networking/README.md) | [10-cheatsheet.md](04-vpc-networking/10-cheatsheet.md) |
| **Transit Gateway / Direct Connect / VPN / PrivateLink** | [04 VPC](04-vpc-networking/README.md) · [13 Advanced](13-advanced-aws/README.md) | [10-cheatsheet.md](04-vpc-networking/10-cheatsheet.md) |
| **ELB (ALB / NLB / GWLB)** | [07 ELB/ASG](07-elb-autoscaling/README.md) | [01-elb-core-concepts.md](07-elb-autoscaling/01-elb-core-concepts.md) |
| **Route 53 (DNS)** | [08 Route 53](08-route53/README.md) | [01-route53-core-concepts.md](08-route53/01-route53-core-concepts.md) |
| **CloudFront (CDN)** | [13 Advanced](13-advanced-aws/README.md) | [01-cloudfront.md](13-advanced-aws/01-cloudfront.md) |
| **API Gateway** | [10 Serverless](10-serverless/README.md) | [02-api-gateway.md](10-serverless/02-api-gateway.md) |

## Storage
| Service | Primary phase | Key file |
|---|---|---|
| **S3** | [05 S3](05-s3/README.md) | [01-s3-core-concepts.md](05-s3/01-s3-core-concepts.md) |
| **S3 Glacier / lifecycle** | [05 S3](05-s3/README.md) | [03-cost-optimization.md](05-s3/03-cost-optimization.md) |
| **EBS** | [03 EC2](03-ec2/README.md) | [01-ec2-core-concepts.md](03-ec2/01-ec2-core-concepts.md) |

## Databases
| Service | Primary phase | Key file |
|---|---|---|
| **RDS (MySQL/Postgres/etc.)** | [06 RDS](06-rds/README.md) | [01-rds-core-concepts.md](06-rds/01-rds-core-concepts.md) |
| **Aurora / Aurora Serverless** | [06 RDS](06-rds/README.md) | [07-scaling-and-cost-optimization.md](06-rds/07-scaling-and-cost-optimization.md) |
| **DynamoDB** | [10 Serverless](10-serverless/README.md) | [08-dynamodb.md](10-serverless/08-dynamodb.md) |
| **ElastiCache (Redis/Memcached)** | [13 Advanced](13-advanced-aws/README.md) | [02-elasticache-redis.md](13-advanced-aws/02-elasticache-redis.md) |
| **RDS Proxy** | [06 RDS](06-rds/README.md) | [05-prisma-and-connection-pooling.md](06-rds/05-prisma-and-connection-pooling.md) |

## Security, Identity & Compliance
| Service | Primary phase | Key file |
|---|---|---|
| **IAM** (users/roles/policies/STS) | [02 IAM/Security](02-iam-security/README.md) | [01-security-core-concepts.md](02-iam-security/01-security-core-concepts.md) |
| **KMS** | [02 IAM/Security](02-iam-security/README.md) | [12-cheatsheet.md](02-iam-security/12-cheatsheet.md) |
| **Secrets Manager / SSM Parameter Store** | [02 IAM/Security](02-iam-security/README.md) | [11-labs.md](02-iam-security/11-labs.md) |
| **Cognito** | [10 Serverless](10-serverless/README.md) | [09-cognito.md](10-serverless/09-cognito.md) |
| **WAF & Shield** | [13 Advanced](13-advanced-aws/README.md) | [06-waf-shield.md](13-advanced-aws/06-waf-shield.md) |
| **GuardDuty / Config / Security Hub / Inspector / Macie** | [02 IAM/Security](02-iam-security/README.md) | [03-security-audits.md](02-iam-security/03-security-audits.md) |
| **IAM Access Analyzer** | [02 IAM/Security](02-iam-security/README.md) | [11-labs.md](02-iam-security/11-labs.md) |

## Application Integration (Messaging)
| Service | Primary phase | Key file |
|---|---|---|
| **SQS** | [10 Serverless](10-serverless/README.md) | [04-sqs-integration.md](10-serverless/04-sqs-integration.md) |
| **SNS** | [10 Serverless](10-serverless/README.md) | [05-sns-integration.md](10-serverless/05-sns-integration.md) |
| **EventBridge** | [10 Serverless](10-serverless/README.md) | [03-eventbridge.md](10-serverless/03-eventbridge.md) |
| **Step Functions** | [10 Serverless](10-serverless/README.md) | [06-step-functions.md](10-serverless/06-step-functions.md) |

## Management & Monitoring
| Service | Primary phase | Key file |
|---|---|---|
| **CloudWatch** (metrics/logs/alarms) | [09 CloudWatch](09-cloudwatch/README.md) | [01-cloudwatch-core-concepts.md](09-cloudwatch/01-cloudwatch-core-concepts.md) |
| **X-Ray** (tracing) | [09 CloudWatch](09-cloudwatch/README.md) | [16-x-ray.md](09-cloudwatch/16-x-ray.md) |
| **CloudTrail** (audit) | [02 IAM/Security](02-iam-security/README.md) | [03-security-audits.md](02-iam-security/03-security-audits.md) |
| **Organizations / SCP / Control Tower** | [13 Advanced](13-advanced-aws/README.md) | [07-organizations-multi-account.md](13-advanced-aws/07-organizations-multi-account.md) |
| **Budgets / Cost Explorer** | [01 Fundamentals](01-aws-fundamentals/README.md) | [06-billing-guide.md](01-aws-fundamentals/06-billing-guide.md) |

## Containers
| Service | Primary phase | Key file |
|---|---|---|
| **Docker** | [11 Docker/ECS](11-docker-ecs/README.md) | [01-docker-fundamentals.md](11-docker-ecs/01-docker-fundamentals.md) |
| **ECR** | [11 Docker/ECS](11-docker-ecs/README.md) | [09-ecr.md](11-docker-ecs/09-ecr.md) |
| **ECS / Fargate / task definitions** | [11 Docker/ECS](11-docker-ecs/README.md) | [07-ecs.md](11-docker-ecs/07-ecs.md) |

## Developer Tools / IaC
| Service | Primary phase | Key file |
|---|---|---|
| **CodePipeline / CodeBuild / CodeDeploy** | [12 CI/CD](12-cicd/README.md) | [docs/deployment-strategies.md](12-cicd/docs/deployment-strategies.md) |
| **GitHub Actions** | [12 CI/CD](12-cicd/README.md) | [labs/lab-01-github-actions.md](12-cicd/labs/lab-01-github-actions.md) |
| **Terraform** | [13 Advanced](13-advanced-aws/README.md) | [04-terraform.md](13-advanced-aws/04-terraform.md) |
| **CloudFormation / CDK** | [13 Advanced](13-advanced-aws/README.md) | [05-cloudformation.md](13-advanced-aws/05-cloudformation.md) |

## Architecture & DR (cross-cutting)
| Topic | Primary phase | Key file |
|---|---|---|
| **Multi-Region / DR (RTO/RPO)** | [13 Advanced](13-advanced-aws/README.md) | [09-multi-region-dr.md](13-advanced-aws/09-multi-region-dr.md) |
| **Enterprise / SaaS / scalability patterns** | [13 Advanced](13-advanced-aws/README.md) | [08-enterprise-architecture.md](13-advanced-aws/08-enterprise-architecture.md) |
| **Well-Architected Framework** | [01 Fundamentals](01-aws-fundamentals/README.md) | [README.md](01-aws-fundamentals/README.md) |

---
*See also: [GLOSSARY.md](GLOSSARY.md) · [README.md](README.md) (master roadmap) · [STANDARDS.md](STANDARDS.md).*

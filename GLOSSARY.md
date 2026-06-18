# AWS Glossary — Key Terms

> Concise definitions of the terms used across this repository. For *where* a service is taught, see [SERVICES-INDEX.md](SERVICES-INDEX.md).

## A
- **AMI (Amazon Machine Image)** — template (OS + software) an EC2 instance boots from.
- **Alias record** — Route 53 record pointing to an AWS resource; works at the zone apex (unlike CNAME) and is free for AWS targets.
- **Auto Scaling Group (ASG)** — maintains a desired number of healthy EC2 instances across AZs; self-heals and scales. ([07](07-elb-autoscaling/06-auto-scaling.md))
- **Availability Zone (AZ)** — one or more isolated data centers within a Region.
- **Aurora** — AWS's MySQL/PostgreSQL-compatible managed engine; auto-scaling storage, Global Database.

## B–C
- **Bucket** — globally-unique S3 container for objects, in one Region.
- **CIDR** — IP range notation (e.g. `10.0.0.0/16`); smaller number = bigger network.
- **CloudFront** — global CDN that caches content at edge locations.
- **CloudTrail** — records AWS API calls (audit: *who did what*).
- **CloudWatch** — metrics, logs, alarms, dashboards (operational: *is it healthy*).
- **CNAME** — DNS record mapping a name to another name; **not** allowed at the apex.
- **Cold start** — latency when Lambda initializes a new execution environment.
- **Cognito** — managed auth: User Pools (authN → JWTs) + Identity Pools (authZ → AWS creds). ([10](10-serverless/09-cognito.md))

## D–E
- **DLQ (Dead Letter Queue)** — captures messages/events that failed processing.
- **DynamoDB** — serverless NoSQL key-value/document DB; single-digit-ms latency. ([10](10-serverless/08-dynamodb.md))
- **EBS** — network-attached block storage for EC2 (persists separately from the instance).
- **EC2** — virtual servers in the cloud. ([03](03-ec2/README.md))
- **ECR / ECS / Fargate** — container registry / orchestrator / serverless container runtime. ([11](11-docker-ecs/README.md))
- **Elastic IP** — static public IPv4 you own.
- **ENI** — virtual network interface attached to an instance/task.
- **EventBridge** — event bus that routes events to targets by rules; supports schedules.

## F–I
- **Fan-out** — one message to many consumers (SNS → multiple SQS/Lambda).
- **GSI / LSI** — DynamoDB Global / Local Secondary Index (alternate query keys).
- **Health check** — periodic probe; unhealthy targets stop receiving traffic.
- **IAM** — Identity and Access Management: users, groups, roles, policies. ([02](02-iam-security/README.md))
- **IaC** — Infrastructure as Code (Terraform, CloudFormation/CDK).
- **Idempotency** — safe to process the same request/event more than once.
- **IGW (Internet Gateway)** — a VPC's door to the internet.
- **Instance profile** — wraps an IAM role so an EC2 instance gets AWS credentials without static keys.

## K–N
- **KMS** — Key Management Service for encryption keys; envelope encryption.
- **Lambda** — serverless functions; pay per ms, up to 15 min. ([10](10-serverless/README.md))
- **Launch Template** — versioned blueprint for new EC2 instances (used by ASG).
- **Least privilege** — grant only the permissions actually needed.
- **Multi-AZ** — synchronous standby in another AZ for **availability/failover** (RDS).
- **NACL** — stateless subnet-level firewall (allow + deny). Contrast **Security Group** (stateful, instance-level).
- **NAT Gateway** — lets private subnets reach the internet outbound only.
- **NLB / ALB / GWLB** — Layer 4 / Layer 7 / Layer 3 load balancers. ([07](07-elb-autoscaling/README.md))

## O–R
- **OAC (Origin Access Control)** — restricts an S3 origin to CloudFront only.
- **OIDC (in CI/CD)** — lets GitHub Actions assume an IAM role with no long-lived AWS keys.
- **Pre-signed URL** — time-limited URL granting temporary access to a private S3 object.
- **RCU / WCU** — DynamoDB read/write capacity units.
- **Read Replica** — asynchronous DB copy for **read scaling** (RDS/Aurora).
- **Region** — geographic area containing multiple AZs.
- **Role (IAM)** — identity providing **temporary** credentials to trusted principals.
- **Route 53** — global DNS service + registrar + health checks. ([08](08-route53/README.md))
- **RTO / RPO** — Recovery Time / Point Objective (downtime / data-loss tolerance for DR).

## S–Z
- **SCP (Service Control Policy)** — Organizations guardrail capping permissions for an OU/account (doesn't grant).
- **Security Group** — stateful, instance-level firewall (allow-only).
- **Secrets Manager** — stores and auto-rotates credentials/API keys.
- **Shared Responsibility Model** — AWS secures *the cloud*; you secure what you put *in* it.
- **SNS / SQS** — pub/sub fan-out / message queue (decoupling). ([10](10-serverless/README.md))
- **STS** — Security Token Service; issues temporary credentials (AssumeRole, federation).
- **Step Functions** — serverless workflow orchestration (Standard vs Express).
- **Sticky sessions** — pin a client to one target (ALB cookie / NLB flow).
- **TTL** — time-to-live: DNS cache duration (Route 53) or item expiry (DynamoDB).
- **VPC** — your isolated virtual network in AWS. ([04](04-vpc-networking/README.md))
- **VPC Endpoint** — private connectivity to AWS services without traversing the internet.
- **WAF / Shield** — Layer-7 web firewall / DDoS protection.
- **Well-Architected Framework** — AWS's 6 pillars: operational excellence, security, reliability, performance efficiency, cost optimization, sustainability.
- **X-Ray** — distributed tracing across services. ([09](09-cloudwatch/16-x-ray.md))

---
*See also: [SERVICES-INDEX.md](SERVICES-INDEX.md) · [README.md](README.md) (master roadmap).*

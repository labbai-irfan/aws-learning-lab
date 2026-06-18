# Module 15 — 100 Docker & ECS Interview Questions (with Model Answers)

> Spoken-style answers grouped by topic. Concise, confident, technically correct.

---

## Docker fundamentals (1–22)
**1. What is a container?** An isolated process that packages an app with its dependencies and shares the host OS kernel — lightweight and portable, unlike a full VM.

**2. Container vs VM?** VMs virtualize hardware and run a full guest OS each; containers virtualize the OS and share the host kernel, so they start in milliseconds and use far less memory.

**3. What is a Docker image?** A read-only, layered template containing the app and its filesystem; containers are running instances of an image.

**4. What is a Dockerfile?** A text file of instructions (FROM, RUN, COPY, CMD…) that Docker uses to build an image reproducibly.

**5. What are image layers?** Each instruction creates a cached, immutable layer; layers are shared across images, which saves space and speeds builds.

**6. CMD vs ENTRYPOINT?** ENTRYPOINT defines the executable that always runs; CMD supplies default arguments (or the command if no ENTRYPOINT). Together they form the container's start command.

**7. What does EXPOSE do?** Documents the port the container listens on — it does not publish it. Use `-p host:container` to actually publish.

**8. What is a multi-stage build?** Using multiple FROM stages so build tools live in an early stage and only the slim runtime artifact is copied into the final image — much smaller, more secure images.

**9. Why use Alpine/distroless base images?** Smaller attack surface, faster pulls, fewer CVEs.

**10. What is `.dockerignore`?** Excludes files (node_modules, .git, secrets) from the build context so they aren't copied into the image.

**11. Why pin image tags?** `node:latest` changes over time; pinning (`node:20.11`) makes builds reproducible and deploys predictable.

**12. How do you keep a container's data?** Use a volume (Docker-managed) or bind mount (host path); the container's writable layer is ephemeral.

**13. Named volume vs bind mount?** Named volumes are managed by Docker and portable; bind mounts map a specific host path (great for local dev).

**14. How do containers talk on a user-defined bridge network?** By container/service name via Docker's built-in DNS.

**15. What is host network mode?** The container shares the host's network stack directly — no port mapping, lower overhead, less isolation.

**16. What is Docker Compose?** A tool to define and run multi-container apps from a YAML file, wiring services, networks, and volumes together.

**17. What does `depends_on` guarantee?** Start order, not readiness — use health checks/retry logic for actual readiness.

**18. How do you handle secrets in Docker?** Inject at runtime via env vars or secrets stores; never bake secrets into image layers.

**19. How do you reduce image size?** Multi-stage builds, slim base images, combine RUN layers, `.dockerignore`, and remove caches.

**20. What is layer caching and how do you exploit it?** Docker reuses unchanged layers; order the Dockerfile so rarely-changing steps (deps install) come before frequently-changing ones (COPY source).

**21. How do you debug a running container?** `docker logs` for output and `docker exec -it <c> sh` for an interactive shell.

**22. What is a sidecar?** A helper container running alongside the main app in the same unit (log router, proxy, metrics agent).

## Amazon ECR (23–32)
**23. What is ECR?** Amazon Elastic Container Registry — a managed, private Docker image registry integrated with IAM and ECS/EKS.

**24. How do you authenticate to ECR?** `aws ecr get-login-password | docker login` against the registry URI; access is governed by IAM and repository policies.

**25. What does image scanning give you?** Detection of known CVEs in OS packages and dependencies in your images.

**26. What are lifecycle policies?** Rules that automatically expire/clean up old or untagged images to control storage cost.

**27. What does an ECR image URI look like?** `<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>`.

**28. How do you pull from ECR privately (no internet)?** Add VPC interface endpoints for ECR (api + dkr) and a gateway endpoint for S3 (layers live in S3).

**29. How do you share images cross-account?** With an ECR repository policy granting the other account pull permission.

**30. What are immutable tags?** A setting that blocks overwriting an existing tag, ensuring a given tag always points to the same image.

**31. Why prefer digests over `:latest` in production?** Digests are immutable and verifiable; `:latest` can silently change and break reproducibility.

**32. How is ECR access controlled?** Via IAM identity policies plus per-repository resource policies (not security groups).

## ECS core concepts (33–58)
**33. What is ECS?** AWS's native container orchestrator that schedules and manages containers across a cluster, with deep AWS integration.

**34. What is a task definition?** A JSON blueprint describing one or more containers: image, CPU/memory, ports, env, volumes, logging, and IAM roles.

**35. What is a task?** A running instantiation of a task definition — one or more containers scheduled together.

**36. What is an ECS service?** A controller that keeps a desired number of tasks running, replaces failures, and registers tasks with a load balancer.

**37. What is an ECS cluster?** A logical grouping of compute capacity (Fargate and/or EC2) on which tasks run.

**38. Fargate vs EC2 launch type?** Fargate is serverless — AWS runs the hosts and you pay per task; EC2 launch type means you manage the container instances for more control/cost tuning.

**39. When do you choose Fargate?** When you want zero host management, fast scaling, and per-task billing for typical web/API/worker workloads.

**40. When do you choose EC2 launch type?** When you need host-level control, GPUs/special instances, daemon sets, or better economics at large steady scale.

**41. What network modes does ECS support?** awsvpc (required for Fargate), bridge, host, and none (EC2 only for the latter three).

**42. What does awsvpc mode give a task?** Its own elastic network interface with a private IP and a task-level security group — first-class VPC networking.

**43. What is a task role?** An IAM role assumed by the application containers to call AWS APIs (e.g., read S3, write DynamoDB) with least privilege.

**44. What is the execution role?** The role ECS itself uses to pull images from ECR, fetch secrets, and write logs.

**45. How does an ECS service integrate with an ALB?** The service registers/deregisters its tasks in a target group; the ALB health-checks and routes to healthy tasks.

**46. How does ECS do rolling deployments?** It launches new-version tasks and drains old ones within min/max healthy percent thresholds — no downtime.

**47. How do you do blue/green on ECS?** With CodeDeploy and two target groups: deploy green, validate, shift traffic, and roll back instantly by switching back.

**48. How does ECS Service Auto Scaling work?** Application Auto Scaling adjusts the desired task count via target-tracking or step policies on CloudWatch metrics (CPU, memory, ALB request count).

**49. What are capacity providers?** They manage where tasks run and how capacity scales — Fargate, Fargate Spot, or EC2 Auto Scaling groups, with weighted strategies.

**50. What is Fargate Spot?** Spare-capacity Fargate at a discount for interruptible workloads; tasks can be reclaimed with a warning.

**51. What placement strategies exist on EC2?** spread (across AZs/instances for HA), binpack (fewest instances for cost), and random.

**52. How do containers in one task share data?** Through a shared volume defined in the task definition.

**53. How do services discover each other?** ECS Service Connect / AWS Cloud Map for DNS-based service discovery, or via an internal ALB.

**54. What is ECS Exec?** A feature to run a command or open a shell inside a running task for debugging, without SSH.

**55. How do you run a one-off job?** A standalone task via RunTask, or a scheduled task triggered by EventBridge.

**56. What is the ECS container agent?** On EC2 launch type, the agent on each instance registers it to the cluster and manages task lifecycle.

**57. What does draining an instance do?** Stops placing new tasks on it and reschedules existing tasks elsewhere — used for maintenance/scale-in.

**58. What is the platform version in Fargate?** The version of the underlying Fargate runtime that determines available features and patches.

## Networking, secrets, logging, scaling (59–78)
**59. Where do ECS container logs go?** To CloudWatch Logs via the awslogs driver, or to other destinations (OpenSearch, Kinesis) via FireLens.

**60. How do you pass secrets to a task securely?** Reference Secrets Manager or SSM Parameter Store ARNs in the task definition's `secrets` block — injected at runtime, never in the image.

**61. How do Fargate tasks in private subnets reach AWS services without NAT?** VPC endpoints for ECR, S3, CloudWatch Logs, Secrets Manager, etc.

**62. How is task-level traffic firewalled?** Each awsvpc task gets a security group controlling its inbound/outbound traffic.

**63. How do you centralize logs across many services?** Ship all to CloudWatch Logs / FireLens and aggregate into OpenSearch or a logging platform.

**64. What causes an OOM-killed container?** Exceeding the container/task memory hard limit; fix by right-sizing memory or fixing leaks.

**65. How do you scale tasks on queue depth?** Target-track on a custom CloudWatch metric like SQS ApproximateNumberOfMessages.

**66. min/max healthy percent — what do they do?** Control how many tasks stay running during a deployment (e.g., 100% min keeps full capacity while rolling).

**67. How do you keep deploys zero-downtime?** Health-checked rolling updates or blue/green, plus draining and proper readiness checks.

**68. How do you right-size a Fargate task?** Pick the smallest CPU/memory combo that meets load (load-test it) to minimize cost.

**69. What's a daemon scheduling strategy?** Runs exactly one task per EC2 instance (e.g., a log/metrics agent) — EC2 launch type only.

**70. How do you handle stateful containers?** Prefer externalizing state (RDS, EFS, S3, ElastiCache); use EFS volumes for shared persistent storage.

**71. How does ECS health-check a service task?** Via the ALB target-group health check and/or a container-level HEALTHCHECK.

**72. How do you trigger tasks on a schedule?** EventBridge Scheduler/rules invoking RunTask (cron-like).

**73. What's the benefit of awsvpc for security?** Per-task security groups and ENIs give fine-grained, instance-independent network isolation.

**74. How do you cut container cost?** Fargate Spot, right-sizing, service auto scaling, binpack placement on EC2, and lifecycle-cleaning ECR.

**75. How do you protect the ECR supply chain?** Image scanning, immutable tags, signed/pinned digests, and least-privilege pull roles.

**76. How do you roll back a bad ECS deploy fast?** CodeDeploy blue/green shifts traffic back to the previous target group instantly; rolling deploys redeploy the prior task definition.

**77. What is FireLens?** A log-router (Fluent Bit/Fluentd) sidecar integration for flexible log routing from ECS tasks.

**78. How do you give a task internet access in a private subnet?** Through a NAT gateway, or use VPC endpoints for AWS-only egress.

## ECS vs alternatives, architecture & troubleshooting (79–100)
**79. ECS vs EKS?** ECS is simpler, AWS-native orchestration; EKS is managed Kubernetes for teams wanting the k8s ecosystem and portability.

**80. ECS vs App Runner?** App Runner is the fastest path to run a single containerized web app/API with autoscaling and HTTPS; ECS gives full control for complex microservices.

**81. When would you pick EKS over ECS?** Existing Kubernetes expertise, multi-cloud portability, or needing the CNCF ecosystem (Helm, operators, service mesh).

**82. Describe a microservices HRMS on ECS.** One ALB with path-based listener rules → per-service target groups → ECS services (Fargate) for auth/employee/payroll/frontend → RDS Multi-AZ, with secrets in Secrets Manager and logs in CloudWatch.

**83. A task is stuck in PENDING — why?** No available capacity, image pull failure, ENI exhaustion, or subnet/SG/endpoint misconfiguration.

**84. "CannotPullContainerError" — what's wrong?** The execution role lacks ECR permissions, Docker isn't authenticated, or the task can't reach ECR (no endpoint/NAT).

**85. Tasks start then immediately stop — first checks?** Container logs and exit code, the health-check path/port, and whether the app actually binds the expected port.

**86. ALB returns 503 in front of ECS — meaning?** No healthy tasks are registered in the target group.

**87. How do you debug intermittent task failures?** Inspect CloudWatch logs, stopped-task reasons, exit codes, memory/CPU metrics, and recent deployments.

**88. How do you achieve immutable deployments?** Build a uniquely tagged image per commit, push to ECR, and update the task definition to that exact tag/digest.

**89. How do you separate dev/staging/prod?** Separate clusters/accounts, parameterized task definitions, and environment-scoped secrets and roles.

**90. How do you secure container-to-AWS calls?** A least-privilege task role scoped to the exact resources the service needs.

**91. How do you handle config that differs per environment?** SSM Parameter Store/Secrets Manager references in the task definition, not baked images.

**92. How do you load-balance multiple microservices behind one entry point?** One ALB with host/path rules fanning out to per-service target groups.

**93. What's the deploy pipeline for ECS?** Build image → push to ECR → register new task definition → update service (rolling or CodeDeploy blue/green) — automated in CI/CD.

**94. How do you reduce cold-start/scale latency?** Keep a sensible minimum task count, right-size, and use target-tracking with sensible thresholds.

**95. How do you run scheduled batch jobs cheaply?** EventBridge-scheduled Fargate (Spot) tasks that run and exit.

**96. How do you isolate noisy-neighbor workloads?** Separate task sizing/clusters or capacity providers; awsvpc SGs and resource limits.

**97. How do you monitor ECS health?** CloudWatch Container Insights (CPU/mem/task counts), ALB target health, and alarms wired to SNS.

**98. How do you move from EC2 single-box to ECS?** Containerize the app, push to ECR, define tasks, create a service behind the existing ALB, then shift traffic.

**99. Why externalize state from containers?** So any task can be replaced/scaled freely; state lives in managed services (RDS/EFS/S3/Redis).

**100. Summarize the build→ship→run flow on AWS.** Dockerfile builds an image → pushed to ECR → ECS/Fargate runs it as tasks behind an ALB, with logs in CloudWatch and secrets from Secrets Manager.

---
*Back to [Docker & ECS README](README.md). Practice more: [14 — MCQs](14-100-mcqs.md) · [13 — Troubleshooting](13-troubleshooting-handbook.md).*

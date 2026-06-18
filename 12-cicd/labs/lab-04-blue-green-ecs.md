# Lab 04 — Blue/Green Deployment on ECS Fargate

> **Goal:** Deploy a container to ECS Fargate with CodeDeploy Blue/Green — stand up green, flip traffic, then watch instant rollback.
>
> **Time:** ~120 min · **Cost:** Fargate tasks + ALB (delete after!)

## Prerequisites
- ECR image from Lab 02
- A VPC with two public subnets
- Lab 03 concepts (CodeDeploy app/deployment group)

---

## Step 1: Create the ALB with two target groups
```bash
# Target groups (ip type for Fargate)
aws elbv2 create-target-group --name tg-blue  --protocol HTTP --port 3000 \
  --vpc-id <VPC_ID> --target-type ip --health-check-path /health
aws elbv2 create-target-group --name tg-green --protocol HTTP --port 3000 \
  --vpc-id <VPC_ID> --target-type ip --health-check-path /health

# ALB + production listener (:80) → tg-blue, test listener (:8080) → tg-green
aws elbv2 create-load-balancer --name my-app-alb --type application \
  --subnets <SUBNET_A> <SUBNET_B> --security-groups <SG_ID>
```

## Step 2: Create the ECS cluster, task def, service (CODE_DEPLOY controller)
```bash
aws ecs create-cluster --cluster-name production-cluster

aws ecs register-task-definition --cli-input-json file://aws/ecs/task-definition.json

aws ecs create-service \
  --cluster production-cluster \
  --service-name my-app-svc \
  --task-definition my-app \
  --desired-count 2 \
  --launch-type FARGATE \
  --deployment-controller type=CODE_DEPLOY \
  --network-configuration 'awsvpcConfiguration={subnets=[<SUBNET_A>,<SUBNET_B>],securityGroups=[<SG_ID>],assignPublicIp=ENABLED}' \
  --load-balancers targetGroupArn=<TG_BLUE_ARN>,containerName=app,containerPort=3000
```

## Step 3: Create the CodeDeploy Blue/Green deployment group
Use the CLI in [`../aws/blue-green/README.md`](../aws/blue-green/README.md)
(`deploymentType=BLUE_GREEN`, both target groups, prod + test listeners,
5-minute termination wait).

## Step 4: Deploy a new version
Push a new image tag and create a deployment with the
[`../aws/codedeploy/appspec-ecs.yml`](../aws/codedeploy/appspec-ecs.yml) +
`taskdef.json`. Watch in the CodeDeploy console:

1. Green task set provisions.
2. Test traffic available on `:8080`.
3. Production listener flips `tg-blue → tg-green`.
4. Termination wait countdown begins.

✅ **Checkpoint:** `curl http://<ALB_DNS>/version` shows the new version; the old
tasks linger during the termination wait.

---

## Step 5: Practice instant rollback
During the termination wait, click **Stop and roll back** in the console (or
`aws deploy stop-deployment --deployment-id <ID> --auto-rollback-enabled`).

✅ **Checkpoint:** Traffic flips back to blue within seconds — the old version is
live again with no redeploy.

---

## Challenges
1. Add a `BeforeAllowTraffic` Lambda hook that validates green and aborts on failure.
2. Switch the deployment config to `ECSCanary10Percent5Minutes` (this becomes Lab 05's idea on ECS).
3. Add CloudWatch alarms (5xx, p99) for automatic rollback.

## Cleanup (important — ALB/Fargate cost money)
```bash
aws ecs update-service --cluster production-cluster --service my-app-svc --desired-count 0
aws ecs delete-service --cluster production-cluster --service my-app-svc --force
aws ecs delete-cluster --cluster production-cluster
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>
aws elbv2 delete-target-group --target-group-arn <TG_BLUE_ARN>
aws elbv2 delete-target-group --target-group-arn <TG_GREEN_ARN>
```

➡️ Next: [lab-05-canary-lambda.md](lab-05-canary-lambda.md)

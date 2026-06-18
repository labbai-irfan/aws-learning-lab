# Lab 03 — Full Pipeline: CodePipeline + CodeDeploy to EC2

> **Goal:** Wire Source → Build → Deploy into one CodePipeline that deploys a Node app to an EC2 instance via CodeDeploy (in-place rolling).
>
> **Time:** ~90 min · **Cost:** 1 t3.micro EC2 + pipeline/build

## Prerequisites
- Lab 02 complete (CodeBuild + ECR working) OR a zip-based app bundle
- A VPC with a public subnet

---

## Step 1: Prepare the EC2 target
Launch a t3.micro (Amazon Linux 2023) with an **instance profile** allowing S3
read (for the bundle) and tag it `App=my-node-app`.

Install the CodeDeploy agent (user-data):
```bash
#!/bin/bash
yum update -y
yum install -y ruby wget
cd /home/ec2-user
wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
chmod +x ./install && ./install auto
systemctl enable --now codedeploy-agent
```

## Step 2: Add the appspec + hook scripts
Copy [`../aws/codedeploy/appspec.yml`](../aws/codedeploy/appspec.yml) and the
[`../aws/codedeploy/scripts/`](../aws/codedeploy/scripts/) folder into your app
repo. Make the scripts executable (`chmod +x`).

## Step 3: Create the CodeDeploy application + deployment group
```bash
aws deploy create-application --application-name my-node-app \
  --compute-platform Server

aws deploy create-deployment-group \
  --application-name my-node-app \
  --deployment-group-name production-fleet \
  --deployment-config-name CodeDeployDefault.OneAtATime \
  --ec2-tag-filters Key=App,Value=my-node-app,Type=KEY_AND_VALUE \
  --service-role-arn arn:aws:iam::<ACCOUNT_ID>:role/CodeDeployServiceRole \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE
```

## Step 4: Create the pipeline
Edit [`../aws/codepipeline/pipeline.json`](../aws/codepipeline/pipeline.json)
(connection ARN, repo, bucket, build project) then:
```bash
aws codepipeline create-pipeline --cli-input-json file://aws/codepipeline/pipeline.json
```

## Step 5: Trigger and watch
Push a commit. The pipeline runs Source → Build → Deploy. Watch the deploy:
```bash
aws deploy list-deployments --application-name my-node-app \
  --deployment-group-name production-fleet
```

✅ **Checkpoint:** `curl http://<EC2_PUBLIC_IP>:3000/health` returns 200, served
by the new revision.

---

## Step 6: Test auto-rollback
Break the app (e.g. make `validate_service.sh` exit 1) and push. Confirm the
deployment **fails and rolls back** to the previous revision.

✅ **Checkpoint:** Deployment status `Failed`, app still serving the old version.

---

## Challenges
1. Switch the deployment config to `HalfAtATime` with two instances behind an ALB.
2. Add a CloudWatch alarm and attach it to the deployment group for alarm-based rollback.
3. Add a manual approval stage between Build and Deploy.

## Cleanup
```bash
aws codepipeline delete-pipeline --name my-app-pipeline
aws deploy delete-deployment-group --application-name my-node-app --deployment-group-name production-fleet
aws deploy delete-application --application-name my-node-app
# terminate the EC2 instance
```

➡️ Next: [lab-04-blue-green-ecs.md](lab-04-blue-green-ecs.md)

# Lab 02 — Building with AWS CodeBuild

> **Goal:** Create a CodeBuild project that runs tests, builds a Docker image, and pushes it to ECR using a `buildspec.yml`.
>
> **Time:** ~45 min · **Cost:** CodeBuild build-minutes (small) + ECR storage

## Prerequisites
- AWS CLI v2, an app with a `Dockerfile` (use this repo's [`../Dockerfile`](../Dockerfile))
- Source in GitHub or CodeCommit

---

## Step 1: Create an ECR repository
```bash
aws ecr create-repository --repository-name my-app \
  --image-scanning-configuration scanOnPush=true
```

## Step 2: Add the buildspec
Copy [`../aws/codebuild/buildspec.yml`](../aws/codebuild/buildspec.yml) to your
repo root (or point the project at its path). Review the phases:
`install → pre_build → build → post_build`.

## Step 3: Create the CodeBuild service role
The role needs ECR push, CloudWatch Logs, and (for secrets) SSM/Secrets Manager
read. Minimal inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect":"Allow","Action":["ecr:GetAuthorizationToken"],"Resource":"*"},
    {"Effect":"Allow","Action":["ecr:BatchCheckLayerAvailability","ecr:PutImage",
      "ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"],
      "Resource":"arn:aws:ecr:*:*:repository/my-app"},
    {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"}
  ]
}
```

## Step 4: Create the build project
```bash
aws codebuild create-project \
  --name my-app-build \
  --source type=GITHUB,location=https://github.com/<ORG>/<REPO>.git \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,\
computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
  --service-role arn:aws:iam::<ACCOUNT_ID>:role/codebuild-my-app
```
> `privilegedMode=true` is required to run `docker build`.

## Step 5: Run it
```bash
aws codebuild start-build --project-name my-app-build
# tail logs in the console or:
aws logs tail /aws/codebuild/my-app-build --follow
```

✅ **Checkpoint:** A new image tag appears in ECR
(`aws ecr list-images --repository-name my-app`), and the build log shows tests
passing.

---

## Challenges
1. Add `reports:` to publish JUnit test results.
2. Add `cache:` for `node_modules` and verify the 2nd build is faster.
3. Pull a value from SSM Parameter Store via `env.parameter-store`.
4. Make the build **fail** if `npm audit` finds a CRITICAL vuln.

## Cleanup
```bash
aws codebuild delete-project --name my-app-build
aws ecr delete-repository --repository-name my-app --force
```

➡️ Next: [lab-03-codepipeline-codedeploy.md](lab-03-codepipeline-codedeploy.md)

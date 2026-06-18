# Lab 05 — Canary Deployment on AWS Lambda

> **Goal:** Use CodeDeploy to canary-shift traffic between two Lambda versions with a pre-traffic validation hook and automatic rollback on alarm.
>
> **Time:** ~75 min · **Cost:** ~$0 (Lambda free tier)

## Prerequisites
- AWS CLI v2
- A simple Lambda function (Node 20) returning `{ statusCode: 200, body: 'v1' }`

---

## Step 1: Create the function + alias
```bash
zip fn.zip index.js
aws lambda create-function --function-name my-api-handler \
  --runtime nodejs20.x --handler index.handler \
  --role arn:aws:iam::<ACCOUNT_ID>:role/lambda-basic \
  --zip-file fileb://fn.zip

# Publish version 1 and point the 'live' alias at it
aws lambda publish-version --function-name my-api-handler   # → Version 1
aws lambda create-alias --function-name my-api-handler \
  --name live --function-version 1
```

## Step 2: Deploy the pre-traffic hook
Deploy [`../aws/canary/pre-traffic-hook.js`](../aws/canary/pre-traffic-hook.js)
as its own Lambda (`my-api-pre-traffic-hook`). Its role needs
`codedeploy:PutLifecycleEventHookExecutionStatus` and `lambda:InvokeFunction`.

## Step 3: Create the CodeDeploy app + deployment group (Lambda)
```bash
aws deploy create-application --application-name my-api \
  --compute-platform Lambda

aws deploy create-deployment-group \
  --application-name my-api \
  --deployment-group-name my-api-dg \
  --deployment-config-name CodeDeployDefault.LambdaCanary10Percent5Minutes \
  --service-role-arn arn:aws:iam::<ACCOUNT_ID>:role/CodeDeployLambdaRole \
  --alarm-configuration enabled=true,alarms=[{name=my-api-errors}] \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_STOP_ON_ALARM
```

## Step 4: Publish v2 and canary-deploy
```bash
# Update code to return 'v2', publish version 2
aws lambda update-function-code --function-name my-api-handler --zip-file fileb://fn-v2.zip
aws lambda publish-version --function-name my-api-handler        # → Version 2

# AppSpec describing the shift (see aws/canary/canary-lambda-pipeline.yml)
aws deploy create-deployment \
  --application-name my-api \
  --deployment-group-name my-api-dg \
  --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"version: 0.0\nResources:\n- myLambda:\n    Type: AWS::Lambda::Function\n    Properties:\n      Name: my-api-handler\n      Alias: live\n      CurrentVersion: 1\n      TargetVersion: 2\nHooks:\n- BeforeAllowTraffic: \"my-api-pre-traffic-hook\""}}'
```

## Step 5: Observe the canary
```bash
# 10% of invocations hit v2 for 5 minutes, then 100%
for i in $(seq 1 50); do
  aws lambda invoke --function-name my-api-handler:live /dev/stdout 2>/dev/null
done | sort | uniq -c   # ~10% should show v2
```

✅ **Checkpoint:** During the bake window roughly 10% of responses are `v2`; the
pre-traffic hook ran and returned `Succeeded`; after 5 min all are `v2`.

---

## Step 6: Trigger an automatic rollback
Deploy a broken v3 (throws an error), make the `my-api-errors` alarm fire during
the canary window.

✅ **Checkpoint:** CodeDeploy detects the alarm, **aborts and rolls back** the
alias to the previous version automatically.

---

## Challenges
1. Switch to `LambdaLinear10PercentEvery1Minute` and watch the gradual ramp.
2. Add an `AfterAllowTraffic` hook that runs a post-deploy smoke test.
3. Wire this into the [production-pipeline.yml](../.github/workflows/production-pipeline.yml).

## Cleanup
```bash
aws deploy delete-deployment-group --application-name my-api --deployment-group-name my-api-dg
aws deploy delete-application --application-name my-api
aws lambda delete-function --function-name my-api-handler
aws lambda delete-function --function-name my-api-pre-traffic-hook
```

🎉 **You've completed Phase 12.** You can now build CI/CD with GitHub Actions and
the AWS Code* suite, and deploy with rolling, blue/green, and canary strategies.

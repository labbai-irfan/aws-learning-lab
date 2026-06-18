# 13 — Serverless Labs (Hands-On)

> Console + CLI labs covering the whole serverless stack. **Setup:** AWS CLI v2 configured (least-privilege user), Node.js 20+, and a Budget alert ([Phase 01 setup](../01-aws-fundamentals/05-aws-account-setup-guide.md)).

**Legend:** 🛠️ run this · ✅ verify · 🔒 security · 💰 cost · ⚠️ gotcha.

---

## Lab 1 — Your first Lambda
1. 🛠️ Create a function:
```bash
cat > index.mjs <<'EOF'
export const handler = async (event) => ({ statusCode: 200, body: `Hello ${event.name ?? "world"}` });
EOF
zip fn.zip index.mjs
aws lambda create-function --function-name hello --runtime nodejs20.x \
  --handler index.handler --zip-file fileb://fn.zip \
  --role arn:aws:iam::<acct>:role/lambda-basic-exec
aws lambda invoke --function-name hello --payload '{"name":"HRMS"}' out.json && cat out.json
```
✅ `out.json` returns "Hello HRMS". 🔒 The role has only `AWSLambdaBasicExecutionRole` (logs).

## Lab 2 — HTTP API → Lambda
1. 🛠️ Create an **HTTP API** (cheaper than REST) and a Lambda proxy integration; deploy.
2. ✅ `curl https://<api-id>.execute-api.<region>.amazonaws.com/` returns your handler output.
⚠️ API Gateway hard timeout = 29 s; Lambda async payload = 256 KB.

## Lab 3 — DynamoDB CRUD from Lambda
1. 🛠️ Create a table (on-demand) and grant the function `dynamodb:*Item`/`Query` on its ARN only:
```bash
aws dynamodb create-table --table-name Employees \
  --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```
2. Put/Query items (see [08 — DynamoDB](08-dynamodb.md) for the SDK code).
✅ One `Query(PK=EMP#123)` returns the employee + related items. 🔒 Least-privilege on the table ARN.

## Lab 4 — SQS queue worker
1. 🛠️ Create a standard queue + a DLQ; set the queue as a Lambda **event source** (batch size 10).
```bash
aws sqs create-queue --queue-name jobs
aws sqs create-queue --queue-name jobs-dlq
```
2. Send messages; watch the Lambda process them in batches.
✅ Failed messages land in the DLQ after max receives. ⚠️ Standard SQS = at-least-once → make the handler idempotent.

## Lab 5 — SNS fan-out
1. 🛠️ Create an SNS topic; subscribe two SQS queues (or two Lambdas).
2. Publish once → both subscribers receive it (**fan-out**).
✅ One publish, multiple deliveries. 💡 Add a subscription **filter policy** to route subsets.

## Lab 6 — EventBridge rule (scheduled + event)
1. 🛠️ Create a **scheduled** rule (cron) targeting a Lambda (e.g., nightly payroll trigger).
2. Create an **event-pattern** rule matching a custom event source, target another Lambda.
✅ The schedule fires on time; custom events route to the right target.

## Lab 7 — Step Functions workflow
1. 🛠️ Define a small **Standard** state machine: Validate → Process → Notify, with a Catch → DLQ on failure.
2. Start an execution; inspect the visual graph + execution history.
✅ Failures route to the catch branch; history shows each state transition. 💡 Express for high-volume short workflows.

## Lab 8 — Cognito-protected API
1. 🛠️ Create a **User Pool** + app client (Authorization Code + PKCE) and an HTTP API **JWT authorizer** pointing at the pool.
2. Sign up a user (Hosted UI), get tokens, call the API with `Authorization: Bearer <access>`.
✅ Calls without a valid JWT are rejected (401); valid ones reach the Lambda with verified claims. 🔒 See [09 — Cognito](09-cognito.md).

## Lab 9 — Trace it with X-Ray
1. 🛠️ Enable **Active Tracing** on the Lambda + tracing on the API stage; instrument the SDK.
2. Generate traffic; open the **service map** and a trace timeline.
✅ You can see API GW → Lambda → DynamoDB latency per hop. See [Phase 09 — X-Ray](../09-cloudwatch/16-x-ray.md).

---

## Cleanup 💰
```bash
aws lambda delete-function --function-name hello
aws dynamodb delete-table --table-name Employees
aws sqs delete-queue --queue-url <jobs-url>; aws sqs delete-queue --queue-url <dlq-url>
# delete the API, topic, rules, state machine, and user pool too
```
⚠️ Delete API Gateway, SNS topics, EventBridge rules, Step Functions, and the Cognito pool to avoid lingering charges.

---
*Back to [Serverless README](README.md). Test yourself: [14 — MCQs](14-100-mcqs.md) · [10 — Interview](10-interview-questions.md).*

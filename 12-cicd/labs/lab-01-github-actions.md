# Lab 01 — Your First GitHub Actions CI/CD Pipeline

> **Goal:** Build a CI pipeline for a Node app, then deploy a React build to S3 + CloudFront using GitHub OIDC (no static AWS keys).
>
> **Time:** ~60 min · **Cost:** ~$0 (S3/CloudFront free-tier friendly)

## Prerequisites
- GitHub repo with a small React or Node app (or use `npx create-react-app demo`)
- AWS account + AWS CLI v2 configured
- An S3 bucket and CloudFront distribution (or create them in step 3)

---

## Part A — Continuous Integration

### Step 1: Add a CI workflow
Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: npm }
      - run: npm ci
      - run: npm test -- --watchAll=false
      - run: npm run build
```

### Step 2: Verify
Push to a branch, open a PR. Confirm the **Checks** tab shows the workflow
running, and that a failing test blocks the PR.

✅ **Checkpoint:** Green check on the PR; red check when you break a test.

---

## Part B — Continuous Deployment with OIDC

### Step 3: Create the OIDC provider + IAM role
```bash
# 1. Create the GitHub OIDC identity provider (once per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Trust policy scoped to your repo + branch (save as trust.json)
cat > trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:ref:refs/heads/main"}
    }
  }]
}
EOF

aws iam create-role --role-name github-actions-react-deploy \
  --assume-role-policy-document file://trust.json

# 3. Attach a least-privilege policy (S3 + CloudFront invalidation)
aws iam put-role-policy --role-name github-actions-react-deploy \
  --policy-name deploy --policy-document '{
    "Version":"2012-10-17",
    "Statement":[
      {"Effect":"Allow","Action":["s3:PutObject","s3:DeleteObject","s3:ListBucket"],
       "Resource":["arn:aws:s3:::my-react-app-prod","arn:aws:s3:::my-react-app-prod/*"]},
      {"Effect":"Allow","Action":["cloudfront:CreateInvalidation"],"Resource":"*"}
    ]}'
```

### Step 4: Add the deploy workflow
Copy [`../.github/workflows/react-ci-cd.yml`](../.github/workflows/react-ci-cd.yml)
into your repo. Edit `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`, `AWS_REGION`, and
the `role-to-assume` ARN.

### Step 5: Deploy
Push to `main`. Watch the **deploy** job assume the role via OIDC, sync to S3,
and invalidate CloudFront.

✅ **Checkpoint:** Visit your CloudFront URL — the new build is live. No AWS keys
were ever stored in GitHub.

---

## Challenges
1. Add a `lint` job that runs **before** `test` using `needs:`.
2. Add a matrix to test on Node 18, 20, 22.
3. Add a `workflow_dispatch` input to deploy a specific git SHA.
4. Add an `environment: production` block with a required reviewer.

## Cleanup
```bash
aws iam delete-role-policy --role-name github-actions-react-deploy --policy-name deploy
aws iam delete-role --role-name github-actions-react-deploy
# (keep the OIDC provider if other repos use it)
```

➡️ Next: [lab-02-codebuild.md](lab-02-codebuild.md)

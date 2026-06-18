# Module 5 — CloudFormation: Native AWS IaC

> Templates, stacks, StackSets, nested stacks, drift detection, change sets, and the CDK. Know when to use CloudFormation vs Terraform.

---

## 1. CloudFormation vs Terraform

| | **CloudFormation** | **Terraform** |
|---|---|---|
| Native to AWS | Yes — no extra state management | No — requires state backend |
| Multi-cloud | No | Yes |
| Language | YAML / JSON | HCL |
| AWS service coverage | 100% day-1 | Usually 1–2 weeks after launch |
| Rollback | Automatic on failure | Manual (requires plan+apply) |
| StackSets (multi-account) | Native | via Terragrunt / account iteration |
| CDK | CloudFormation output | CDKTF |
| When to choose | AWS-only orgs, StackSets required, native rollback needed | Multi-cloud, richer logic, large module ecosystem |

---

## 2. Template anatomy

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: HRMS production stack

Parameters:
  Env:
    Type: String
    AllowedValues: [dev, staging, prod]
    Default: staging
  DBPassword:
    Type: String
    NoEcho: true        # never shows in console/logs

Mappings:
  InstanceType:
    prod:    { Api: t3.medium, DB: db.r6g.large }
    staging: { Api: t3.micro,  DB: db.t4g.micro }

Conditions:
  IsProd: !Equals [!Ref Env, prod]

Resources:
  HRMSBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain   # don't delete data on stack delete
    Properties:
      BucketName: !Sub "hrms-assets-${Env}-${AWS::AccountId}"
      VersioningConfiguration:
        Status: Enabled

  HRMSDB:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceClass: !FindInMap [InstanceType, !Ref Env, DB]
      MultiAZ: !If [IsProd, true, false]
      MasterUserPassword: !Ref DBPassword

Outputs:
  BucketName:
    Value: !Ref HRMSBucket
    Export:
      Name: !Sub "${Env}-hrms-bucket"
  DBEndpoint:
    Value: !GetAtt HRMSDB.Endpoint.Address
```

---

## 3. Intrinsic functions quick reference

| Function | Use |
|---|---|
| `!Ref` | Reference a resource logical ID or parameter |
| `!GetAtt Resource.Attr` | Get an attribute of a resource |
| `!Sub "string ${Var}"` | String interpolation |
| `!If [Cond, A, B]` | Conditional value |
| `!Select [idx, list]` | Pick from a list |
| `!Split [delim, str]` | Split a string |
| `!Join [delim, list]` | Join to a string |
| `!FindInMap [Map, K1, K2]` | Map lookup |
| `!ImportValue ExportName` | Cross-stack import |
| `!Base64 string` | For UserData |

---

## 4. Change sets (preview before apply)

```bash
aws cloudformation create-change-set \
  --stack-name hrms-prod \
  --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod \
  --change-set-name update-2026-06-17

aws cloudformation describe-change-set \
  --stack-name hrms-prod --change-set-name update-2026-06-17

aws cloudformation execute-change-set \
  --stack-name hrms-prod --change-set-name update-2026-06-17
```

💡 **Always create a change set for prod** — it shows exactly which resources will be added/modified/deleted before anything happens.

---

## 5. Nested stacks & cross-stack references

### Nested stacks — for modularity
```yaml
Resources:
  VPCStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3.amazonaws.com/cfn-templates/vpc.yaml
      Parameters:
        CIDR: "10.0.0.0/16"
  AppStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub "https://s3.amazonaws.com/cfn-templates/app.yaml"
      Parameters:
        VpcId: !GetAtt VPCStack.Outputs.VpcId
```

### Cross-stack references — for loose coupling
Export from one stack:
```yaml
Outputs:
  VpcId:
    Export: { Name: "hrms-prod-VpcId" }
```
Import in another:
```yaml
Properties:
  VpcId: !ImportValue "hrms-prod-VpcId"
```
⚠️ **You cannot delete a stack that exports a value being imported** — plan export names carefully.

---

## 6. StackSets — multi-account / multi-region

Deploy one template across **multiple accounts and regions** at once:
```
   Management Account ──► StackSet ──► Account A (us-east-1)
                                   ──► Account A (eu-west-1)
                                   ──► Account B (us-east-1)
```
Use cases: GuardDuty baseline, Config rules, IAM baselines, CloudTrail — anything that must be consistent across an Organization.

```bash
aws cloudformation create-stack-set --stack-set-name security-baseline \
  --template-body file://security-baseline.yaml \
  --permission-model SERVICE_MANAGED \  # uses Org trusted access
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

aws cloudformation create-stack-instances --stack-set-name security-baseline \
  --deployment-targets OrganizationalUnitIds=["ou-xxx-yyy"] \
  --regions ["us-east-1","eu-west-1"]
```

---

## 7. Drift detection

```bash
aws cloudformation detect-stack-drift --stack-name hrms-prod
aws cloudformation describe-stack-resource-drifts --stack-name hrms-prod \
  --stack-resource-drift-status-filters MODIFIED DELETED
```
Drift = someone changed a resource outside CloudFormation. Regular drift detection (EventBridge schedule) is a governance control.

---

## 8. AWS CDK — CloudFormation with a real language

CDK generates CloudFormation YAML from Python/TypeScript/Java code:
```python
from aws_cdk import Stack, aws_s3 as s3
class HRMSStack(Stack):
    def __init__(self, scope, id, **kwargs):
        super().__init__(scope, id, **kwargs)
        s3.Bucket(self, "Assets",
            versioned=True,
            removal_policy=RemovalPolicy.RETAIN)
```
```bash
cdk synth   # generate CloudFormation template
cdk diff    # like `terraform plan`
cdk deploy  # like `terraform apply`
```
💡 CDK is the recommended approach for teams comfortable with code; it brings type safety, unit testing, and abstraction over raw CloudFormation.

---

## ✅ CloudFormation checklist
- [ ] `NoEcho: true` on all secret parameters
- [ ] `DeletionPolicy: Retain` on stateful resources
- [ ] Change sets before every prod update
- [ ] StackSets for org-wide security baselines
- [ ] Regular drift detection (EventBridge schedule)
- [ ] Nested stacks for template modularity
- [ ] CDK for new projects over raw YAML

➡️ Next: [Module 6 — WAF & Shield](06-waf-shield.md)

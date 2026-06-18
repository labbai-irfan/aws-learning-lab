# Module 4 — Terraform: Infrastructure as Code for AWS

> Production-grade Terraform: providers, state, modules, workspaces, remote backend, CI/CD, and the patterns that separate amateur from enterprise IaC.

---

## 1. Why Terraform for AWS

| | Manual (Console/CLI) | AWS CloudFormation | **Terraform** |
|---|---|---|---|
| Multi-cloud | No | No (AWS only) | **Yes** |
| State management | No | Stack managed | **Local or remote** |
| Plan before apply | No | Change sets | **`terraform plan`** |
| Module ecosystem | No | Nested stacks | **Registry + community** |
| Language | N/A | JSON/YAML | **HCL** |
| Drift detection | No | Yes | **Yes (`plan`)** |

---

## 2. Core concepts

```
   Configuration (.tf files)
       │ terraform init   (downloads providers + modules)
       ▼
   Provider (AWS API auth)
       │ terraform plan   (computes diff vs state)
       ▼
   State File (terraform.tfstate — source of truth about deployed resources)
       │ terraform apply  (executes the plan)
       ▼
   Real AWS Resources
```

### Providers, resources, data sources
```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  required_version = ">= 1.5"
}

provider "aws" {
  region = var.region
  default_tags { tags = { Project = "HRMS", ManagedBy = "Terraform" } }
}

resource "aws_s3_bucket" "assets" {
  bucket = "hrms-assets-${var.env}"
}

data "aws_vpc" "main" {
  filter { name = "tag:Name", values = ["hrms-vpc"] }
}
```

---

## 3. Variables, locals, outputs

```hcl
variable "env" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "db_password" {
  type      = string
  sensitive = true   # never printed in logs
}

locals {
  name_prefix = "hrms-${var.env}"
  common_tags = { Env = var.env, App = "hrms" }
}

output "alb_dns" {
  description = "ALB DNS name for CNAME"
  value       = aws_lb.api.dns_name
}
```

---

## 4. Remote state (essential for teams)

Store state in **S3 + DynamoDB** (locking) — never commit `terraform.tfstate` to git.

```hcl
terraform {
  backend "s3" {
    bucket         = "hrms-terraform-state-ACCT"
    key            = "prod/hrms/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hrms-terraform-locks"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
  }
}
```

🛠️ Bootstrap the backend (one-time, done manually):
```bash
aws s3api create-bucket --bucket hrms-terraform-state-ACCT --region us-east-1
aws s3api put-bucket-versioning --bucket hrms-terraform-state-ACCT \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name hrms-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## 5. Modules — reusable infrastructure

Structure:
```
modules/
  vpc/          main.tf  variables.tf  outputs.tf
  rds/
  ecs-service/
  alb/
environments/
  prod/         main.tf  terraform.tfvars
  staging/
```

Module usage:
```hcl
module "hrms_vpc" {
  source = "../../modules/vpc"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b", "us-east-1c"]
  env    = var.env
}

module "rds" {
  source               = "../../modules/rds"
  subnet_ids           = module.hrms_vpc.private_db_subnet_ids
  vpc_id               = module.hrms_vpc.vpc_id
  engine_version       = "8.0.39"
  instance_class       = var.db_instance_class
  multi_az             = var.env == "prod"
}
```

💡 Use **semantic versioning** on modules: `source = "git::https://github.com/org/tf-modules.git//vpc?ref=v2.3.0"`.

---

## 6. Workspaces vs directories

| | **Terraform workspaces** | **Directory-per-environment** |
|---|---|---|
| State | Separate per workspace | Separate (different state keys) |
| Config | Shared (same `.tf`) | Different (can diverge) |
| Best for | Identical environments | Prod/non-prod may differ significantly |
| Risk | Accidental `terraform apply` on prod | More file duplication |

💡 **Directory-per-environment** is the production standard for most teams. Workspaces work well for spinning up feature-branch environments.

---

## 7. Sensitive operations & safety

```bash
terraform plan -out=plan.tfplan          # save plan to file
terraform apply plan.tfplan              # apply exactly the saved plan
terraform plan -target=module.rds        # plan only one module
terraform destroy -target=aws_instance.old  # destroy specific resource
```

⚠️ Safety rules:
- **`-target` is a last resort** — only for emergency fixes; normal workflow plans the whole graph.
- Protect production resources: `prevent_destroy = true` in lifecycle block.
- Mark state as sensitive for secret outputs.
- **Never `terraform destroy`** on prod without a change request and backup.

```hcl
resource "aws_rds_cluster" "hrms" {
  lifecycle {
    prevent_destroy       = true
    ignore_changes        = [engine_version]  # managed by AWS
    create_before_destroy = true
  }
}
```

---

## 8. Terraform in CI/CD

```
   PR opened ──► CI:
                  terraform fmt -check
                  terraform validate
                  tflint / tfsec / checkov (security scan)
                  terraform plan -out=plan.tfplan
                  Post plan as PR comment (Atlantis/Spacelift)
   PR merged ──► CD:
                  terraform apply plan.tfplan  (against staging)
   Release tag ──► terraform apply (prod, with human approval gate)
```

Tools: **Atlantis** (self-hosted PR automation), **Spacelift** / **Terraform Cloud** (SaaS), **GitHub Actions** with OIDC (no static AWS credentials).

🔒 Use **OIDC federated auth** from GitHub Actions — no stored AWS keys:
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCT:role/github-terraform-role
    aws-region: us-east-1
```

---

## 9. Enterprise patterns

### Import existing resources
```bash
terraform import aws_security_group.app sg-0abc123
```

### Moved blocks (safe refactoring)
```hcl
moved {
  from = aws_security_group.old_name
  to   = module.network.aws_security_group.app
}
```

### Dynamic blocks
```hcl
resource "aws_security_group" "app" {
  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

---

## ✅ Terraform checklist
- [ ] Remote state (S3 + DynamoDB lock + encrypt)
- [ ] Modules for reusable infra; versioned refs
- [ ] `default_tags` on provider (never forget a tag)
- [ ] `prevent_destroy` on databases/critical resources
- [ ] `sensitive = true` on secret variables/outputs
- [ ] CI: fmt + validate + tfsec + plan as PR comment
- [ ] CD: apply on merge, with approval gate for prod
- [ ] OIDC auth from CI — no static AWS access keys

➡️ Next: [Module 5 — CloudFormation](05-cloudformation.md)

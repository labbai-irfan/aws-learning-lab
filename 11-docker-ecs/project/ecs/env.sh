#!/usr/bin/env bash
# Source this in every step:  source ecs/env.sh
# Fill in the IDs from your account/VPC before running the cloud steps.

export REGION="ap-south-1"
export ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
export REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
export CLUSTER="hrms-prod"
export IMAGE_TAG="1.0.0"

# --- networking (fill these in from your VPC — Phase 04) ---
export VPC_ID="vpc-xxxxxxxx"
export PUB_SUBNET_A="subnet-pub-a"
export PUB_SUBNET_B="subnet-pub-b"
export PRIV_SUBNET_A="subnet-priv-a"
export PRIV_SUBNET_B="subnet-priv-b"

# --- security groups (created by 00-bootstrap.sh, or pre-existing) ---
export ALB_SG="sg-alb"      # allows 80/443 from internet
export TASK_SG="sg-task"    # allows 5000/80 from ALB_SG; egress all
export RDS_SG="sg-rds"      # allows 3306 from TASK_SG

# --- data layer ---
export DB_SUBNET_GROUP="hrms-db-subnets"
export DB_HOST="REPLACE-WITH-RDS-ENDPOINT"               # from Step 4
export DB_NAME="hrms"
export DB_USER="hrmsadmin"
export DB_SECRET_ARN="arn:aws:secretsmanager:${REGION}:${ACCOUNT}:secret:hrms/db"

# --- IAM roles (created by 00-bootstrap.sh) ---
export EXEC_ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/ecsTaskExecutionRole"
export TASK_ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/hrmsTaskRole"

# --- target group ARNs (created in Step 5; paste them here after) ---
export FRONTEND_TG="arn:aws:elasticloadbalancing:...:targetgroup/hrms-frontend-tg/..."
export AUTH_TG="arn:aws:elasticloadbalancing:...:targetgroup/hrms-auth-tg/..."
export EMPLOYEE_TG="arn:aws:elasticloadbalancing:...:targetgroup/hrms-employee-tg/..."
export PAYROLL_TG="arn:aws:elasticloadbalancing:...:targetgroup/hrms-payroll-tg/..."

echo "env loaded: account=$ACCOUNT region=$REGION registry=$REGISTRY cluster=$CLUSTER"

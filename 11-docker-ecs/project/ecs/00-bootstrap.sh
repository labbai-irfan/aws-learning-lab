#!/usr/bin/env bash
# Create the cluster, IAM roles, log groups, and security groups for the HRMS deploy.
# Idempotent-ish: re-running prints "exists" for things already present.
# Prereq:  source ecs/env.sh   (with VPC/subnet IDs filled in)
set -euo pipefail

echo "==> ECS cluster ($CLUSTER) with Fargate + Container Insights"
aws ecs create-cluster --cluster-name "$CLUSTER" \
  --capacity-providers FARGATE FARGATE_SPOT \
  --settings name=containerInsights,value=enabled 2>/dev/null || echo "cluster exists"

echo "==> Task EXECUTION role (lets ECS pull images + write logs + read secrets)"
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  2>/dev/null || echo "exec role exists"
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
# allow reading the DB secret (scoped to the hrms/db secret)
aws iam put-role-policy --role-name ecsTaskExecutionRole --policy-name ReadDbSecret \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",
    \"Action\":[\"secretsmanager:GetSecretValue\"],\"Resource\":\"${DB_SECRET_ARN}*\"}]}"

echo "==> Task ROLE (the app's own AWS permissions — minimal here)"
aws iam create-role --role-name hrmsTaskRole \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  2>/dev/null || echo "task role exists"

echo "==> CloudWatch log groups (30-day retention)"
for svc in auth employee payroll frontend; do
  aws logs create-log-group --log-group-name "/ecs/hrms-$svc" 2>/dev/null || true
  aws logs put-retention-policy --log-group-name "/ecs/hrms-$svc" --retention-in-days 30
done

echo "==> Security groups (ALB → tasks → RDS)"
# NOTE: create these once; paste the IDs into ecs/env.sh.
#   ALB_SG : inbound 80,443 from 0.0.0.0/0
#   TASK_SG: inbound 5000 and 80 from ALB_SG ; egress all
#   RDS_SG : inbound 3306 from TASK_SG
echo "    (create/verify ALB_SG, TASK_SG, RDS_SG per the comments, then update env.sh)"

echo "Bootstrap complete."

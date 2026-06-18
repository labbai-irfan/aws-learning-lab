#!/usr/bin/env bash
# Create one ECS service per microservice, each wired to its ALB target group.
# Prereq:  source ecs/env.sh  (TG ARNs + TASK_SG + private subnets filled in)
#          task definitions already registered (Step 6)
set -euo pipefail

NET="awsvpcConfiguration={subnets=[${PRIV_SUBNET_A},${PRIV_SUBNET_B}],securityGroups=[${TASK_SG}],assignPublicIp=DISABLED}"
DEPLOY="deploymentCircuitBreaker={enable=true,rollback=true},minimumHealthyPercent=100,maximumPercent=200"

create() {  # name family containerName containerPort targetGroupArn
  local svc="$1" fam="$2" cname="$3" port="$4" tg="$5"
  echo "==> service hrms-${svc}-svc (family ${fam})"
  aws ecs create-service \
    --cluster "$CLUSTER" \
    --service-name "hrms-${svc}-svc" \
    --task-definition "$fam" \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "$NET" \
    --deployment-configuration "$DEPLOY" \
    --health-check-grace-period-seconds 60 \
    --load-balancers "targetGroupArn=${tg},containerName=${cname},containerPort=${port}"
}

create frontend hrms-frontend frontend 80   "$FRONTEND_TG"
create auth     hrms-auth     auth     5000 "$AUTH_TG"
create employee hrms-employee employee 5000 "$EMPLOYEE_TG"
create payroll  hrms-payroll  payroll  5000 "$PAYROLL_TG"

echo "Services created. Watch rollout:"
echo "  aws ecs describe-services --cluster $CLUSTER --services hrms-frontend-svc hrms-auth-svc hrms-employee-svc hrms-payroll-svc --query 'services[].{n:serviceName,d:desiredCount,r:runningCount}'"

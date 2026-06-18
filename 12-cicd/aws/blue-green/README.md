# Blue/Green Assets

This folder documents the AWS resources you wire up for an ECS Blue/Green
deployment. CodeDeploy orchestrates the swap; you provide the two target
groups and a production listener.

## Required infrastructure

```
                  ┌─────────────── ALB ───────────────┐
   Internet ────► │  Listener :443                      │
                  │     │                               │
                  │     ├─ (prod traffic) ─► Target Group BLUE  ─► ECS task set (v1)
                  │     └─ (test :8080)    ─► Target Group GREEN ─► ECS task set (v2)
                  └─────────────────────────────────────┘
```

1. **Two target groups** — `tg-blue` and `tg-green` (same VPC, same port).
2. **Production listener** (`:443`) — points at the *active* target group.
3. **Optional test listener** (`:8080`) — lets you validate green before cutover.
4. **ECS service** with `deploymentController.type = CODE_DEPLOY`.
5. **CodeDeploy application** (compute platform `ECS`) + **deployment group**
   referencing the cluster, service, both target groups, and both listeners.

## The flip (what CodeDeploy does)

1. Provision the **green** task set with the new task definition.
2. Register green tasks with `tg-green`.
3. (Optional) Route test traffic to green; run `AfterAllowTestTraffic` hook.
4. Run `BeforeAllowTraffic` validation.
5. **Reroute the production listener** from `tg-blue` → `tg-green`.
6. Run `AfterAllowTraffic` validation.
7. Wait the **termination period** (e.g. 5 min) — instant rollback window.
8. Terminate the blue task set.

## Create the deployment group (CLI)

```bash
aws deploy create-deployment-group \
  --application-name my-app \
  --deployment-group-name my-app-bg \
  --service-role-arn arn:aws:iam::123456789012:role/CodeDeployECSRole \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --ecs-services clusterName=production-cluster,serviceName=my-app-svc \
  --load-balancer-info '{
    "targetGroupPairInfoList": [{
      "targetGroups": [{"name":"tg-blue"},{"name":"tg-green"}],
      "prodTrafficRoute": {"listenerArns": ["arn:...:listener/prod"]},
      "testTrafficRoute": {"listenerArns": ["arn:...:listener/test"]}
    }]
  }' \
  --blue-green-deployment-configuration '{
    "terminateBlueInstancesOnDeploymentSuccess": {
      "action": "TERMINATE", "terminationWaitTimeInMinutes": 5
    },
    "deploymentReadyOption": {"actionOnTimeout": "CONTINUE_DEPLOYMENT"}
  }' \
  --deployment-style '{
    "deploymentType": "BLUE_GREEN",
    "deploymentOption": "WITH_TRAFFIC_CONTROL"
  }'
```

➡️ Full conceptual deep dive: [../../docs/blue-green-deployment.md](../../docs/blue-green-deployment.md)

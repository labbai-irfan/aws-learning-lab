// CodeDeploy Lambda pre-traffic hook.
// Runs BEFORE traffic shifts to the new version. Must call
// PutLifecycleEventHookExecutionStatus with Succeeded/Failed,
// otherwise CodeDeploy times out and rolls back.
const { CodeDeployClient, PutLifecycleEventHookExecutionStatusCommand } =
  require('@aws-sdk/client-codedeploy');
const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');

const codedeploy = new CodeDeployClient({});
const lambda = new LambdaClient({});

exports.handler = async (event) => {
  const { DeploymentId, LifecycleEventHookExecutionId } = event;
  let status = 'Succeeded';

  try {
    // Invoke the NEW version directly and assert it behaves.
    const res = await lambda.send(new InvokeCommand({
      FunctionName: 'my-api-handler:2', // target version
      Payload: Buffer.from(JSON.stringify({ healthcheck: true })),
    }));
    const payload = JSON.parse(Buffer.from(res.Payload).toString());
    if (payload.statusCode !== 200) {
      status = 'Failed';
      console.error('Pre-traffic validation failed:', payload);
    }
  } catch (err) {
    status = 'Failed';
    console.error('Pre-traffic hook error:', err);
  }

  await codedeploy.send(new PutLifecycleEventHookExecutionStatusCommand({
    deploymentId: DeploymentId,
    lifecycleEventHookExecutionId: LifecycleEventHookExecutionId,
    status, // 'Succeeded' allows traffic shift; 'Failed' aborts + rolls back
  }));

  return status;
};

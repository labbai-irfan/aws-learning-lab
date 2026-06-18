/**
 * HRMS application instrumentation for CloudWatch.
 *
 * Express middleware that, for every request, emits ONE structured JSON log line
 * in Embedded Metric Format (EMF). CloudWatch:
 *   - stores the line in the /hrms/api log group (queryable in Logs Insights), AND
 *   - auto-extracts metrics into the HRMS/App namespace (no extra PutMetricData calls).
 *
 * Metrics produced (dimensions: route):
 *   RequestCount, ErrorCount, LatencyMs
 * Plus business helpers: recordLoginResult(), recordPayrollRun().
 *
 * Ship stdout to CloudWatch via the CloudWatch agent (EC2) or awslogs driver (containers).
 */

const NAMESPACE = 'HRMS/App';
const ENV = process.env.NODE_ENV || 'prod';

/** Build an EMF document so CloudWatch extracts the named metrics. */
function emf(metrics, dimensions, fields) {
  return JSON.stringify({
    _aws: {
      Timestamp: Date.now(),
      CloudWatchMetrics: [
        {
          Namespace: NAMESPACE,
          Dimensions: [Object.keys(dimensions)],
          Metrics: metrics.map((m) => ({ Name: m.name, Unit: m.unit })),
        },
      ],
    },
    ...dimensions,
    ...Object.fromEntries(metrics.map((m) => [m.name, m.value])),
    ...fields,
  });
}

/** Express middleware: time the request and emit metrics + a structured log line. */
function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  const requestId = req.headers['x-request-id'] || cryptoRandom();

  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    const isError = res.statusCode >= 500;
    // route template, not the raw URL, to keep metric cardinality bounded
    const route = (req.route && req.route.path) || req.baseUrl || 'unknown';

    const line = emf(
      [
        { name: 'RequestCount', unit: 'Count', value: 1 },
        { name: 'ErrorCount', unit: 'Count', value: isError ? 1 : 0 },
        { name: 'LatencyMs', unit: 'Milliseconds', value: Math.round(ms) },
      ],
      { route, Env: ENV },
      {
        level: isError ? 'error' : 'info',
        method: req.method,
        statusCode: res.statusCode,
        ms: Math.round(ms),
        requestId,
        msg: isError ? 'request failed' : 'request ok',
      }
    );
    // stdout -> CloudWatch agent / awslogs -> /hrms/api
    process.stdout.write(line + '\n');
  });

  req.requestId = requestId;
  next();
}

/** Business metric: login success/failure -> alarm on LoginSuccessRate. */
function recordLoginResult(success) {
  process.stdout.write(
    emf(
      [
        { name: 'LoginAttempt', unit: 'Count', value: 1 },
        { name: 'LoginSuccess', unit: 'Count', value: success ? 1 : 0 },
      ],
      { Env: ENV },
      { level: 'info', msg: 'login', success }
    ) + '\n'
  );
}

/** Business metric: a payroll run completed. */
function recordPayrollRun(employees, payPeriod) {
  process.stdout.write(
    emf(
      [{ name: 'PayrollRunCount', unit: 'Count', value: 1 },
       { name: 'PayrollEmployees', unit: 'Count', value: employees }],
      { Env: ENV },
      { level: 'info', msg: 'payroll run', payPeriod, employees }
    ) + '\n'
  );
}

function cryptoRandom() {
  return require('crypto').randomBytes(8).toString('hex');
}

module.exports = { metricsMiddleware, recordLoginResult, recordPayrollRun };

/* ------------------------------------------------------------------ *
 * Usage in your Express app:
 *
 *   const { metricsMiddleware, recordLoginResult } = require('./app-instrumentation');
 *   app.use(metricsMiddleware);
 *
 *   app.post('/api/login', async (req, res) => {
 *     const ok = await auth(req.body);
 *     recordLoginResult(ok);
 *     res.status(ok ? 200 : 401).json({ ok });
 *   });
 *
 * Then create metric filters / alarms on HRMS/App ErrorCount, LatencyMs (p99),
 * and LoginSuccess vs LoginAttempt (rate) — see project/alarms.sh and Module 8.
 * ------------------------------------------------------------------ */

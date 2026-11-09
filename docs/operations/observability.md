---
icon: lucide/activity
---

# Observability

Observability makes it possible to understand a request without reproducing it
locally. The platform should cover logs, metrics and traces across the Gateway
and every downstream service.

## Signals

### Logs

Emit structured JSON logs with:

- UTC timestamp and severity;
- service and environment;
- request or trace ID;
- HTTP method, route template and status;
- duration in milliseconds;
- dependency name and outcome when applicable.

Do not log passwords, access tokens, API keys, full authorization headers or
unredacted personal data.

### Metrics

At minimum, expose:

| Metric | Purpose |
| --- | --- |
| Request count by route and status | Traffic and error rate |
| Request latency percentiles | User-facing performance |
| In-flight requests | Saturation |
| Dependency failures and latency | Locate slow downstream services |
| Database connection pool usage | Detect persistence pressure |
| Pod CPU and memory | Capacity and autoscaling |
| Exchange provider rate and failures | Monitor external dependency |

Use low-cardinality labels. Never use user IDs, order IDs or unrestricted URLs
as metric labels.

### Traces

Propagate a trace context from Gateway through Product, Order, Account, Auth and
Exchange. A trace for `POST /orders` should show product lookup, persistence
and any exchange call as separate spans.

## Health endpoints

Every service should provide:

- **liveness**: the process is running;
- **readiness**: the service can receive traffic and required dependencies are
  available;
- **info/version**: build version and commit identifier without secrets.

Readiness should be used by load balancers and Kubernetes; liveness must not
restart a service merely because an optional external provider is temporarily
unavailable.

## Dashboards and alerts

Create dashboards for traffic, errors, latency, saturation and dependency
health. Alert on symptoms such as elevated 5xx rate, failed readiness checks,
high latency, pod restarts and database exhaustion. Every alert must link to a
runbook and identify an owner.

Prometheus and Grafana are suitable options for metrics and dashboards. The
specific tools are an implementation decision and must be recorded with
retention, access and cost assumptions.

## Browser observability integration

The three web applications integrate **Grafana Faro** for browser errors,
performance and tracing, and **Umami** for demo product-usage analytics. The
[frontend PWA and observability plan](../frontend/pwa-observability.md) defines
application identities, sanitized events, environment variables, deployment
choices and verification. Collection is disabled by default. Backend URLs,
hosting and retention remain to be confirmed at CDN deployment; admin usage
analytics are excluded.

The store is a simulation. Analytics must describe **demo orders**, never real
payments or revenue, and must exclude credentials, personal identifiers and
raw search/order/account URLs.

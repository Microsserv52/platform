---
icon: lucide/list-checks
---

# Service observability requirements

These requirements apply to every business service and frontend. Service owners
apply them in their own repositories. The platform repository does not commit
changes under `api/`; it provides the collectors, dashboards, alerts and
deployment-side OpenTelemetry injection.

## Required per service

| Requirement | Contract |
| --- | --- |
| Health | `/actuator/health` (Spring) or `/health` (Exchange), with liveness and readiness semantics |
| Metrics | `/actuator/prometheus` (Spring) or `/metrics` (Exchange), Prometheus text format |
| Metrics labels | `application`, `service`, `method`, `uri`/route template, `status`, `outcome`; no user IDs, order IDs or raw URLs |
| Traces | OTLP gRPC to Alloy on `4317`; W3C `traceparent` propagation between Gateway and downstream services |
| Trace resources | `service.name`, `service.version`, `deployment.environment`, `service.namespace=microsserv52` |
| Logs | Structured JSON with UTC timestamp, level, service, request/trace ID, route and status |
| Secrets | Never log passwords, tokens, API keys, cookies, authorization headers or signed upload URLs |
| Sampling | Parent-based trace sampling; start at 20% locally and tune in production |
| Failure isolation | A telemetry backend outage must not fail readiness or block a business request |
| SLO | Availability 99.5%, p95 latency target by endpoint; see [Costs, PaaS and SLA](../infrastructure/costs.md#sla-and-slo) |
| Alerts | Every page alert has `severity`, `owner` and a `runbook_url` |

## Frontends

| Requirement | Contract |
| --- | --- |
| Faro | Initialize once when `NEXT_PUBLIC_ENABLE_TELEMETRY=true` and a Faro URL exists |
| Privacy | Respect opt-out and Do Not Track; strip query strings, user metadata, private routes and raw errors |
| Trace propagation | Public catalog only until private-route CORS/privacy review is complete |
| Environment | `NEXT_PUBLIC_APP_ENV` and `NEXT_PUBLIC_APP_VERSION` identify the release |
| Failure isolation | Faro import or send failure must not block rendering or checkout |

## Current status

| Service | Metrics | Logs | Traces | Profiles | Owner action |
| --- | --- | --- | --- | --- | --- |
| Gateway | yes | yes | OTel Java agent | not enabled | add Pyroscope agent if approved |
| Auth | yes | yes | OTel Java agent | not enabled | add Pyroscope agent if approved |
| Account | yes | yes | OTel Java agent | not enabled | add Pyroscope agent if approved |
| Order | yes | yes | OTel Java agent | not enabled | add Pyroscope agent if approved |
| Product | yes | yes | OTel Java agent | not enabled | add Pyroscope agent if approved |
| Exchange | yes | yes | **pending** | pending | add OTel Python packages and `opentelemetry-instrument` in its repo |
| Landing / Store / Admin | n/a | n/a | Faro configured for local builds | n/a | set the production Faro URL when an AWS HTTPS ingest path exists |

The Java agent is injected by `compose.observability.yml` and
`k8s/base/otel-instrumentation.yaml`; metrics stay on the Micrometer endpoint.
See [OpenTelemetry for services](https://github.com/Microsserv52/platform/blob/main/observability/otel/README.md).

## Local verification

```bash
scripts/observability-up.sh
curl -fsS http://localhost:3000/api/health
curl -fsS 'http://localhost:3200/api/search?tags=service.name%3Dgateway&limit=1'
curl -fsS 'http://localhost:9009/prometheus/api/v1/query?query=up'
```

A service is not complete until it appears in Prometheus targets, Tempo traces,
Loki logs and the **Service RED** dashboard.

## Related

- [Observability](../operations/observability.md)
- [Grafana on AWS](../operations/grafana-aws.md)
- [Service contracts](contracts.md)

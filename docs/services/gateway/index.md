---
icon: lucide/route
---

# Gateway

![Tech Stack](https://skillicons.dev/icons?i=java,spring,postgres,docker,kubernetes,grafana,prometheus)

The Gateway is the platform's single public entry point. It routes requests to
internal services and prevents clients from depending on internal hostnames or
ports.

## Responsibilities

- Route Product, Order, Exchange, Auth and Account requests.
- Forward the authenticated identity and relevant request headers.
- Apply cross-cutting concerns such as CORS, request limits and access logs.
- Return consistent errors without exposing internal service details.
- Provide a health endpoint that does not require user authentication.

## Implementation

The implementation is tracked in the [`api/gateway`](../../../api/gateway/)
submodule. Spring Cloud Gateway MVC routes Auth, Account, Order, Product and
Exchange and validates JWTs at the API boundary. Catalog GETs, registration,
login/CSRF preparation and health are public. Product writes and account
administration require ROLE_ADMIN; orders and own profile require authentication.

Static frontends call `/api/session/*` through the local edge. Gateway owns the
HttpOnly session cookie and CSRF checks; no Next.js session server is required.
See [browser sessions and authorization](../../frontend/architecture.md#api-owned-browser-sessions)
for the endpoint table, cookie configuration and real-service acceptance limits.

## Observability requirements

| Signal | Requirement | Current |
| --- | --- | --- |
| Health | `/actuator/health` with liveness/readiness semantics | implemented |
| Metrics | `/actuator/prometheus` with low-cardinality route/status labels | implemented |
| Traces | OTLP to Alloy, W3C `traceparent` propagation | OTel Java agent |
| Logs | structured JSON with service, request/trace ID, route and status | implemented |
| Profiles | Pyroscope agent where approved | not enabled |

See [Service observability requirements](../observability-requirements.md) for
the full contract, redaction rules and verification commands.

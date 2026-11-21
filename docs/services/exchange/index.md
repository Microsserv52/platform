---
icon: lucide/dollar-sign
---

# Exchange

API that allows users to convert between currencies. The API must use a third-party service to fetch exchange rates.

## Implementation

This microservice is implemented in Python using the [FastAPI](https://fastapi.tiangolo.com/) framework.

The service should isolate the external provider behind an adapter, validate
currency codes and return a stable platform response even if the provider's
payload changes. The provider and credentials must be configurable.

This service follows the [Exchange API exercise](https://insper.github.io/platform/2026.2/exercises/exchange/).

## Observability requirements

| Signal | Requirement | Current |
| --- | --- | --- |
| Health | `/health` with liveness/readiness semantics | implemented or planned with the service |
| Metrics | `/metrics` with low-cardinality route/status labels | implemented or planned with the service |
| Traces | OTLP to Alloy, W3C `traceparent` propagation | pending Python OTel integration |
| Logs | structured JSON with service, request/trace ID, route and status | implemented or planned |
| Profiles | Pyroscope agent where approved | pending |

See [Service observability requirements](../observability-requirements.md) for
the full contract, redaction rules and verification commands.

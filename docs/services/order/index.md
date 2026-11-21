---
icon: lucide/shopping-cart
---

# Order

Orders are tied to authenticated users and reference existing products

Order stores monetary values in USD. It calls Product to validate items and
obtain prices, and calls Exchange only when a client requests another currency.

## Implementation

This microservice is implemented in Java using the [Spring Boot](https://spring.io/projects/spring-boot) framework.

The reusable Java contract is tracked in the [`api/order`](../../../api/order/)
submodule. The implementation and persistence layer are tracked in
[`api/order-service`](../../../api/order-service/). See
[Endpoints](endpoints.md) for the contract and
[Developing](../../development/developing.md) for the local workflow.

This service follows the [Order API exercise](https://insper.github.io/platform/2026.2/exercises/order/).

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

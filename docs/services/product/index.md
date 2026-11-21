---
icon: lucide/package
---

# Product

Product owns the product catalogue: product identity, display name, price, unit
and an optional image.

The [image flow](images.md) covers the S3-backed upload contract, database
tables and delivery configuration implemented by the Product service.

RESTful API for an online store

This service owns the product catalogue: product identity, display name,
price and unit. Product data is consumed by Order when an order is created.

## Implementation

This microservice is implemented in Java using the [Spring Boot](https://spring.io/projects/spring-boot) framework.

The service is tracked in [`api/product`](../../../api/product/) and its
reusable contract in [`api/product-interface`](../../../api/product-interface/).
See [Endpoints](endpoints.md) for the contract, the
[image handoff](images.md) for the image flow and
[Developing](../../development/developing.md) for the local workflow.

This service follows the [Product API exercise](https://insper.github.io/platform/2026.2/exercises/product/).

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

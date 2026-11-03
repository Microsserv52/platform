---
icon: lucide/shopping-cart
---

# Order

Orders are tied to authenticated users and reference existing products

Order stores monetary values in USD. It calls Product to validate items and
obtain prices, and calls Exchange only when a client requests another currency.

## Implementation

This microservice is implemented in Java using the [Spring Boot](https://spring.io/projects/spring-boot) framework.

The Java service is tracked in the [`api/order`](../../../api/order/) submodule.
The integration/service-layer repository is tracked in
[`api/order-service`](../../../api/order-service/). See [Endpoints](endpoints.md)
for the contract and [Developing](../../development/developing.md) for the
local workflow.

This service follows the [Order API exercise](https://insper.github.io/platform/2026.2/exercises/order/).

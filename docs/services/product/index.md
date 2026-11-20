---
icon: lucide/package
---

# Product

Product owns the product catalogue: product identity, display name, price, unit
and an optional image.

The [image implementation handoff](images.md) records the approved S3/CloudFront
design, migrations, upload contract and acceptance work; the implementation now
lives in the Product service below.

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

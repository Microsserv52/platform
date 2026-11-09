---
icon: lucide/package
---

# Product

The Product source repository will be created later. The
[image implementation handoff](images.md) records the approved S3/CloudFront
design, migrations, upload contract and acceptance work for that service.

RESTful API for an online store

This service owns the product catalogue: product identity, display name,
price and unit. Product data is consumed by Order when an order is created.

## Implementation

This microservice is implemented in Java using the [Spring Boot](https://spring.io/projects/spring-boot) framework.

The implementation repository is not included in the current platform snapshot.
The required contract is documented in [Endpoints](endpoints.md).

This service follows the [Product API exercise](https://insper.github.io/platform/2026.2/exercises/product/).

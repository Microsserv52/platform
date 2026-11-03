---
icon: lucide/code
---

# Developing

## Repository layout

```text
api/
  gateway/        Gateway submodule
  order/          Java Order API submodule
  order-service/  Order integration/service-layer submodule
docs/             Zensical documentation
  project/        Scope, organization and delivery
  development/    Local development and CI/CD
  infrastructure/ AWS, EKS, deployment and costs
  operations/     Observability, performance and load testing
  services/       Service contracts and endpoint reference
compose.yml       Local service topology
zensical.toml     Documentation configuration
.github/workflows/ CI and GitHub Pages workflow
```

## Service boundaries

Keep business logic inside the service that owns the data. A service may call
another service through its HTTP contract, but must not import its persistence
models. In particular, Order obtains product information from Product and
exchange rates from Exchange.

The current Java Order submodule uses Spring Boot and OpenFeign. Its client
contract is visible in `api/order/src/main/java/Microsserv52/order/OrderController.java`;
the complete endpoint behavior is specified in [Order API](../services/order/endpoints.md).

## Local workflow

1. Create or update the relevant service submodule.
2. Add or update unit and integration tests.
3. Run the service's formatter, tests and build.
4. Update the service documentation and contract examples.
5. From the root, build the documentation with `uv run zensical build --clean`.
6. Review the rendered pages and the final Git diff.

Do not commit generated `site/` output, Maven `target/` output or credentials.

## Contract changes

When an endpoint or payload changes, update the owning service page and
[Service Contracts](../services/contracts.md) in the same change. Document
authentication, status codes, validation rules and an example request and
response.

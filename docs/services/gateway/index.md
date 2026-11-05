---
icon: lucide/route
---

# Gateway

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
Exchange, validates the JWT at the public boundary, and exposes only the
health endpoint without authentication.

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

## Current status

The Gateway implementation is not present in this repository snapshot. The
compose topology expects an image named `Microsserv52-gateway`. Its public
routes and upstream mapping must be documented here when the service contract
is finalized.

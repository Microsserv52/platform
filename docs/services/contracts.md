---
icon: lucide/file-text
---

# Service contracts

This section describes the contracts used by the platform. A contract defines
the HTTP method, path, authentication requirements, payloads, status codes and
failure behavior that consumers can rely on.

## Common rules

- JSON is used for request and response bodies.
- IDs are UUIDs.
- Monetary values are decimal numbers, stored in USD by Order.
- Protected requests carry the token issued by Auth.
- A service owns its data and exposes it through its API.
- Error responses should include a stable machine-readable code and a human
  readable message.

## Service-to-service calls

| Caller | Callee | Purpose |
| --- | --- | --- |
| Gateway | Auth, Account, Product, Order, Exchange | Route and protect public requests |
| Auth | Account | Load account credentials and identity |
| Order | Product | Validate products and obtain prices at checkout |
| Order | Exchange | Convert order totals requested in another currency |

See the detailed endpoint pages for [Product](product/endpoints.md),
[Order](order/endpoints.md) and [Exchange](exchange/endpoints.md).

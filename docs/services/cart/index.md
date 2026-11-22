---
icon: lucide/shopping-cart
---

# Cart service and Redis

Cart is not implemented. There is no Cart repository, API route, Redis client or
cart data model in this platform. The Store keeps its cart in browser storage
under `ms52-cart-v1`; the cart does not leave the browser and the Store PWA
remains online-only.

Redis is provisioned as a shared cache endpoint, but no service uses it for carts
or service-level caching, and `CACHE_ENABLED` is `false` in the deployed
ConfigMap. The shared Redis instance has one eviction and persistence policy for
every consumer; it does not provide per-service isolation.

`POST /orders` accepts item IDs and quantities from the client. Order reads
product prices through Product and persists the resulting demo order in
PostgreSQL. No cart snapshot, cart merge, guest-cart capability or checkout
clearing flow exists.

## Observability

There is no Cart service to instrument, so there are no Cart health, metrics,
traces, logs or profiles. The [service observability
requirements](../observability-requirements.md) define the contract a future
Cart service would meet.

## Related

- [Architecture](../../project/architecture.md)
- [Order API](../order/index.md)
- [Product API](../product/index.md)
- [Service contracts](../contracts.md)

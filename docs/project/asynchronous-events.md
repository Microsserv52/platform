---
icon: lucide/workflow
---

# Asynchronous events

Kafka is not implemented. The repository has no broker, topic, producer,
consumer, outbox table, relay or Kafka client dependency, and no service
publishes or consumes domain events.

| Flow | Current behavior |
| --- | --- |
| Order creation | `POST /orders` validates the request, reads prices through Product and commits the demo order to PostgreSQL in the request. No `order.created` event or outbox row is written. |
| Product images | Upload validation and metadata persistence run synchronously. There is no pending/ready queue, variant worker or asynchronous status endpoint. |
| Cart | No Cart service or Redis cart data exists. |
| Redis | Redis is provisioned as a shared cache endpoint with `CACHE_ENABLED=false`; it is not used as an event transport. |

Post-order work therefore stays in the request path, and a failure after the
order commit is not retried by a relay. There is no consumer lag, dead-letter
topic, replay procedure or event-schema compatibility policy to operate.

## Monitoring

The self-hosted Grafana stack monitors HTTP, JVM, container and trace signals.
It has no Kafka, outbox, consumer-lag or dead-letter metrics because no event
transport exists.

## Related

- [Architecture](architecture.md)
- [Order API](../services/order/index.md)
- [Product images](../services/product/images.md)
- [Cart](../services/cart/index.md)

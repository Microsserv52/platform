---
icon: lucide/dollar-sign
---

# Exchange

API that allows users to convert between currencies. The API must use a third-party service to fetch exchange rates.

## Implementation

This microservice is implemented in Python using the [FastAPI](https://fastapi.tiangolo.com/) framework.

The service should isolate the external provider behind an adapter, validate
currency codes and return a stable platform response even if the provider's
payload changes. The provider and credentials must be configurable.

This service follows the [Exchange API exercise](https://insper.github.io/platform/2026.2/exercises/exchange/).

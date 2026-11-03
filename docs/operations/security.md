---
icon: lucide/shield
---

# Security

## Trust boundaries

Clients access the platform through the Gateway. Internal services are not
intended to be directly exposed to the Internet. Auth issues tokens, Account
owns user data, and each service validates the authenticated identity before
serving protected data.

## Required controls

- Require authentication for Product, Order and Exchange endpoints.
- Enforce ownership: a user can only read their own orders.
- Validate UUIDs, quantities, prices, currency codes and request sizes.
- Never trust prices supplied by an order client; read the current Product price.
- Store passwords using a slow, salted password hash and never log credentials
  or tokens.
- Keep database and provider credentials in environment variables or a secret
  manager.
- Use TLS at the public boundary and restrict internal network access.
- Return safe error messages without stack traces or secrets.
- Add rate limits to login and externally exposed endpoints.

## Configuration warning

The sample `compose.yml` contains development database credentials. Replace
them before using the stack outside a local environment.

Security issues should be reported privately to the repository maintainers and
must not be disclosed in an issue before a fix is available.

---
icon: lucide/lock-keyhole
---

# Auth

Auth authenticates users and manages the tokens used by protected platform
requests.

## Responsibilities

- Authenticate credentials through a login flow.
- Issue short-lived access tokens with the user identity and roles.
- Validate token signature, expiry and issuer.
- Provide the identity required by downstream services.
- Keep credentials and signing keys out of logs and source control.

## Integration contract

Gateway sends authentication requests to Auth and forwards the resulting
identity to Product, Order and Exchange. Auth reads account data through the
Account service; it must not access the Account database directly.

## Implementation

The implementation is tracked in the [`api/auth`](../../../api/auth/)
submodule. `POST /auth/login` validates credentials through Account and issues
a short-lived HMAC-signed JWT. The signing secret and internal service secret
are supplied through environment variables.

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

## Current status

The Auth implementation and its endpoint contract are not present in this
repository snapshot. The compose topology expects an image named
`Microsserv52-auth`. Add the login, token validation and failure-response
examples when that service is integrated.

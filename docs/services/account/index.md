---
icon: lucide/user-round
---

# Account

Account owns registration and user profile data. It is the source of identity
data consumed by Auth and must not expose password hashes to clients.

## Responsibilities

- Register users with validated input.
- Store account data and password hashes securely.
- Return the minimum profile data required by Auth and the application.
- Support the authorization roles used by the platform.
- Expose health and readiness information for deployment.

## Integration contract

Auth calls Account to load credentials and user status. Gateway routes public
account operations. Other business services receive the authenticated user
identity from Gateway/Auth rather than querying Account directly.

## Current status

The Account implementation and endpoint contract are not present in this
repository snapshot. The compose topology expects an image named
`Microsserv52-account`. Document its registration, profile and error responses
when the service is integrated.

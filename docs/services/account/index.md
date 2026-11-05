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

## Implementation

The implementation is tracked in the [`api/account`](../../../api/account/)
submodule. It follows the hands-on split between the HTTP resource, domain
entity and persistence repository. Registration is public, profile reads and
deletion require a JWT, and Auth accesses credentials through the protected
internal header.

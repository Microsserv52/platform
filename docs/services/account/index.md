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
entity and persistence repository. Registration is public and always creates
ROLE_USER. `GET /accounts/me` returns the authenticated caller's profile.
Account list/detail/deletion require ROLE_ADMIN; deleting self or another
administrator is rejected with 409. The admin frontend exposes read-only account
details. Auth accesses credentials through the protected internal header;
Gateway blocks that internal route from public clients. See the
[frontend authorization boundary](../../frontend/architecture.md#api-owned-browser-sessions).

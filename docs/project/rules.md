---
icon: lucide/scale
---

# Engineering rules

These rules keep independently developed services interoperable and make the
project easier to operate and assess.

## API rules

- Use resource-oriented paths and the HTTP method that matches the operation.
- Return JSON for API payloads and document every public endpoint.
- Use UUIDs for resource identifiers.
- Return the documented status code for success and failure.
- Validate all client input at the service boundary.
- Do not expose persistence entities as an accidental public contract.
- Include a stable error code and safe message in error responses.
- Keep backward compatibility when possible; announce breaking changes.

## Domain rules

- Product owns product names, units, prices and availability.
- Order owns orders and enforces order ownership.
- Order stores monetary values in USD and performs conversion only through
  Exchange.
- Clients cannot provide or override the price used for an order.
- Auth owns token issuance and validation; Account owns user data.
- Services communicate over documented HTTP contracts, not shared databases.

## Security rules

- Authentication is required for protected endpoints.
- Authorization is checked on every request that accesses user-owned data.
- Secrets are supplied through environment variables or a secret manager.
- Passwords, tokens, API keys and provider responses containing secrets must
  never be logged.
- Use least-privilege IAM and Kubernetes permissions.
- Use TLS at public boundaries and restrict internal network traffic.

## Reliability rules

- Add timeouts to every outbound request.
- Use bounded retries only for safe, transient failures.
- Make writes idempotent where a client may retry.
- Expose health and readiness checks separately.
- Fail explicitly when a dependency is unavailable; do not return fabricated
  success responses.

## Documentation rules

- Update docs in the same pull request as a contract or behavior change.
- Mark planned behavior as planned; distinguish it from deployed behavior.
- Include commands, prerequisites, configuration and verification evidence.
- Record architecture decisions and operational incidents.

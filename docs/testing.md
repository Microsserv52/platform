---
icon: lucide/badge-check
---

# Testing strategy

Testing is layered so failures are fast to diagnose and the integrated system
is still verified.

| Layer | Scope | Examples |
| --- | --- | --- |
| Unit | One class, function or adapter | Validation, price calculation |
| Contract | Request and response compatibility | Product and Exchange clients |
| Integration | Service plus database/dependencies | Order persistence |
| Smoke | Deployed health and critical path | Login, product, order |
| Load | Capacity and saturation | HPA and Gateway |
| Security | Access control and safe failure | Ownership and token expiry |

Every service should run its unit tests in its own repository. The integration
repository should run a small cross-service smoke suite against Compose or a
test environment. Keep test data isolated and never use production credentials.

Record failures with the commit, environment, command, logs and remediation.

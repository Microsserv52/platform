---
icon: lucide/users-round
---

# Repository and organization

## Repository model

The root repository is the integration repository. Individual services are
developed in their own GitHub repositories and included here as Git submodules.
This keeps service ownership and release history independent while providing a
single place to run the complete platform.

| Path | Role |
| --- | --- |
| [`api/gateway`](../api/gateway/) | Gateway submodule |
| [`api/order`](../api/order/) | Java Order API submodule |
| [`api/order-service`](../api/order-service/) | Order service-layer submodule |
| `docs/` | Project and service documentation |
| `compose.yml` | Local service topology |
| `.github/workflows/` | Repository automation |

Product, Exchange, Auth and Account repositories are expected by the platform
architecture but are not currently present as submodules in this snapshot.

## Ownership

Each service should have a named maintainer and at least one reviewer from
another service area. The group should agree on ownership before implementation:

| Area | Primary responsibilities |
| --- | --- |
| Gateway | Routing, public API boundary and edge policies |
| Auth | Credentials, tokens, roles and token validation |
| Account | User registration and profile data |
| Product | Product catalogue, prices and product lifecycle |
| Order | Order lifecycle, ownership and totals |
| Exchange | Provider adapter, rates and currency validation |
| Platform | Containers, AWS/EKS, CI/CD, load tests and observability |
| Documentation | Contracts, runbooks, decisions and delivery evidence |

Ownership does not remove shared responsibility: every member must understand
the complete request flow and be able to explain the implementation.

## Contribution workflow

1. Create a branch named `feature/<short-description>`,
   `fix/<short-description>` or `docs/<short-description>`.
2. Make changes in the owning repository or submodule.
3. Add tests and update the relevant contract documentation.
4. Open a pull request with verification evidence.
5. Review and merge the service repository first.
6. Update the submodule pointer in this integration repository.
7. Run the full integration and documentation checks.

Never commit directly to `main` and never commit credentials, generated build
outputs or local environment files.

## Submodule commands

```bash
git submodule update --init --recursive
git -C api/order status
git -C api/order log -1 --oneline
git add api/order
git commit -m "Update order service"
```

The root commit records a submodule commit, not a copy of the submodule files.
When a submodule is unavailable, document the missing repository and its
expected contract instead of adding placeholder implementation.

---
icon: lucide/panels-top-left
---

# Frontend applications

The initial implementation is merged. The selected
[product image architecture](product-images.md) adds URL-based rendering and
admin image management, with S3 integration deferred to the future Product
service. Upload controls are enabled only in explicit fixture mode until then.

Three independent Next.js repositories are integrated as Git submodules and
implemented for static CDN export. The local Docker setup serves them on one
origin. **This is an educational mock store: no real payments or transactions
occur, and no goods are shipped.** Demo orders are API records, not purchases.

## Agreed decisions

- English UI, shared modern branding and the existing project logo.
- Public catalog browsing; authentication to create or read own demo orders.
- Next.js, TypeScript, MUI/Emotion, Tailwind and the approved TanStack/form/test tools.
- antislop applied during implementation; reference research and defaults authorized.
- Each app has a Dockerfile for local testing; no frontend Kubernetes manifests.
- Production will use CDN hosting with separate per-app environment values.
  Ask the owner about provider, origin routing and variables before deployment.
- Additional libraries always require owner approval. No date library, queue
  framework, animation stack or 21st.dev runtime dependency was added.

## Sites and content

| Repository / submodule                 | Path      | Implemented experience                                                                                                                                                                |
| -------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Microsserv52/landing` / `web/landing` | `/`       | Demo introduction, live catalog preview, platform explanation, privacy/diagnostic controls and documentation links                                                                    |
| `Microsserv52/store` / `web/store`     | `/store/` | Public search/sort catalog, product details, guest cart, login/register, authenticated review, demo order creation/history/details and read-only own account                          |
| `Microsserv52/admin` / `web/admin`     | `/admin/` | Role-gated overview with API-derived counts, searchable/sortable/paginated products/accounts, create/delete product dialogs, account detail dialog and configured observability links |

Detail URLs use `/store/product/?id=<uuid>` and `/store/order/?id=<uuid>`.
These work for arbitrary runtime IDs without a server-rendered Next.js route.
Admin accounts are read-only in the UI. No product editing, all-orders admin
view, stock, shipping, payment fields or revenue reports are invented.

Every screen has appropriate loading, failure and empty/access states. Shopping
copy uses “Add to demo cart” and “Create demo order”; confirmation says that no
payment was taken and no goods will be shipped. Product images are clearly
unavailable placeholders because the API has no imagery contract.

## Documentation

| Page                                          | Contents                                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------------------- |
| [Design](design.md)                           | Defaults, visual decisions, real UI references and antislop                           |
| [Architecture](architecture.md)               | Static zones, API-owned sessions, authorization and current contract limits           |
| [Dependencies](dependencies.md)               | Approved packages, exact resolved versions and official setup                         |
| [PWA and observability](pwa-observability.md) | Online-only store installation, Faro/Umami behavior and environment map               |
| [Local development and delivery](delivery.md) | Real-service versus fixture Docker modes, commands, CI and remaining integration work |
| [Verification](verification.md)               | Actual checks, browser evidence and limits                                            |

The implementation is pushed on task branches for review. Source
repositories are private. No CDN deployment or production telemetry endpoint
has been configured.

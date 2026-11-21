---
icon: lucide/panels-top-left
---

# Frontend applications

The three frontends render optional product image URLs and expose admin image
management. The Product service implements the upload flow (S3 in production, a
local mock in Compose). Upload controls are gated by
`NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS`; fixture mode enables them against the
local mock. See [Product images](product-images.md).

Three independent Next.js repositories are integrated as Git submodules and
implemented for static CDN export. The local Docker setup serves them on one
origin. **This is an educational mock store: no real payments or transactions
occur, and no goods are shipped.** Demo orders are API records, not purchases.

## Stack and boundaries

- English UI, shared branding and the existing project logo.
- Public catalog browsing; authentication to create or read own demo orders.
- Next.js, TypeScript, MUI/Emotion, Tailwind and TanStack/form/test tools.
- Each app has a Dockerfile for local testing; there are no frontend Kubernetes
  manifests.
- Observability is self-hosted (Prometheus, Mimir, Loki, Tempo, Pyroscope,
  Grafana, Alloy) with OpenTelemetry and Faro; edge security uses AWS Shield,
  CloudFront, security groups and optional AWS WAF.
- CloudFront serves the static exports with separate per-app build values. The
  current public origin is the CloudFront hostname; no custom domain is
  configured.
- No date library, queue framework, animation stack or 21st.dev runtime
  dependency is installed.

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
payment was taken and no goods will be shipped. Product images support optional
URL metadata, with explicit fallbacks. Admin upload controls appear when
`NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS` is enabled.

## Documentation

| Page                                          | Contents                                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------------------- |
| [Design](design.md)                           | Defaults, visual decisions, real UI references and antislop                           |
| [Architecture](architecture.md)               | Static zones, API-owned sessions, authorization and current contract limits           |
| [Dependencies](dependencies.md)               | Approved packages, exact resolved versions and official setup                         |
| [PWA and observability](pwa-observability.md) | Online-only store installation, Faro/Umami behavior and environment map               |
| [Local development and delivery](delivery.md) | Real-service versus fixture Docker modes, commands, CI and integration boundaries |
| [Verification](verification.md)               | Actual checks, browser evidence and limits                                            |

All ten source repositories are public. There is no custom domain or production
Faro endpoint; the local stack uses the Alloy receiver.

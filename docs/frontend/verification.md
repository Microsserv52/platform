---
icon: lucide/clipboard-check
---

# Frontend verification

The three static applications are verified by formatting, ESLint, TypeScript,
Vitest, static export and Playwright browser suites. The browser suites run
Chromium desktop and Pixel 5 profiles against the exported files and explicit API
fixtures. The Docker images and `compose.frontend-demo.yml` serve `/`, `/store/`,
`/admin/` and `/api/` on `localhost:8081`.

## Automated checks

| Check | Current state |
| --- | --- |
| Formatting, lint and types | Pass in landing, store and admin |
| Unit tests | Five Vitest tests per application |
| Static export | Pass in all three applications |
| Browser suites | Landing, store and admin pass desktop and mobile fixture flows |
| Docker | All three Dockerfiles build; fixture Compose serves the three zones and `/api/` |
| Runtime dependencies | `npm audit --omit=dev --audit-level=moderate` reports no production findings |
| Development dependencies | Eight moderate findings through ESLint's `minimatch` dependency; see [Dependencies](dependencies.md) |
| Java services | Gateway and Account pass their Maven test and coverage checks |

## Browser coverage

| Area | Covered behavior |
| --- | --- |
| Navigation | Landing catalog to store, product detail, cross-zone privacy and home links, skip link and mobile drawer |
| Catalog | Search, price sort, product cards, missing-product state and 404 recovery |
| Cart | Add, quantity, reload persistence and remove; the cart is browser storage |
| Authentication | Empty-field validation, fixture sign-in, sign-out and authenticated navigation |
| Orders | Guest checkout redirect, pending submit state, order detail and demo-only notices |
| Account | Own profile, account detail dialog and restricted access |
| Administration | Administrator denial for ordinary users, overview counts, product create/search/delete, sorting and pagination |
| Themes | Light and dark surfaces across catalog, dialogs and admin tables |
| Layout | 390px and 1280px viewports without page overflow; wide admin tables scroll inside their container |
| Observability | Opt-out control and explicit unconfigured-dashboard messages |
| Errors | Missing product, custom 404, validation feedback and no uncaught browser errors |

The fixtures are disposable and visibly labeled. They do not prove backend
authorization, persistence or production security.

## Accessibility and visual constraints

The theme tokens meet WCAG AA contrast for primary and secondary text, accents,
placeholders and button labels in both themes. Controls use MUI focus, keyboard
and disabled behavior with a 44px minimum target. Pages have labeled landmarks,
one primary heading, page titles, alt text, explicit image dimensions, reduced
motion support and unrestricted zoom. Faro is lazy-loaded and Umami loads after
interaction readiness with automatic page tracking disabled.

## Limits

- Production CloudFront, real Product/Exchange services and full-stack cookie,
  CSRF and authorization behavior are not exercised by the local fixtures.
- The CloudFront hostname is the current public origin; no custom domain or ACM
  certificate is configured.
- Production Faro and Umami collection are not verified against a public
  collector.
- Lighthouse, field Web Vitals, exhaustive assistive-technology testing and load
  testing are not measured and no performance score is claimed.
- PWA installation is verified by the manifest and icon export only; the app is
  online-only and does not cache private or API data offline.

See [Delivery](delivery.md) for the fixture and real-service modes, and
[Product image verification](image-verification.md) for the image flow.

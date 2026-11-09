---
icon: lucide/network
---

# Frontend architecture

## Source and runtime ownership

`web/landing`, `web/store` and `web/admin` are independent Git submodules. Each
owns a Next.js App Router application, strict TypeScript configuration, npm
lockfile, tests, static-export Dockerfile and CI workflows. No source imports
cross a submodule boundary and no JavaScript monorepo or module federation
runtime is introduced. Shared design/API conventions are documented centrally.

Each app uses `src/app` for routes, `src/components` for feature and shared UI,
`src/lib` for schemas/API access, and `tests/` for browser checks and fixtures.
The platform owns Compose, Nginx, the submodule commits and integration docs.
Gateway/Account own the backend changes. Kubernetes frontends are deferred.

## One domain, static zones

| Public path                                                            | Destination    | Behavior                                                       |
| ---------------------------------------------------------------------- | -------------- | -------------------------------------------------------------- |
| `/` and landing pages                                                  | Landing export | Root assets at `/_next/*`                                      |
| `/store/`                                                              | Store export   | Fixed `/store` base path; all assets/manifests remain under it |
| `/admin/`                                                              | Admin export   | Fixed `/admin` base path; independent assets                   |
| `/api/*`                                                               | Gateway        | Nginx strips `/api` only; authenticated responses use no-store |
| Legacy `/auth`, `/accounts`, `/products`, `/orders`, `/exchange` paths | Gateway        | Existing Bearer API clients remain supported                   |

Exact `/store` and `/admin` requests redirect to their slash form; prefix
matching cannot capture `/storefront`. Nginx serves actual exported paths and
returns a zone-specific 404 rather than rewriting unknown URLs to a shell.
Cross-zone links are ordinary anchors and load the destination app. Next.js
routing inside the store is used after demo order creation.

All apps use `output: 'export'`, `trailingSlash: true` and unoptimized static
images. There are no server actions, BFFs or runtime Next.js session handlers.
Product/order IDs are validated query parameters to statically exported detail
pages. Public catalog data is fetched at runtime; the initial export does not
require an available Product service or embed stale demo product data.

The approach follows official [static export](https://nextjs.org/docs/app/guides/static-exports),
[basePath](https://nextjs.org/docs/app/api-reference/config/next-config-js/basePath)
and [multi-zone](https://nextjs.org/docs/app/guides/multi-zones) guidance. The
future CDN needs equivalent path-to-origin behavior, trailing-slash/404 rules
and an API origin. Choose those with the owner at deployment time.

## API-owned browser sessions

| Gateway endpoint      | Purpose                                                                                |
| --------------------- | -------------------------------------------------------------------------------------- |
| `GET /session/csrf`   | Return the Spring CSRF token/header; establish its cookie                              |
| `POST /session/login` | Call Auth, set the access token in an HttpOnly cookie, return 204 without a token body |
| `GET /session`        | Validate the token and fetch the authenticated Account profile                         |
| `DELETE /session`     | Clear the session cookie; no refresh/revocation capability is claimed                  |

Through the public proxy these endpoints are `/api/session/*`. The host-only
`ms52-session` cookie has path `/api`, SameSite=Lax and HttpOnly. It is Secure
by default; local HTTP Compose explicitly sets `SESSION_COOKIE_SECURE=false`.
Its lifetime follows Auth's access-token expiry. The frontend never stores or
reads JWTs in localStorage, sessionStorage or a JavaScript cookie.

Spring Security's cookie CSRF repository and default request-token handler
protect cookie-authenticated writes and login. Every frontend mutation obtains
a token first. The Gateway request wrapper turns the cookie into a Bearer
header for token validation and downstream routing; explicit Bearer clients
retain their existing behavior. Upstream login/profile requests have timeouts.
The signing key stays in backend secret configuration.

Gateway maps the signed `roles` claim to authorities, requires ROLE_ADMIN for
Product writes and account list/detail/deletion, and blocks public internal
credential routes. Only GET product reads are anonymous. Account enforces its
own admin list/detail/deletion rules and exposes `GET /accounts/me` for the
authenticated user. Administrator/self deletion is rejected; account deletion
is not exposed in the frontend. Admin provisioning is an operator action,
never a registration input.

The route guard is presentation only. Tests verify backend role enforcement,
CSRF and an actual CSRF-cookie/login/profile exchange with local upstream
fixtures. Logout clears the cookie/client caches and notifies other tabs.
Receiving tabs use TanStack's [query reset](https://tanstack.com/query/latest/docs/framework/react/reference/classes/QueryClient)
to notify active subscribers and refetch session state, so an open private view
does not retain the previous profile after another tab signs out.
An already-issued token remains valid until expiry if copied elsewhere; there
is no fabricated refresh/revocation endpoint.

## State and optimization

TanStack Query owns API reads/mutations and schema-checked responses. Query
keys isolate private order data by identity; session changes reset cached data.
Reads have bounded retries/cancellation, mutations never retry automatically.
The cart stores only validated IDs/positive integer quantities under
`ms52-cart-v1`, synchronizes with browser storage and revalidates catalog data
before submission. Order receives IDs/quantities and calculates authoritative
prices. An uncertain submission directs users to order history before retry.

Search/sort operate locally on the unpaginated Product array. React deferred
rendering keeps input responsive; it is not called network debounce. TanStack
Table v9 uses explicit sorting/pagination features and 10-row pages. No virtual
list is added without evidence of a large-list rendering problem, and no
background queue is needed for the current flows. New server search/pagination,
debounce or queue packages require a separate contract/approval.

## Remaining service prerequisites

- Product/Exchange source and usable local images are absent. Verify Product
  accepts anonymous GET, enforces its own write permissions and matches the
  documented id/name/price/unit payload before real-service acceptance.
- The checked-in Order returns `productId` in items and rejects non-USD totals.
  The frontend uses that payload and USD only.
- Exchange route naming differs between docs and Gateway; currency UI is deferred.
- Order creation lacks documented idempotency; the frontend prevents duplicate
  clicks and automatic retries but cannot promise exactly-once order creation.
- All-orders administration, account editing/role changes, product editing,
  product media/stock/categories and financial reporting require new contracts.

The fixture-only Docker mode is for UI verification and never proves these
real-service prerequisites. Backend and frontend release commits must be
reviewed in their owning repositories before integration pointers are promoted.

---
icon: lucide/activity
---

# PWA and observability

## Online-only Store PWA

The store exports `/store/manifest.webmanifest` with distinct application ID,
start URL and scope `/store/`, standalone display, theme colors and a scalable
icon based on the existing platform mark. Landing/admin do not register root or
admin workers. There is **no service worker or offline caching**: private API
responses, credentials, account data and orders are never put in worker caches,
and writes are never replayed in the background.

Installation is browser-dependent and requires HTTPS in deployment (localhost
is suitable for development). The browser's install/add-to-home-screen action
is used; there is no misleading cross-platform install button. Device-specific
installation still needs acceptance on the chosen deployment. The current browser cart is not offline checkout: orders require an online
authenticated API. The selected [Redis Cart service](../services/cart/index.md)
will make the server cart authoritative; offline mutation/replay remains out of scope. See [Next.js PWA guidance](https://nextjs.org/docs/app/guides/progressive-web-apps).

## Grafana Cloud and Faro

Grafana Cloud is the selected destination for Faro. See the
[complete managed stack plan](../operations/observability.md#selected-grafana-cloud-stack)
for Prometheus/Mimir, Loki, Tempo, Pyroscope, OTel/Alloy and Graphite support.
The stack is selected; collector credentials, region and policy remain pending.

The approved SDK and tracing packages initialize once in the browser when
`NEXT_PUBLIC_ENABLE_TELEMETRY=true`, a Faro URL is configured and the visitor has
not opted out or enabled Do Not Track. App identity is landing/store/admin with
environment and release version. Import/init failures do not block the UI.

Console capture is disabled. The before-send hook drops arbitrary logs/events,
removes page query strings/user metadata, strips measurement context/action data
and sends generic browser errors without raw messages, context or stack traces.
This deliberately trades stack detail for conservative initial redaction.
Source maps are not uploaded and no Faro CLI/key is added.

Trace propagation is limited to the same-origin public catalog endpoint. Private
session/accounts/orders and individual product URLs are ignored, and traces
from private/query-bearing pages are dropped. Backend end-to-end trace
continuation is **not claimed** until its backend instrumentation is verified.
See the official [Faro Next.js guide](https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-applications/frontend-observability/get-started/instrument-nextjs/).

## Umami

Umami uses its official script through `next/script` after interactive loading,
without an npm wrapper. It is gated by the same telemetry setting, configured
script URL/website ID, Do Not Track and the browser opt-out. Admin usage
analytics are excluded. Automatic tracking is disabled; one manual pageview is
sent per pathname change/script readiness. Private store route names normalize
to `/store/private`; raw search values, UUID query parameters, email and account
identifiers are not supplied.

Events are named `demo_store_opened`, `demo_cart_item_added`,
`demo_order_created` and `demo_order_failed`. The only property supplied is the
application name. Creation is recorded after a successful API response, not on
button click. These are demo events, never payment/revenue records.
See [Umami tracker configuration](https://docs.umami.is/docs/tracker-configuration).

The landing `/privacy/` page explains local cart/session behavior and optional
telemetry, and offers a persistent browser opt-out. Reload after opting out to
stop an already-loaded collector. Endpoints/hosting/retention and policy must
be chosen with the owner before collection is enabled; no compliance claim or
production collection is fabricated.

## Per-app public build variables

Each frontend has an `.env.example`, and each Dockerfile declares matching
build arguments. No public value is a secret. CDN build environments must
supply each application's values independently.

| Variable                                                                                    | Purpose                                                          |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `NEXT_PUBLIC_API_BASE_URL`                                                                  | Defaults to `/api`; future CDN origin routing decided later      |
| `NEXT_PUBLIC_DISPLAY_TIME_ZONE`                                                             | IANA timezone; native Intl handles display                       |
| `NEXT_PUBLIC_APP_ENV`, `NEXT_PUBLIC_APP_VERSION`                                            | Environment and immutable release identifier                     |
| `NEXT_PUBLIC_ENABLE_TELEMETRY`                                                              | Defaults to false                                                |
| `NEXT_PUBLIC_FARO_URL`                                                                      | Approved browser collector URL                                   |
| `NEXT_PUBLIC_UMAMI_SCRIPT_URL`, `NEXT_PUBLIC_UMAMI_WEBSITE_ID`, `NEXT_PUBLIC_UMAMI_DOMAINS` | Approved script, website and allowed hostnames                   |
| `NEXT_PUBLIC_GRAFANA_DASHBOARD_URL`, `NEXT_PUBLIC_UMAMI_DASHBOARD_URL`                      | Non-secret dashboard links, never embedded dashboard credentials |

Changing public variables or base paths requires rebuilding the static export.
Gateway uses backend-only `AUTH_URL`, `ACCOUNT_URL`, `JWT_SECRET`,
`SESSION_COOKIE_SECURE` and `SESSION_COOKIE_PATH`. Production uses Secure cookies;
only the explicit local HTTP setup disables that cookie flag.

Before deployment, ask the owner to choose CDN provider, public/API origins,
per-app variables, Grafana Cloud stack/collector values, Umami hosting, allowed
script/connect origins, retention
and any collection policy. Do not create production resources or Kubernetes
frontends as part of local delivery.

Cloudflare is selected for DDoS/WAF/Tunnel security. This does not select the
static CDN provider or domain name; both remain open. See the
[security edge plan](../infrastructure/cloudflare.md).

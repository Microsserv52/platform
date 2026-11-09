---
icon: lucide/list-checks
---

# Local testing and delivery

## Full backend integration mode

From the platform root:

```bash
git submodule update --init --recursive
cp .env.example .env
docker compose up --build -d
```

The local entry point is `http://localhost:8080/`, with `/store/` and `/admin/`
on that origin. The three frontend services each build from their own Dockerfile
and serve their static export with Nginx. This mode uses Gateway/Auth/Account/
Order and the configured real Product/Exchange images. Those last two images
are external prerequisites and are not fabricated by frontend initialization.

The Compose edge uses Docker's DNS resolver and dynamically resolves upstream
addresses, so recreated frontend containers do not retain stale routing.
This requires the pinned Nginx 1.28 image; see the
[official upstream documentation](https://nginx.org/en/docs/http/ngx_http_upstream_module.html#resolve).
Set `DISPLAY_TIME_ZONE` before building to choose the display zone. Public
frontend values are baked into static exports and require a rebuild to change.

## Disposable frontend fixture mode

For UI-only testing without missing backend images, use the separate file:

```bash
docker compose -f compose.frontend-demo.yml up --build -d
docker compose -f compose.frontend-demo.yml ps
docker compose -f compose.frontend-demo.yml down
```

Open `http://localhost:8081/`, `/store/` or `/admin/`. This dedicated project binds
the endpoint to localhost and displays a **Local API fixtures** notice.
`FRONTEND_DEMO_PORT` can select another local port. Do not combine this file with
production deployment or call these fixtures live-service integration evidence.

Only in this fixture mode, use `visitor@example.test` or `admin@example.test`
with password `fixture-only`. These are canned test inputs, not real accounts
or committed production credentials. Products and orders are disposable
in-memory records that reset when the fixture service restarts. The fixture
server in `tests/frontend/serve.py` is test infrastructure, not an application
backend, security implementation or substitute for the missing services.

To review already-built exports without Docker:

```bash
python3 tests/frontend/serve.py --fixtures --port 4173
```

The optional Python server is loopback-only by default and requires each app's
`out/` directory. Docker is the persistent local preview used for handoff.

## Frontend repository checks

Use Node.js 24 and `npm ci` in each repository. The official Next.js and
Playwright generators were used. Each app exposes `format:check`, `lint`,
`typecheck`, `test`, `test:e2e`, `build` and a local pre-commit configuration that
calls the same installed npm tools without downloading hook packages.

CI runs formatting, lint, types, Vitest, static builds and Chromium desktop/mobile
Playwright flows. Browser tests use explicit API fixtures; backend tests verify
real access-control/session code separately. CodeQL configuration is included;
private-repository execution depends on the organization's GitHub security
entitlement. The image workflow publishes only immutable `sha-<commit>` tags for
local/integration container use. It does not deploy to a CDN or Kubernetes.

Platform Java/CodeQL/EKS workflows initialize only the public backend submodules.
They do not try to clone the private frontend repositories with the platform's
repository-scoped token. Each private frontend runs its own checks. A future
cross-repository frontend integration job needs an owner-configured GitHub App
or read credential; no broader credential or permission has been added here.

## Real administrator setup

New registrations always receive ROLE_USER. There is no public promote-to-admin
endpoint or frontend role-editing control. In an explicitly local/non-production
database, an authorized operator may promote a chosen demo account after
registration. For example, connect with your local PostgreSQL tooling and use
its bound-variable support to set that known account's roles to ROLE_ADMIN.
Do not publish credentials or add an automatic production administrator seed.
Record the operator action in deployment evidence when real environments are used.

## Release and acceptance

- Review frontend/backend source branches in their owning repositories first.
- Pin fetchable reviewed submodule commits in the platform; do not pin unpushed
  local-only commits in a shared integration release.
- Run real Product/Exchange contract checks, public reads and restricted writes
  before claiming full backend integration. Confirm order ownership and USD totals.
- Use [verification evidence](verification.md) to distinguish static/unit/fixture
  checks from production acceptance. Preserve the mock-store notices throughout.
- Ask the owner about CDN hosting and each app's environment values at deployment
  time. Agree API origin/cookie path, TLS, cache/404 rules, telemetry policy and
  rollback together. No frontend Kubernetes deployment is included now.

Record CI runs, app/backend commit IDs, container tags, environment and rollback
artifacts in final release evidence. Keep secrets out of docs and public build
values. Update the organization profile and disclose AI-assisted source/docs per
the course's [delivery requirements](../project/delivery.md).

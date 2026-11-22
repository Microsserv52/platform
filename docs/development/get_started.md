---
icon: lucide/rocket
---

# Get started

## Prerequisites

- Git with submodule support.
- Docker and Docker Compose.
- Java 25 and Maven (only required to build the Java services locally).
- Python 3.14 and `uv` (only required to work on the documentation).

## Clone the repository

```bash
git clone https://github.com/Microsserv52/platform.git
cd platform
git submodule update --init --recursive
```

The submodules are independent repositories. Changes to a submodule must be
committed in that repository first, then the resulting commit must be recorded
in this repository. The observability stack is the `observability` submodule;
initialize it before running `scripts/observability-up.sh` or the observability
Compose profile.

## Preview the documentation

```bash
uv sync
uv run zensical serve
```

Open the address printed by Zensical, normally
`http://127.0.0.1:8000/`.

## Run the platform

Choose one runtime mode:

- Use **Docker Compose** for local development and integration testing.
- Use **MicroK8s** to validate the Kubernetes deployment locally.
- Use **AWS EKS** for the production backend.

These modes do not share runtime resources or defaults.

### Docker Compose (local)

The root `compose.yml` is for local testing only. It starts PostgreSQL with
local defaults and builds Account, Auth, Gateway and Order from their checked
out submodules. Product and Exchange are external service repositories, so
their images must be available locally or in a registry. Compose includes a
local deterministic Exchange provider mock by default:

```bash
test -f .env || cp .env.example .env
docker compose up -d
docker compose ps
docker compose logs -f gateway
```

No external Exchange provider configuration is required for local development.
To use a real provider instead, set `EXCHANGE_PROVIDER_URL` and
`EXCHANGE_PROVIDER_API_KEY` in `.env`.

The mock responds to `/health`, `/latest`, `/v1/latest`, and `/latest.json`
with deterministic USD, EUR, BRL, GBP and JPY rates. It is intended for local
testing only and must not be used by production workloads. It refuses to start
when `ENV` or `APP_ENV` is `prod` or `production` (case-insensitive).

The Product and Exchange images are required artifacts, but do not require
additional configuration when they are already available locally or through
Docker's configured registry. Product shares the local PostgreSQL container
(`POSTGRES_DB`, default `platform`) and Flyway creates its schema on first
startup; Exchange receives the platform-wide `JWT_SECRET`.
PostgreSQL credentials, internal service URLs, JWT settings and the internal
service secret have local defaults.

> [!WARNING]
> The `.env.example` placeholders are unsafe local defaults. Before exposing
> this stack, replace at minimum `POSTGRES_PASSWORD`, `JWT_SECRET` and
> `INTERNAL_SERVICE_SECRET`. `JWT_SECRET` must be identical across Gateway,
> Auth, Account, Order, Product and Exchange, or authenticated calls fail with
> 401/403. Never reuse these defaults for MicroK8s or EKS.

#### Administrator access (local)

Registration always creates `ROLE_USER` accounts, but locally the Compose
fallback sets `ADMIN_EMAIL=admin@microsserv52.com` and
`ADMIN_PASSWORD=1berto52`, so on startup the Account service seeds that
account with `ROLE_ADMIN,ROLE_USER` (or promotes it if it already exists,
never overwriting its password). Sign in with it at `http://localhost:8080/admin/`
or via `POST /auth/login` to reach account list/detail/delete and Product
writes.

The bootstrap is **local-only and opt-in**:

- `.env.example` leaves both vars empty (disabled by default). Setting exactly
  one of the two fails Account startup; setting both empty disables it.
- It refuses to run when `ENV` or `APP_ENV` is `prod`/`production`
  (case-insensitive), or when any comma-separated token of
  `SPRING_PROFILES_ACTIVE` is `prod`/`production`. In those cases Account
  exits at startup instead of creating a privileged account.
- Never set these in MicroK8s or EKS; promote real accounts with SQL instead
  (below). Treat `1berto52` as public knowledge — it exists in this repo.

To create or promote an administrator manually (required anywhere the seed is
disabled), update the `roles` column with bound parameters and verify:

```bash
# Container name is <compose-project>-database-1 (default project: platform).
docker exec -i platform-database-1 psql -U admin -d platform <<'SQL'
UPDATE accounts
SET roles = CASE
    WHEN roles LIKE '%ROLE_ADMIN%' THEN roles
    WHEN roles = '' THEN 'ROLE_ADMIN'
    ELSE roles || ',ROLE_ADMIN'
END
WHERE lower(email) = lower('you@example.com')
RETURNING id, email, roles;
SQL
```

Verify with a query and with a freshly issued token (log out/in):

```bash
docker exec platform-database-1 psql -U admin -d platform \
  -c "SELECT email, roles FROM accounts WHERE lower(email) = lower('you@example.com');"
# Then: login again and call an admin endpoint, e.g. GET /api/accounts — expect 200, not 403.
```

Record operator promotions as deployment evidence in real environments.

#### Demo data (optional)

Two opt-in ways to fill the local stack with demo content. Both are
idempotent, use fixed identities, and refuse to run when `ENV`, `APP_ENV` or
`SPRING_PROFILES_ACTIVE` marks `prod`/`production`.

**API seeder (products, pictures, customer, orders)** — run after the main
stack is up:

```bash
docker compose --profile demo up --abort-on-container-exit demo-seeder
```

`scripts/seed_demo.py` logs in through the joined nginx endpoint with the
bootstrap admin, then creates the 20 products with their pictures, the demo
customer and that customer's orders from `scripts/demo-data.json` through the
real APIs. Pictures are uploaded with the presigned image flow, so they land in
the image-storage mock exactly like a normal client upload. Re-running skips
what already exists (products by name, images when the product already has
one, customer by email, orders by content); it never resets an existing
customer's password. On a fresh database run it once; `docker compose down -v`
resets everything.

**SQL (products only)** — for a database-only fill, e.g. when the gateway is
down. Fixed UUIDs, no duplicates:

```bash
docker exec -i platform-database-1 psql -U admin -d platform <<'SQL'
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000001', 'Tomato', 3.25, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Tomato');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000002', 'Carrot', 2.10, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Carrot');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000003', 'Potato', 1.90, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Potato');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000004', 'Broccoli', 4.50, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Broccoli');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000005', 'Apple', 3.60, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Apple');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000006', 'Banana', 2.40, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Banana');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000007', 'Strawberry', 6.20, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Strawberry');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000008', 'Chicken Breast', 12.90, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Chicken Breast');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000009', 'Salmon Fillet', 18.50, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Salmon Fillet');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000010', 'Cheddar Cheese', 9.80, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Cheddar Cheese');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000011', 'Whole Milk', 2.10, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Whole Milk');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000012', 'Eggs', 4.50, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Eggs');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000013', 'Sourdough Loaf', 5.40, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Sourdough Loaf');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000014', 'Croissant', 2.90, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Croissant');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000015', 'Jasmine Rice', 3.20, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Jasmine Rice');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000016', 'Olive Oil', 11.90, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Olive Oil');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000017', 'Coffee Beans', 14.50, 'kg'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Coffee Beans');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000018', 'Orange Juice', 4.80, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Orange Juice');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000019', 'Butter', 5.60, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Butter');
INSERT INTO products (id, name, price, unit)
SELECT '8b1f0000-0000-4000-8000-000000000020', 'Honey', 7.90, 'unit'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE name = 'Honey');
SQL
docker exec platform-database-1 psql -U admin -d platform \
  -c "SELECT name, price, unit FROM products ORDER BY name;"
```

Accounts and orders are deliberately not seeded by SQL: password hashes are
bcrypt-owned by Account and order totals are computed by Order. Create those
with the API seeder above.

> [!NOTE] Demo images
> `scripts/demo-data.json` ships a picture file (`scripts/images/<slug>.jpg`)
> for every product plus an alt text. The seeder attaches each image through
> `POST /products/{id}/image/uploads` → `PUT <uploadUrl>` →
> `POST /products/{id}/image` (see the product contract). In Compose the
> image-storage mock serves `/media/` behind nginx; in production the object
> keys are stored in AWS S3 behind a CloudFront media origin.

The local edge is Nginx on `http://localhost:8080`. Service containers are
replicated in the Compose topology and the gateway remains the only application
entry point exposed through the proxy.

For MicroK8s or EKS, see the [Kubernetes deployment guide](../infrastructure/eks.md).

The gateway is exposed on port `8080` by the compose configuration. The
repository snapshot currently contains the Order API and documentation
submodules, while the Product, Exchange, Account, Auth and Gateway images must
be supplied by their respective service repositories before the full stack can
start.

### Kubernetes

For local MicroK8s or production EKS, follow the
[Kubernetes deployment guide](../infrastructure/eks.md). MicroK8s and EKS require
Kubernetes Secrets and reachable Product/Exchange services; they do not use
the Compose `.env` file.

## Verify a service

```bash
cd api/order
./mvnw test
./mvnw spring-boot:run
```

Run the API tests and smoke tests for the other services from their own
submodule directories.

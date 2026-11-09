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
in this repository.

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
testing only and must not be used by production workloads.

The Product and Exchange images are required artifacts, but do not require
additional configuration when they are already available locally or through
Docker's configured registry.
PostgreSQL credentials, internal service URLs, JWT settings and the internal
service secret have local defaults.

The local edge is Nginx on `http://localhost:8080`. Service containers are
replicated in the Compose topology and the gateway remains the only application
entry point exposed through the proxy.

For MicroK8s or EKS, see the [Kubernetes deployment guide](../../k8s/README.md).

The gateway is exposed on port `8080` by the compose configuration. The
repository snapshot currently contains the Order API and documentation
submodules, while the Product, Exchange, Account, Auth and Gateway images must
be supplied by their respective service repositories before the full stack can
start.

### Kubernetes

For local MicroK8s or production EKS, follow the
[Kubernetes deployment guide](../../k8s/README.md). MicroK8s and EKS require
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

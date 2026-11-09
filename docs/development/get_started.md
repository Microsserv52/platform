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

The root `compose.yml` describes the intended local topology. Account, Auth,
Gateway and Order are built from their checked-out submodules when Compose is
started with `--build`. Product and Exchange are external service
repositories, so set `PRODUCT_IMAGE` and `EXCHANGE_IMAGE` in `.env` to images
built or published from those repositories before starting the stack:

```bash
docker compose up -d
docker compose ps
docker compose logs -f gateway
```

The local edge is Nginx on `http://localhost:8080`. Service containers are
replicated in the Compose topology and the gateway remains the only application
entry point exposed through the proxy.

For MicroK8s or EKS, see the [Kubernetes deployment guide](../../k8s/README.md).

The gateway is exposed on port `8080` by the compose configuration. The
repository snapshot currently contains the Order API and documentation
submodules, while the Product, Exchange, Account, Auth and Gateway images must
be supplied by their respective service repositories before the full stack can
start.

## Verify a service

```bash
cd api/order
./mvnw test
./mvnw spring-boot:run
```

Run the API tests and smoke tests for the other services from their own
submodule directories.

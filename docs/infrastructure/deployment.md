---
icon: lucide/server
---

# Deployment

## Documentation deployment

`.github/workflows/docs.yml` builds the Zensical site on pushes to `main` and
`master`, uploads the `site` artifact and deploys it to GitHub Pages. The
published site is [microsserv52.github.io/platform](https://microsserv52.github.io/platform/).

To reproduce the CI build locally:

```bash
uv sync
uv run zensical build --clean
```

## Planned staging — not implemented

See the [staging environment plan](staging.md) and its unchecked implementation
backlog. The owner selected scheduled developer-only access and synthetic seed
data. The plan keeps all production business services at smaller fixed capacity,
separates Grafana Cloud observability, enables Faro errors and disables Umami/
usage analytics. Current deployment workflows and Kubernetes files do not
implement that environment and must not be applied as an assumed staging setup.

## Application deployment

The repository supports three distinct runtime modes:

1. **Docker Compose** — local development and integration testing. It
   provisions PostgreSQL and uses the local Exchange provider mock.
2. **MicroK8s** — local Kubernetes validation. It uses the Kubernetes
   manifests and can deploy the local PostgreSQL manifest.
3. **AWS EKS** — production. It uses external PostgreSQL/RDS, production
   secrets, external Product/Exchange URLs, and the manual deployment workflow.

The local application topology is declared in [`compose.yml`](../../compose.yml).
Nginx listens on port `8080` and forwards traffic to the gateway. Run it with:

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
```

Stop it with `docker compose down`.

For a deployment environment:

1. Build and tag every service image with the names used by `compose.yml`.
2. Provide secrets through the platform's secret manager, not the compose file.
3. Configure the database connection and third-party exchange provider through
   environment variables.
4. Apply migrations before starting dependent services.
5. Verify health endpoints and an authenticated product/order flow.

The compose file is not a production orchestration manifest. Production uses
the Kubernetes manifests and must additionally define persistent storage, TLS,
backups, observability, network policies and a rollback strategy.

The repository includes a manual `Deploy to AWS EKS` workflow. Configure
`AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `EKS_CLUSTER_NAME`, `JWT_SECRET`,
`INTERNAL_SERVICE_SECRET`, `SPRING_DATASOURCE_URL`,
`SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD` as GitHub
Actions secrets. Also set `CACHE_REDIS_URL` as a secret and `PRODUCT_URL`/
`EXCHANGE_URL` as repository variables. The AWS role should use OIDC and least-privilege ECR/EKS
permissions; no long-lived AWS access key is required.

## Infrastructure review scope and verification

The infrastructure review preserves the five earlier Compose, MicroK8s, Redis,
Exchange mock and load-testing commits without republishing the merged frontend
or product-image changes. The split Kubernetes files replace `k8s/platform.yaml`;
the manual EKS workflow applies only backend resources. Frontends remain static
CDN exports, with hosting and environment values to be agreed before deployment.

Compose builds the checked-out Account, Auth, Gateway and Order sources under
explicit `:local` image tags. Product and Exchange sources are still absent;
provide those images under the configured tags, or use immutable registry image
references in `.env`. The PostgreSQL baseline is explicitly version 17 to match
the local Kubernetes manifest; Redis is constrained to 7.4. Existing database
volumes from another PostgreSQL major require a separate backup/migration plan.
The MicroK8s database and Redis manifests have no persistent volumes and are
disposable. Compose preserves Redis data in a named volume.

The provider mock uses deterministic USD reference rates and rebases them for
supported base currencies. Unsupported currencies return HTTP 400. Its date is
the current UTC date; the rates are fixtures, not live financial data. Validate
its HTTP behavior without starting the full platform:

```bash
python3 -m unittest discover -s tests/infrastructure -p 'test_*.py'
python3 -m unittest discover -s tests/frontend -p 'test_*.py'
docker compose config --quiet
uv run zensical build --clean
```

The k6 catalog baseline requires HTTP 200 and fails on missing routes or denied
requests. It is not evidence of authenticated checkout capacity. Redis endpoint
wiring does not implement caching; service-owned cache behavior remains future
work. Kubernetes resources and the manual EKS workflow must be validated in the
target cluster before deployment; no cluster or cloud deployment is performed
as part of this review.

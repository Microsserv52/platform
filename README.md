# Platform

Web application that allows authenticated users to buy and sell products
through a set of microservices.

## Documentation

The complete project and service documentation is published at
[https://microsserv52.github.io/platform/](https://microsserv52.github.io/platform/).
It is built with [Zensical](https://zensical.com).

To preview it locally from the project root:

```bash
uv sync
uv run zensical serve
```

Start with the [project overview](docs/project/project.md) or the
[getting started guide](docs/development/get_started.md).

## Web applications and local preview

The [frontend documentation](docs/frontend/index.md) covers three
independent Next.js applications integrated as Git submodules: `web/landing` at
`/`, `web/store` at `/store`, and `web/admin` at `/admin`, on one domain.
The agreed UI is English, with a shared modern brand and a public catalog.

This is an **educational mock store: no real payments or transactions take
place, and no goods are shipped**. Authenticated users will create persisted
demo orders. The store includes an online-only PWA manifest; Grafana Faro and
Umami are integrated but disabled until their deployment values are agreed.
Each app exports static files and has a Dockerfile. Production CDN hosting and
per-app environment values will be discussed before deployment; frontend
Kubernetes deployment is deferred.

To test the frontend independently of the missing Product/Exchange images:

```bash
docker compose -f compose.frontend-demo.yml up --build -d
```

Open `http://localhost:8081/`, `/store/` or `/admin/`. This separate local-only
mode visibly labels disposable API fixtures. See the [local testing guide](docs/frontend/delivery.md)
for fixture inputs, real-service mode and verification limits.

## CI/CD and environment variables

Each service repository owns lint, format, tests, JaCoCo quality gates, CodeQL,
and container publishing to GHCR. Images are tagged
`ghcr.io/microsserv52/<service>:sha-<commit>`. The platform workflow validates
the integration and pulls the image for each submodule commit; it builds locally
only when that immutable image is not available.

Copy [`.env.example`](.env.example) for local development. Do not commit the
real `.env` file or any secret values.

Configure repository secrets in **Settings → Secrets and variables → Actions**
for each repository:

| Repository | Required secrets |
| --- | --- |
| `Microsserv52/platform` | `AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `EKS_CLUSTER_NAME`, `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` |
| `Microsserv52/account` | `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` |
| `Microsserv52/auth` | `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `ACCOUNT_URL`, `ACCESS_TOKEN_EXPIRATION_SECONDS` |
| `Microsserv52/gateway` | `JWT_SECRET`, `AUTH_URL`, `ACCOUNT_URL`, `ORDER_URL`, `PRODUCT_URL`, `EXCHANGE_URL` |
| `Microsserv52/order-service` | `JWT_SECRET`, `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `PRODUCT_URL` |
| `Microsserv52/order` | No runtime secrets; this repository contains the reusable API contract. |

For local Compose, put the values in the root `.env`. For MicroK8s, create
the `platform-secrets` Kubernetes secret as described in
[`k8s/README.md`](k8s/README.md). For EKS, use an RDS PostgreSQL URL and add
the values to the **platform** repository's Actions secrets.

### Environment variable locations

| Variable type | Local development | GitHub Actions | Kubernetes/EKS |
| --- | --- | --- | --- |
| Service URLs and image tags | Root `.env` | Repository variables or workflow defaults | ConfigMap/deployment values |
| JWT and internal credentials | Root `.env` (never commit) | Repository **Secrets** | `platform-secrets` |
| Database URL and credentials | Root `.env` | Platform or service **Secrets** | `platform-secrets` / AWS Secrets Manager |
| AWS deployment values | Not required | Platform **Secrets** (`AWS_REGION`, `AWS_DEPLOY_ROLE_ARN`, `EKS_CLUSTER_NAME`) | IAM/OIDC and cluster configuration |

The service workflows need `packages: write` to publish GHCR images. The
platform workflow needs `packages: read` to pull them. Keep GHCR packages
private unless the deployment policy explicitly requires public images.

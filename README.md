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

## CI/CD and secrets

The platform CI runs service tests, Spring context/integration tests, JaCoCo
coverage gates, Compose validation, and container builds. CodeQL runs for Java
and GitHub Actions. The AWS EKS deployment is manual and uses GitHub OIDC;
it does not require long-lived AWS access keys.

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

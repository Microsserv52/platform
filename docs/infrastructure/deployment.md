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
Actions secrets. The AWS role should use OIDC and least-privilege ECR/EKS
permissions; no long-lived AWS access key is required.

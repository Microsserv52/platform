---
icon: lucide/server
---

# Deployment

Use the [deployment runbook](runbook.md) for the exact AWS and LocalStack
commands, verification and troubleshooting. See [infrastructure changes](changes.md)
for the manifest moves and migration steps introduced by the current
implementation.

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

The repository supports four distinct runtime modes:

1. **Docker Compose** — daily development and integration testing. It
   provisions PostgreSQL and uses the local Exchange provider mock.
2. **LocalStack rehearsal** — deployment rehearsal with Terraform, EKS, ECR,
   RDS, ElastiCache, S3 and CloudFront emulated locally. Start it with
   `scripts/localstack-up.sh`; see [LocalStack rehearsal](localstack.md).
3. **MicroK8s** — local Kubernetes validation through the `microk8s` overlay.
4. **AWS EKS** — production. Terraform provisions the infrastructure and shell
   scripts deploy from an authenticated workstation.

The local application topology is declared in [`compose.yml`](../../compose.yml).
Nginx listens on port `8080` and forwards traffic to the gateway. Run it with:

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
```

Stop it with `docker compose down`.

!!! warning "Local Compose defaults are not deployable"

    Compose injects the `.env` values verbatim. Replace `POSTGRES_PASSWORD`,
    `JWT_SECRET` and `INTERNAL_SERVICE_SECRET` before exposing the stack.
    Product connects to the shared local PostgreSQL and requires
    `SPRING_DATASOURCE_URL/USERNAME/PASSWORD` plus `JWT_SECRET`; Exchange
    requires `JWT_SECRET`. Leave `ADMIN_EMAIL`/`ADMIN_PASSWORD` unset in real
    environments: the Account service seeds a LOCAL-ONLY admin when both are
    set, and refuses to start if both are set while `ENV`/`APP_ENV`/
    `SPRING_PROFILES_ACTIVE` marks the environment as `prod`/`production`.
    In any real environment provide these through the secret manager, never
    through the compose file.

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

Deployment is shell-first and has no CI/CD deploy workflow. Infrastructure is
declared in [`terraform/`](https://github.com/Microsserv52/platform/blob/main/terraform/README.md); workloads live in
[`k8s/`](https://github.com/Microsserv52/platform/blob/main/k8s/README.md). Log in with short-lived credentials, then run:

```bash
aws sso login --profile platform
export AWS_PROFILE=platform
export TF_STATE_BUCKET=my-platform-tf-state   # optional; defaults to platform-tfstate-<account-id>
scripts/deploy-aws.sh --frontends
```

The script provisions VPC, EKS, ECR, RDS, ElastiCache, S3, CloudFront and the
Product IRSA role, pushes images, creates `platform-secrets`, applies the
`aws` overlay, annotates the Product service account, rolls out the services
and optionally syncs the frontends and invalidates CloudFront. It does not
create long-lived AWS access keys; use IAM Identity Center or a role profile.
Product needs `JWT_SECRET` and its datasource values, and Exchange needs
`DEPLOY_EXCHANGE_PROVIDER_URL` and `DEPLOY_EXCHANGE_PROVIDER_API_KEY` for the
real provider. Use `--skip-terraform`, `--skip-images` or `--no-auto-approve`
for partial deployments. The demo seeder is never deployed; run
`scripts/seed_demo.py` manually against the deployed URL.

The Kubernetes resources must additionally define persistent storage, TLS,
backups, observability, network policies and a rollback strategy before the
deployment is treated as production-grade.

## Infrastructure review scope and verification

The infrastructure review preserves the five earlier Compose, MicroK8s, Redis,
Exchange mock and load-testing commits without republishing the merged frontend
or product-image changes. The Kustomize base and overlays replace `k8s/platform.yaml`;
the AWS deployment path applies only backend resources. Frontends remain static
CDN exports, with hosting and environment values to be agreed before deployment.

Compose builds the checked-out Account, Auth, Gateway and Order sources under
explicit `:local` image tags. Product and Exchange are submodule services built
from their own Dockerfiles; use immutable registry image references for
deployments. The PostgreSQL baseline is explicitly version 17 to match
the local Kubernetes manifest; Redis is constrained to 7.4. Existing database
volumes from another PostgreSQL major require a separate backup/migration plan.
The MicroK8s database and Redis manifests have no persistent volumes and are
disposable. Compose preserves Redis data in a named volume.

The provider mock uses deterministic USD reference rates and rebases them for
supported base currencies. Unsupported currencies return HTTP 400. Its date is
the current UTC date; the rates are fixtures, not live financial data. The mock
refuses to start when `ENV` or `APP_ENV` is `prod` or `production`, and no
Kubernetes manifest or deployment script builds or starts it. Validate
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
work. Kubernetes resources and the AWS deployment path must be validated in the
target cluster before deployment; no cluster or cloud deployment is performed
as part of this review.

---
icon: lucide/server
---

# Deployment

Use the [deployment runbook](runbook.md) for the exact AWS and LocalStack
commands, verification and troubleshooting. The Kubernetes layout and overlay
differences are listed in [`k8s/README.md`](https://github.com/Microsserv52/platform/blob/main/k8s/README.md).

## Documentation deployment

`.github/workflows/docs.yml` builds the Zensical site on pushes to `main` and
`master`, uploads the `site` artifact and deploys it to GitHub Pages. The
published site is [microsserv52.github.io/platform](https://microsserv52.github.io/platform/).

To reproduce the CI build locally:

```bash
uv sync
uv run zensical build --clean
```

## Staging environment

The [staging environment](staging.md) has its own Terraform configuration in
`terraform/environments/staging` and a one-replica Kubernetes overlay in
`k8s/overlays/staging`. It runs in a dedicated VPC and cluster, uses private RDS,
ElastiCache and S3 resources, and has no CloudFront, WAF, DNS record or public
load balancer. Access is limited to the EKS endpoint and `kubectl port-forward`.

No CI/CD workflow provisions or deploys staging. An operator applies Terraform
and the overlay from an authenticated workstation. The runtime modes below
describe the production deployment and the local rehearsal paths.

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
5. **AWS EKS staging** — the same workload definitions at one replica in the
   separate staging account or VPC; see [Staging](staging.md).

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

The script provisions VPC, EKS, ECR, RDS, ElastiCache, S3, CloudFront, the
Product IRSA role and the Cluster Autoscaler IRSA role, pushes images, installs
`metrics-server` and Cluster Autoscaler, creates the internet-facing Gateway
NLB in Terraform, creates `platform-secrets`, applies the `aws` overlay (with
the Gateway NodePort), annotates the Product service account, rolls out the
services and optionally syncs the frontends and invalidates CloudFront. It does not
create long-lived AWS access keys; use IAM Identity Center or a role profile.
Product needs `JWT_SECRET` and its datasource values, and Exchange needs
`DEPLOY_EXCHANGE_PROVIDER_URL`. The provider API key is optional; set
`DEPLOY_EXCHANGE_PROVIDER_API_KEY` and
`DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY=true` only when the provider
requires authentication. Use `--skip-terraform`, `--skip-images` or
`--no-auto-approve` for partial deployments. The demo seeder is never deployed;
run `scripts/seed_demo.py` manually against the deployed URL.

Observability is a separate opt-in step. Set `TF_VAR_enable_observability=true`
and apply Terraform, then run `scripts/install-observability.sh`. It installs
Prometheus, Mimir, Loki, Tempo, Pyroscope, Grafana, Alloy and blackbox, with
EBS-backed PVCs. Grafana stays ClusterIP and is published behind Amazon Cognito
at an ALB when a custom domain exists; see
[Grafana on AWS](../operations/grafana-aws.md) and
[custom domains](custom-domains.md).

Images can also be built and pushed by the manual
**Publish EKS images** workflow. It does not deploy; after it finishes, roll out
the tag from the shell:

```bash
TAG=<workflow-tag> scripts/deploy-aws.sh --skip-terraform --skip-images
```

See [CI/CD](../development/cicd.md#eks-image-publishing-workflow) for the
workflow inputs and ECR permissions.

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

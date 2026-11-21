---
icon: lucide/git-compare
---

# Infrastructure changes

This page records the infrastructure work delivered on the
`feature/localstack-iac` branch: what was added, removed, renamed and how to
migrate an existing MicroK8s/EKS setup.

## Summary

| Area | Change |
| --- | --- |
| Terraform | New `terraform/` tree with reusable modules and `localstack`/`aws` environments |
| LocalStack | New `compose.localstack.yml` and `scripts/localstack-up.sh` / `down.sh` |
| Kubernetes | Flat `k8s/*.yaml` replaced by `k8s/base` plus `microk8s`, `localstack` and `aws` overlays |
| Workloads | Product and Exchange manifests added; frontends remain static S3/CloudFront exports |
| Deployment | Shell-first `scripts/deploy-aws.sh`; `.github/workflows/deploy-eks.yml` removed |
| Secrets | `platform-secrets` now uses `SPRING_DATASOURCE_PASSWORD`, not `POSTGRES_PASSWORD` |
| Configuration | `.env.example` gained LocalStack, AWS, Terraform and frontend sections |
| Documentation | New runbook, LocalStack, Terraform, overlays and changes pages |

The daily `compose.yml` mode, service source code, CI tests, CodeQL and the
documentation workflow are unchanged.

## Added

### Terraform

```text
terraform/
  modules/
    network/       VPC, subnets, IGW, NAT, route tables
    ecr/           one repository per service
    rds/           PostgreSQL subnet group, security group, instance
    elasticache/   Redis subnet group, security group, cluster
    storage/       media bucket + landing/store/admin buckets
    cloudfront/    one distribution, OACs, cache behaviors, rewrite function
    eks/           cluster, node group, OIDC, IRSA, optional access entry
    dns/           optional ACM certificate and validation records
  environments/
    localstack/    LocalStack endpoints, dummy credentials, local state
    aws/           real provider, optional S3 state, optional DNS
```

The AWS environment requires Terraform >= 1.10 because the S3 backend uses
native state locking (`use_lockfile = true`). The LocalStack environment works
from >= 1.9.

### LocalStack

- `compose.localstack.yml` runs `localstack/localstack:2026.10.8`, publishes
  `4566`, `8081` and the LocalStack load-balancer range, and mounts the Docker
  socket for EKS/k3s.
- `scripts/localstack-up.sh` provisions the stack, pushes images, exports the
  kubeconfig and deploys the `localstack` overlay.
- `scripts/localstack-down.sh` destroys the Terraform stack and the volume.

### Kubernetes layout

```text
k8s/
  base/                    # shared workloads and policy
    namespace-config.yaml  # Namespace, ConfigMap, Product ServiceAccount
    account.yaml
    auth.yaml
    order.yaml
    gateway.yaml
    product.yaml
    exchange.yaml
    ingress.yaml
    hpa.yaml
    pdb.yaml
    kustomization.yaml
  overlays/
    microk8s/              # local PostgreSQL, Redis, image-storage mock
    localstack/            # Traefik ingress, exchange mock
    aws/                   # nginx TLS redirect
```

### Scripts

| Script | Purpose |
| --- | --- |
| `scripts/deploy-aws.sh` | login guard, Terraform, ECR push, secrets, overlay, IRSA, rollout, optional frontends |
| `scripts/localstack-up.sh` | start LocalStack, provision, push, deploy |
| `scripts/localstack-down.sh` | destroy LocalStack stack and volume |
| `scripts/bootstrap-tf-state.sh` | create the private versioned Terraform state bucket |
| `scripts/build-and-push-images.sh` | build/push account, auth, gateway, order, product, exchange |
| `scripts/create-platform-secrets.sh` | create/update `platform-secrets` |
| `scripts/sync-frontends.sh` | build and sync landing/store/admin to S3 + CloudFront |
| `scripts/common.sh` | shared paths, env loading and helpers |

### Documentation

- [Deployment runbook](runbook.md) — full AWS and LocalStack operations.
- [LocalStack rehearsal](localstack.md) — emulator scope and limits.
- [Deployment](deployment.md) — runtime modes and deployment overview.
- [Terraform README](https://github.com/Microsserv52/platform/blob/main/terraform/README.md)
- [Kubernetes README](https://github.com/Microsserv52/platform/blob/main/k8s/README.md)
- This changes page.

## Changed

### Kubernetes manifest paths

| Previous | Now |
| --- | --- |
| `k8s/00-namespace-config.yaml` | `k8s/base/namespace-config.yaml` |
| `k8s/05-redis.yaml` | `k8s/overlays/microk8s/redis.yaml` |
| `k8s/10-database.yaml` | `k8s/overlays/microk8s/database.yaml` |
| `k8s/20-account.yaml` | `k8s/base/account.yaml` |
| `k8s/30-auth.yaml` | `k8s/base/auth.yaml` |
| `k8s/40-order.yaml` | `k8s/base/order.yaml` |
| `k8s/50-gateway.yaml` | `k8s/base/gateway.yaml` |
| `k8s/60-ingress.yaml` | `k8s/base/ingress.yaml` |
| `k8s/70-hpa.yaml` | `k8s/base/hpa.yaml` |
| `k8s/71-pdb.yaml` | `k8s/base/pdb.yaml` |
| — | `k8s/base/product.yaml` |
| — | `k8s/base/exchange.yaml` |
| — | `k8s/overlays/microk8s/image-storage.yaml` |
| — | `k8s/overlays/localstack/exchange-mock.yaml` |

Apply commands change from per-file applies to one overlay:

```bash
# before
kubectl apply -f k8s/00-namespace-config.yaml
kubectl apply -f k8s/10-database.yaml
# ...

# now
kubectl apply -k k8s/overlays/microk8s
kubectl apply -k k8s/overlays/localstack
kubectl apply -k k8s/overlays/aws
```

### Secret keys

`platform-secrets` no longer uses the `POSTGRES_PASSWORD` key. It now contains:

- `JWT_SECRET`
- `INTERNAL_SERVICE_SECRET`
- `CACHE_REDIS_URL`
- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `EXCHANGE_PROVIDER_API_KEY`

Existing clusters must recreate the secret or add the new key:

```bash
kubectl -n platform patch secret platform-secrets --type merge \
  -p "{\"stringData\":{\"SPRING_DATASOURCE_PASSWORD\":\"$(kubectl -n platform get secret platform-secrets -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)\"}}"
```

### Workload configuration

- Product now runs with `SPRING_PROFILES_ACTIVE=prod` and `PRODUCT_IMAGE_MODE=s3`
  in the AWS and LocalStack modes.
- The MicroK8s overlay switches Product to `PRODUCT_IMAGE_MODE=mock` and adds the
  `image-storage` mock.
- Exchange is deployed with the base manifests; LocalStack adds `exchange-mock`,
  while AWS expects `DEPLOY_EXCHANGE_PROVIDER_URL`.
- All backend Deployments now have startup, liveness and readiness probes,
  resource requests/limits, a restricted security context and a rolling update
  strategy.
- HPA scales 2-6 replicas at 70% CPU; PDB keeps one replica available.
- Frontends are not Kubernetes workloads; they are static exports synced to
  separate S3 buckets behind one CloudFront distribution.

### Configuration sources

The base ConfigMap keeps internal service URLs and placeholders. The deploy
scripts patch infrastructure-dependent values after applying the overlay:

```bash
kubectl -n platform patch configmap platform-config --type merge -p '{"data":{...}}'
```

The LocalStack and MicroK8s overlays patch the database and cache endpoints.
The AWS deploy script patches the media bucket, region, CloudFront origin and
Exchange provider URL.

### Deployment workflow

`.github/workflows/deploy-eks.yml` was removed. Deployment now runs from a
logged-in workstation:

```bash
export AWS_PROFILE=platform
scripts/deploy-aws.sh --frontends
```

CI still runs tests, CodeQL and documentation. There is no plan to add a CI/CD
deploy workflow.

### Environment template

`.env.example` now separates:

- daily Compose values (`POSTGRES_*`, `CACHE_REDIS_URL`, mock URLs)
- LocalStack values (`LOCALSTACK_*`)
- AWS deployment values (`TF_STATE_*`, `DEPLOY_EXCHANGE_PROVIDER_*`, `TF_VAR_*`)
- frontend build values (`NEXT_PUBLIC_*`)
- manual seeder values

LocalStack dummy credentials are no longer stored in `.env`; the LocalStack
script exports them for its own commands. `deploy-aws.sh` ignores them if they
are present.

## Removed

- `.github/workflows/deploy-eks.yml`
- flat `k8s/00-*`, `05-*`, `10-*`, `20-*`, `30-*`, `40-*`, `50-*`, `60-*`,
  `70-*` and `71-*` manifests
- the implicit `POSTGRES_PASSWORD` secret key
- the assumption that Product and Exchange are external workloads only

## Migration checklist

- [ ] Check out the branch and update submodules.
- [ ] Copy the new `.env.example` values into `.env`; do not copy old secrets
      over the new keys blindly.
- [ ] Recreate or patch `platform-secrets` with `SPRING_DATASOURCE_PASSWORD`.
- [ ] Replace per-file `kubectl apply -f k8s/...` commands with the matching
      overlay.
- [ ] For MicroK8s, build `microsserv52-image-storage:local`.
- [ ] For AWS, log in, set `DEPLOY_EXCHANGE_PROVIDER_URL` and
      `DEPLOY_EXCHANGE_PROVIDER_API_KEY`, then run `scripts/deploy-aws.sh`.
- [ ] Install an ingress controller in EKS before expecting the Ingress to serve.
- [ ] Stop using the deleted `Deploy to AWS EKS` workflow.

## Verification performed

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/localstack validate
terraform -chdir=terraform/environments/aws validate
kubectl kustomize k8s/overlays/microk8s
kubectl kustomize k8s/overlays/localstack
kubectl kustomize k8s/overlays/aws
docker compose -f compose.yml config --quiet
docker compose -f compose.localstack.yml config --quiet
python3 -m unittest discover -s tests/infrastructure -p 'test_*.py'
python3 -m unittest discover -s tests/frontend -p 'test_*.py'
uv run zensical build --clean
```

All checks passed. Runtime provisioning was not executed because this
environment has no AWS credentials and no LocalStack Student token.

## Related

- [Deployment runbook](runbook.md)
- [Deployment](deployment.md)
- [LocalStack rehearsal](localstack.md)
- [Staging plan](staging.md)

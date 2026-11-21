---
icon: lucide/container
---

# LocalStack rehearsal

Use the [deployment runbook](runbook.md#localstack-rehearsal) for the complete
step-by-step commands, verification and troubleshooting. This page describes
the rehearsal design and its limits.

The LocalStack rehearsal runs the backend the way AWS does: workloads in EKS,
images from ECR, PostgreSQL from RDS, Redis from ElastiCache, and product media
in S3 behind CloudFront. It is a deployment rehearsal, not the daily loop. The
daily loop remains [`compose.yml`](../../compose.yml).

## Prerequisites

- Docker with the Compose plugin.
- Terraform >= 1.9.
- `kubectl`, `aws` CLI and `jq`.
- A LocalStack **Student** (or paid) auth token. Hobby does not include EKS,
  ECR, RDS, ElastiCache or CloudFront.

```bash
cp .env.example .env
# set LOCALSTACK_AUTH_TOKEN
scripts/localstack-up.sh
```

If a healthy LocalStack already answers on `LOCALSTACK_ENDPOINT`, the script
reuses it. To re-apply manifests without rebuilding images:

```bash
SKIP_IMAGES=true scripts/localstack-up.sh
```

The script starts [`compose.localstack.yml`](../../compose.localstack.yml) when
needed, waits for `/_localstack/health`, runs `terraform apply` in
`terraform/environments/localstack`, logs Docker in to LocalStack ECR, builds
and pushes all six service images plus the exchange mock, exports the
kubeconfig, creates `platform-secrets`, applies `k8s/overlays/localstack` and
rolls every deployment.

Teardown destroys the Terraform stack and the LocalStack volume. An existing
container that the script reused is left running:

```bash
scripts/localstack-down.sh
```

## Observability rehearsal

The Compose observability profile runs alongside LocalStack for a local
metrics/logs/traces loop without touching the EKS rehearsal:

```bash
docker compose -f compose.yml -f compose.observability.yml \
  --profile observability up -d
```

The LocalStack EKS rehearsal can install the same Prometheus/Grafana stack with
emptyDir storage and the control-plane toleration:

```bash
scripts/install-observability.sh --localstack
kubectl -n observability port-forward svc/grafana 3000:3000
```

It uses `observability/helm/values.localstack.yaml` and
`k8s/overlays/localstack/observability`. The external CloudFront `Probe` is
deleted in that overlay because LocalStack has no public edge. Prometheus and
Grafana data is not durable in this mode; it is a rehearsal, not storage.

See [Observability](../operations/observability.md).

## What is provisioned

| Layer      | LocalStack resource                                          |
| ---------- | ------------------------------------------------------------ |
| Network    | VPC, two public/private subnets, route tables (no NAT)        |
| Registry   | ECR repositories for account, auth, gateway, order, product, exchange, exchange-mock |
| Database   | RDS PostgreSQL, published on loopback and reached through the LocalStack container IP |
| Cache      | ElastiCache Redis single node                                 |
| Storage    | Media bucket plus landing, store and admin buckets            |
| CDN        | One CloudFront distribution with OAC and path behaviors       |
| Kubernetes | EKS cluster (k3s under the hood), no managed node group       |

## Emulation limits

- LocalStack EKS is k3s. VPC, security groups and node groups are metadata, not
  enforced networking.
- CloudFront resources exist through the API; edge behavior and DNS are
  emulated, so treat the distribution domain as a local URL.
- RDS and ElastiCache are published on loopback. The script reads the current
  endpoint addresses and ports from the emulator and points pods at the
  LocalStack container IP on the k3d network. `LOCALSTACK_HOST_IP` overrides
  detection; do not rely on a port seen in an older run, because LocalStack can
  reassign it.
- LocalStack EKS has a single control-plane node with a `NoSchedule` taint. The
  `localstack` overlay adds the matching toleration and runs one replica per
  deployment so the full stack fits on one node. HPA and PDB objects remain, but
  HPA needs `metrics-server` and stays idle without it.
- LocalStack EKS does not install an ingress controller by default. Use
  `kubectl port-forward svc/gateway 8080:8080` for direct API access. The nginx
  and CloudFront paths, including the `/api` prefix rewrite, are exercised only
  in the AWS and MicroK8s modes.
- LocalStack ECR, RDS, ElastiCache and CloudFront have partial Terraform
  provider coverage. If a resource is rejected, use `awslocal` for that resource
  and record the gap.
- Product's S3 client uses the AWS SDK default credential chain. The localstack
  overlay sets `AWS_ENDPOINT_URL` and dummy credentials, but a Product build
  that resolves endpoints internally needs `AWS_ENDPOINT_URL_S3` support from
  the SDK. The browser presign path additionally requires HTTPS and an exact
  `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` match.

## Frontend delivery

Frontends are static exports. To publish them to LocalStack S3 and CloudFront:

```bash
FRONTEND_BUCKETS="$(terraform -chdir=terraform/environments/localstack output -json frontend_buckets)" \
CLOUDFRONT_DISTRIBUTION_ID="$(terraform -chdir=terraform/environments/localstack output -raw cloudfront_distribution_id)" \
AWS_ENDPOINT_URL=http://localhost:4566 \
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080 \
NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS=http://localhost:4566 \
scripts/sync-frontends.sh
```

The Gateway expects `/products`, not `/api/products`. nginx and CloudFront strip
the `/api` prefix in the deployed modes. Direct LocalStack access normally uses
`kubectl port-forward svc/gateway 8080:8080`, so build the frontends with
`NEXT_PUBLIC_API_BASE_URL=http://localhost:8080` and keep the forward open.

## Related

- [Deployment runbook](runbook.md)
- [Infrastructure changes](changes.md)
- [Terraform modules](https://github.com/Microsserv52/platform/blob/main/terraform/README.md)
- [Kubernetes overlays](https://github.com/Microsserv52/platform/blob/main/k8s/README.md)
- [AWS setup](aws.md)
- [EKS and Kubernetes](eks.md)

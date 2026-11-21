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
# set LOCALSTACK_AUTH_TOKEN and keep the dummy AWS_* values
scripts/localstack-up.sh
```

The script starts [`compose.localstack.yml`](../../compose.localstack.yml),
waits for `/_localstack/health`, runs `terraform apply` in
`terraform/environments/localstack`, logs Docker in to LocalStack ECR, builds
and pushes all six service images, exports the kubeconfig, creates
`platform-secrets`, applies `k8s/overlays/localstack` and rolls the deployments.

Teardown destroys the Terraform stack and the LocalStack volume:

```bash
scripts/localstack-down.sh
```

## What is provisioned

| Layer      | LocalStack resource                                          |
| ---------- | ------------------------------------------------------------ |
| Network    | VPC, two public/private subnets, route tables (no NAT)        |
| Registry   | ECR repositories for account, auth, gateway, order, product, exchange |
| Database   | RDS PostgreSQL, publicly reachable on the Docker host         |
| Cache      | ElastiCache Redis single node                                 |
| Storage    | Media bucket plus landing, store and admin buckets            |
| CDN        | One CloudFront distribution with OAC and path behaviors       |
| Kubernetes | EKS cluster (k3s under the hood), no managed node group       |

## Emulation limits

- LocalStack EKS is k3s. VPC, security groups and node groups are metadata, not
  enforced networking.
- CloudFront resources exist through the API; edge behavior and DNS are
  emulated, so treat the distribution domain as a local URL.
- RDS and ElastiCache are published on the host. Pods reach them through the
  Docker bridge gateway (`LOCALSTACK_HOST_GATEWAY` overrides detection).
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
NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS=http://localhost:4566 \
scripts/sync-frontends.sh
```

LocalStack's HTTP endpoint is rejected by the admin allowlist unless the
origin is configured or the page runs with the fixture flag. Validate S3 through
the API first, then add LocalStack TLS for the browser flow.

## Related

- [Deployment runbook](runbook.md)
- [Infrastructure changes](changes.md)
- [Terraform modules](https://github.com/Microsserv52/platform/blob/main/terraform/README.md)
- [Kubernetes overlays](https://github.com/Microsserv52/platform/blob/main/k8s/README.md)
- [AWS setup](aws.md)
- [EKS and Kubernetes](eks.md)

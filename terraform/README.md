# Infrastructure as code

For the end-to-end operational commands, see the
[deployment runbook](../docs/infrastructure/runbook.md). For the list of files
changed by this implementation, see
[infrastructure changes](../docs/infrastructure/changes.md).

Terraform owns all AWS resources for both run modes:

- `environments/localstack` — the deployment rehearsal. Uses the LocalStack
  endpoints, dummy credentials and local state. No AWS account required.
- `environments/aws` — the real account. Uses the standard AWS provider, remote
  S3 state when `TF_STATE_BUCKET` is set, and CloudFront in `us-east-1`.
- `environments/grafana-cloud` — optional Grafana Cloud folder, dashboards,
  contact point, alert rules and synthetic checks. Uses the `grafana/grafana`
  provider and is validated locally without credentials.

Kubernetes workloads are separate from this layer; see [`../k8s/README.md`](../k8s/README.md).

## Modules

| Module        | Resources                                                                 |
| ------------- | ------------------------------------------------------------------------- |
| `network`     | VPC, public/private subnets, internet gateway, NAT, route tables          |
| `ecr`         | One repository per service, scan-on-push and lifecycle policy             |
| `rds`         | PostgreSQL subnet group, security group and instance                      |
| `elasticache` | Redis subnet group, security group and single-node cluster                |
| `storage`     | Product media bucket, one bucket per frontend, lifecycle, versioning       |
| `cloudfront`  | One distribution, S3 OACs, media CORS, `/store`, `/admin`, `/media` and optional `/api` |
| `eks`         | Cluster, node group, OIDC provider, Product IRSA, Cluster Autoscaler IRSA, access entry, optional EBS CSI IRSA/add-on |
| `dns`         | Optional ACM certificate and DNS validation through Route 53              |

## LocalStack rehearsal

```bash
cp .env.example .env          # set LOCALSTACK_AUTH_TOKEN
scripts/localstack-up.sh
scripts/localstack-down.sh
```

`localstack-up.sh` starts the emulator, provisions the stack with Terraform,
pushes images to LocalStack ECR, exports a kubeconfig, creates the platform
secret and applies the LocalStack overlay.

## Real AWS

```bash
aws sso login --profile platform
export AWS_PROFILE=platform
export TF_STATE_BUCKET=my-platform-tf-state   # optional; defaults to platform-tfstate-<account-id>
scripts/deploy-aws.sh --frontends
```

The deploy script performs, in order: state bootstrap, `terraform apply`, ECR
login and image push, kubeconfig export, `metrics-server` and Cluster Autoscaler
installation, Secret creation, overlay apply, ConfigMap patch, IRSA annotation,
rolling rollout, optional frontend sync and CloudFront invalidation.

Required inputs before the first real deployment:

- `DEPLOY_EXCHANGE_PROVIDER_URL` for the real Exchange provider and, only if
  the provider requires authentication, `DEPLOY_EXCHANGE_PROVIDER_API_KEY`.
  Set `DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY=true` in that case.
- `TF_VAR_domain_name`/`TF_VAR_hosted_zone_id` (with `TF_VAR_create_dns=true`)
  or a pre-existing `TF_VAR_acm_certificate_arn` when using a custom domain.
- An nginx ingress controller installed in the cluster.

Use `--skip-terraform`, `--skip-images`, `--skip-addons`, `--frontends` or
`--no-auto-approve` to control individual phases. Deployment is intentionally
shell-first; there is no CI/CD deploy workflow.

## State

By default `deploy-aws.sh` creates and uses a private bucket named
`platform-tfstate-<account-id>`. To reuse a specific bucket, create it once and
export its name:

```bash
TF_STATE_BUCKET=my-platform-tf-state scripts/bootstrap-tf-state.sh
```

The backend uses S3 native locking (`use_lockfile = true`), so no DynamoDB lock
table is required. State contains the generated RDS password: keep the bucket
private and encrypted.

## Observability preparation

The AWS environment has an opt-in observability flag (default `false`):

```bash
export TF_VAR_enable_observability=true
terraform -chdir=terraform/environments/aws apply
```

This creates the `aws-ebs-csi-driver` add-on with its IRSA role and the Secrets
Manager containers `platform/grafana/admin` and `platform/grafana/alerting`. It
does not write secret values or deploy the observability stack. After the apply,
`scripts/install-observability.sh` deploys Prometheus, Mimir, Loki, Tempo,
Pyroscope, Grafana, Alloy, blackbox and the OTel Java agent. See
[Grafana on AWS](../docs/operations/grafana-aws.md).

The Grafana Cloud environment is optional and separate because it needs Cloud
tokens:

```bash
terraform -chdir=terraform/environments/grafana-cloud init
terraform -chdir=terraform/environments/grafana-cloud validate
```

## Cost warning

A real deployment is not free-tier-only. EKS control plane, worker nodes, NAT
gateway, RDS, ElastiCache, Route 53 and the ingress load balancer are billed
while they exist. The account has a USD 100/month budget, but the full stack is
≈ $280/month if the full self-hosted observability stack is running, so use the smallest instance classes that fit the
workloads and `terraform -chdir=terraform/environments/aws destroy` after the
demo. LocalStack is the zero-cost rehearsal path. See the
[dated resource-by-resource estimate](../docs/infrastructure/costs.md),
including the budget guardrail, node sizing and teardown caveats.

## Teardown

`protect_state = true` (the default) keeps RDS deletion protection and its final
snapshot, and blocks deleting non-empty S3 buckets and ECR repositories. Turn the
guards off first, then destroy:

```bash
terraform -chdir=terraform/environments/aws apply   -var protect_state=false
terraform -chdir=terraform/environments/aws destroy -var protect_state=false
```

The first command deletes no data. A final snapshot left behind and retained S3
versions keep billing until removed.

## Provider caveat

Terraform's AWS provider coverage against LocalStack is incomplete for EKS,
RDS, ElastiCache and CloudFront. Run `terraform validate` locally first, and
fall back to `awslocal` for any resource LocalStack rejects. Real AWS is the
source of truth for provider behavior.

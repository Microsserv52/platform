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

Kubernetes workloads are separate from this layer; see [`../k8s/README.md`](../k8s/README.md).

## Modules

| Module        | Resources                                                                 |
| ------------- | ------------------------------------------------------------------------- |
| `network`     | VPC, public/private subnets, internet gateway, NAT, route tables          |
| `ecr`         | One repository per service, scan-on-push and lifecycle policy             |
| `rds`         | PostgreSQL subnet group, security group and instance                      |
| `elasticache` | Redis subnet group, security group and single-node cluster                |
| `storage`     | Product media bucket, one bucket per frontend, CORS, lifecycle, versioning |
| `cloudfront`  | One distribution, S3 OACs, `/store`, `/admin`, `/media` and optional `/api` |
| `eks`         | Cluster, node group, OIDC provider, Product IRSA role, access entry       |
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
export TF_STATE_BUCKET=my-platform-tf-state   # optional but recommended
scripts/deploy-aws.sh --frontends
```

The deploy script performs, in order: state bootstrap, `terraform apply`, ECR
login and image push, kubeconfig export, Secret creation, overlay apply,
ConfigMap patch, IRSA annotation, rolling rollout, optional frontend sync and
CloudFront invalidation.

Required inputs before the first real deployment:

- `DEPLOY_EXCHANGE_PROVIDER_URL` and `DEPLOY_EXCHANGE_PROVIDER_API_KEY` for the
  real Exchange provider.
- `TF_VAR_cors_allowed_origins` including the admin origin.
- `TF_VAR_domain_name`/`TF_VAR_hosted_zone_id` (with `TF_VAR_create_dns=true`)
  or a pre-existing `TF_VAR_acm_certificate_arn` when using a custom domain.
- An nginx ingress controller installed in the cluster.

Use `--skip-terraform`, `--skip-images`, `--frontends` or `--no-auto-approve`
to control individual phases. Deployment is intentionally shell-first; there is
no CI/CD deploy workflow.

## State

Without `TF_STATE_BUCKET`, the AWS environment keeps state locally
(`-backend=false`). For shared or repeatable deployments, create the private
versioned bucket once:

```bash
TF_STATE_BUCKET=my-platform-tf-state scripts/bootstrap-tf-state.sh
```

The backend uses S3 native locking (`use_lockfile = true`), so no DynamoDB lock
table is required. State contains the generated RDS password: keep the bucket
private and encrypted.

## Cost warning

A real deployment is not free-tier-only. EKS control plane, worker nodes, NAT
gateway, RDS, ElastiCache, Route 53 and Secrets Manager are billed while they
exist. Use AWS Budgets, the smallest instance classes, and
`terraform -chdir=terraform/environments/aws destroy` after the demo. LocalStack
is the zero-cost rehearsal path.

## Provider caveat

Terraform's AWS provider coverage against LocalStack is incomplete for EKS,
RDS, ElastiCache and CloudFront. Run `terraform validate` locally first, and
fall back to `awslocal` for any resource LocalStack rejects. Real AWS is the
source of truth for provider behavior.

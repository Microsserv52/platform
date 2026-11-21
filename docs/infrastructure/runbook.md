---
icon: lucide/terminal
---

# Deployment runbook

Step-by-step operations for the two Kubernetes deployment modes:

- [Real AWS](#aws-deployment): Terraform provisions the infrastructure and
  shell scripts deploy from a logged-in workstation.
- [LocalStack rehearsal](#localstack-rehearsal): the same Terraform and
  Kubernetes contract against a local AWS emulator.

For the design rationale see [Deployment](deployment.md), [AWS setup](aws.md),
[EKS and Kubernetes](eks.md) and [LocalStack rehearsal](localstack.md). For the
files changed in this implementation see [Infrastructure changes](changes.md).

!!! info "No CI/CD deploy"

    AWS deployment is intentionally shell-first. `.github/workflows/deploy-eks.yml`
    was removed. CI still runs tests, CodeQL and documentation; it does not
    provision or deploy AWS resources.

## Prerequisites

| Tool        | Version   | Used by                                      |
| ----------- | --------- | -------------------------------------------- |
| Terraform   | >= 1.10   | both modes; 1.10 is required for S3 locking  |
| AWS CLI     | v2        | both modes                                   |
| `kubectl`   | >= 1.30   | both modes                                   |
| Docker      | current   | image builds and LocalStack                  |
| `jq`        | current   | deployment scripts                           |
| `openssl`   | current   | secret generation                            |

```bash
terraform version
aws --version
kubectl version --client
docker compose version
jq --version
```

Check out submodules before building Product and Exchange images:

```bash
git submodule update --init --recursive
```

## AWS deployment

### 1. AWS identity and permissions

Use IAM Identity Center (SSO) or an assumed role. Do not create long-lived
access keys. The deploying principal needs permissions for:

- VPC/EC2: VPC, subnets, route tables, internet/NAT gateways, security groups
- EKS: clusters, node groups, access entries, OIDC providers
- IAM: roles, policies, policy attachments, `iam:PassRole`
- ECR: repositories and image push/pull
- RDS and ElastiCache: subnet groups, security groups, instances/clusters
- S3: buckets, policies, CORS, lifecycle, versioning
- CloudFront: distributions, OACs, functions, invalidations
- Route 53 and ACM when `TF_VAR_create_dns=true`

### 2. Configure `.env`

```bash
cp .env.example .env
```

Fill at least:

```dotenv
JWT_SECRET=<paste output of: openssl rand -base64 48>
INTERNAL_SERVICE_SECRET=<paste output of: openssl rand -base64 32>
DEPLOY_EXCHANGE_PROVIDER_URL=https://provider.example.com
# Optional, only when the provider requires authentication:
# DEPLOY_EXCHANGE_PROVIDER_API_KEY=...
# DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY=false
# Optional extra CORS origins; CloudFront domain and aliases are automatic:
# TF_VAR_cors_allowed_origins=[]
```

Generate the two secrets first, then paste the values. Do not use `$(...)`
inside the file: Docker Compose reads `.env` literally.

| Variable | Required | Purpose |
| --- | --- | --- |
| `JWT_SECRET` | yes | shared signing secret for Gateway, Auth, Account, Order, Product, Exchange |
| `INTERNAL_SERVICE_SECRET` | yes | Auth to Account internal calls |
| `DEPLOY_EXCHANGE_PROVIDER_URL` | yes | real Exchange provider; falls back to a non-mock `EXCHANGE_PROVIDER_URL` |
| `DEPLOY_EXCHANGE_PROVIDER_API_KEY` | only when the provider requires it | stored in `platform-secrets` when set |
| `DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY` | optional | defaults to `false`; the service sends no `Authorization` header when false and no key is set |
| `TF_VAR_cors_allowed_origins` | optional | extra browser origins; the CloudFront domain and aliases are added automatically |
| `TF_STATE_BUCKET` | recommended | private versioned bucket for Terraform state |
| `TF_VAR_domain_name` | optional | custom frontend domain |
| `TF_VAR_hosted_zone_id` | optional | Route 53 zone for the domain |
| `TF_VAR_create_dns` | optional | `true` creates ACM certificate and validation records |
| `TF_VAR_acm_certificate_arn` | optional | use a pre-existing `us-east-1` certificate |
| `TF_VAR_api_domain_name` | optional | `api.example.com` |
| `TF_VAR_cloudfront_api_origin_domain` | required for `/api` through CloudFront | ingress/load-balancer hostname; do not use the CloudFront alias |
| `NEXT_PUBLIC_API_BASE_URL` | optional | defaults to `/api` |
| `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` | optional | defaults to the media bucket S3 origin |
| `TF_VAR_admin_principal_arn` | optional | grants another IAM principal EKS cluster admin |

!!! warning "Keep local values out of AWS"

    `EXCHANGE_PROVIDER_URL` above the AWS section points at the local Compose
    mock. AWS uses `DEPLOY_EXCHANGE_PROVIDER_URL`. Never set `ADMIN_EMAIL` or
    `ADMIN_PASSWORD` for AWS; the Account bootstrap is local-only.

### 3. Log in

IAM Identity Center:

```bash
aws configure sso --profile platform
aws sso login --profile platform
export AWS_PROFILE=platform
aws sts get-caller-identity
```

Access key alternative:

```bash
aws configure --profile platform
chmod 600 ~/.aws/credentials
aws sts get-caller-identity --profile platform
```

The deploy script also accepts `--login`, which logs in and exits:

```bash
export AWS_PROFILE=platform
scripts/deploy-aws.sh --login
scripts/deploy-aws.sh --frontends
```

### 4. Terraform state

`deploy-aws.sh` creates and uses a private, versioned, encrypted bucket named
`platform-tfstate-<account-id>` when `TF_STATE_BUCKET` is unset. The AWS backend
uses S3 native locking, so no DynamoDB table is needed. To reuse an existing
bucket instead:

```bash
export TF_STATE_BUCKET=my-platform-tf-state
scripts/bootstrap-tf-state.sh
```

### 5. Deploy

Review the plan interactively:

```bash
scripts/deploy-aws.sh --no-auto-approve
```

Apply and deploy in one step:

```bash
scripts/deploy-aws.sh
```

Include the static frontends and CloudFront invalidation:

```bash
scripts/deploy-aws.sh --frontends
```

The script runs these phases:

1. Validate AWS credentials and required inputs.
2. Bootstrap the S3 state bucket (default `platform-tfstate-<account-id>`).
3. `terraform init` and `terraform apply`.
4. Export the `admin` kubeconfig and create the namespace.
5. Install `metrics-server` and Cluster Autoscaler (unless `--skip-addons`).
6. Create `platform-secrets` from the RDS outputs and shared secrets.
7. Log Docker in to ECR and build/push the six service images.
8. Apply `k8s/overlays/aws`.
9. Patch `platform-config` with the media bucket, region, CloudFront origin and
   Exchange provider URL.
10. Annotate the `product` service account with its IRSA role.
11. Set image tags, restart and wait for each rollout.
12. Optionally build/sync landing, store and admin to S3 and invalidate
    CloudFront.

| Flag | Effect |
| --- | --- |
| `--skip-terraform` | reuse the current infrastructure and outputs |
| `--skip-images` | skip Docker build/push and reuse the requested `TAG` already in ECR |
| `--skip-addons` | do not install metrics-server or Cluster Autoscaler |
| `--frontends` | also build and upload the static frontends |
| `--no-auto-approve` | show the Terraform plan and require confirmation |
| `--login` | run `aws sso login --profile "$AWS_PROFILE"` and exit |

### 6. Generated Terraform outputs

```bash
terraform -chdir=terraform/environments/aws output
terraform -chdir=terraform/environments/aws output -raw cloudfront_domain_name
terraform -chdir=terraform/environments/aws output -json frontend_buckets | jq
```

The AWS environment creates:

| Layer | Resources |
| --- | --- |
| Network | VPC, two public and two private subnets, internet gateway, one NAT gateway |
| Registry | One ECR repository per backend service |
| Database | RDS PostgreSQL 17 in private subnets |
| Cache | Single-node ElastiCache Redis |
| Storage | Media bucket plus landing, store and admin buckets |
| CDN | One CloudFront distribution, OACs, `/store/*`, `/admin/*`, `/media/*`, optional `/api/*` |
| Kubernetes | EKS cluster, 2–6 node managed group, OIDC provider, Product IRSA, Cluster Autoscaler IRSA, optional access entry |
| DNS | Optional ACM certificate and Route 53 alias records |

Terraform creates the internet-facing Gateway NLB with a CloudFront-only
security group; the AWS overlay exposes Gateway as NodePort `30080` for that
target group, and CloudFront uses the NLB as the `/api` origin. An Ingress
controller is only needed for host-based ingress or additional TLS termination. The node group starts at
two `t3.medium` nodes and Cluster Autoscaler moves it to six when pods stay
`Pending`.

### 7. Verify

```bash
kubectl get nodes
kubectl -n kube-system get deploy metrics-server cluster-autoscaler
kubectl top nodes
kubectl -n platform get pods,svc,ingress,hpa,pdb
kubectl -n platform rollout status deployment/gateway --timeout=300s
kubectl -n platform get secret platform-secrets
kubectl -n platform get sa product -o yaml | grep eks.amazonaws.com/role-arn
```

Health check through the gateway:

```bash
kubectl -n platform port-forward svc/gateway 8080:8080
curl -fsS http://localhost:8080/actuator/health
```

Frontend:

```bash
terraform -chdir=terraform/environments/aws output -raw cloudfront_domain_name
```

When `TF_VAR_domain_name` is set, use `https://<domain>` instead.

### 8. Seed demo data manually

The seeder is never deployed. Run it against the public API after deployment:

```bash
DEMO_BASE_URL=https://app.example.com/api \
ADMIN_EMAIL=... \
ADMIN_PASSWORD=... \
python3 scripts/seed_demo.py
```

Create or promote the admin account with SQL first if it does not exist. See
[Get started](../development/get_started.md).

### 9. Update an existing deployment

| Change | Command |
| --- | --- |
| Application code only | `scripts/deploy-aws.sh --skip-terraform` |
| Frontends only | `scripts/deploy-aws.sh --skip-terraform --skip-images --frontends` |
| Infrastructure only | `scripts/deploy-aws.sh --skip-images` |
| Rebuild images without touching Terraform | `scripts/deploy-aws.sh --skip-terraform` |

### 9c. Use images published by CI

The manual **Publish EKS images** workflow pushes the six images without
touching the cluster. Deploy its tag with:

```bash
TAG=<workflow-tag> scripts/deploy-aws.sh --skip-terraform --skip-images
```

Omit `--skip-terraform` when the infrastructure itself also needs applying. The
workflow defaults to the full commit SHA; pass an explicit `tag` input to use a
shorter or release tag. See
[CI/CD](../development/cicd.md#eks-image-publishing-workflow).

### 9b. Roll back an application release

Image tags are the Git short SHA, so a previous release remains in ECR. Roll
back only the workloads; do not rebuild with `TAG=<old-sha>` because that would
build the current source under an old tag.

```bash
REGISTRY="$(terraform -chdir=terraform/environments/aws output -raw registry)"
PREVIOUS=<previous-short-sha>
for svc in account auth gateway order product exchange; do
  kubectl -n platform set image "deployment/$svc" "$svc=$REGISTRY/$svc:$PREVIOUS"
done
kubectl -n platform rollout status deployment/gateway --timeout=300s
```

Infrastructure rollback means reverting the Terraform change and applying it.
Database migrations must be backward-compatible; test the rollback plan before
relying on it.

### 10. Teardown

!!! danger "Destructive operation"

    Destroying the stack deletes EKS, RDS, ElastiCache, buckets, CloudFront and
    IAM resources. Take a backup first. RDS has deletion protection and final
    snapshots, and ECR repositories are not force-deleted by default.

The stack is protected by default (`protect_state = true`): RDS keeps deletion
protection and a final snapshot, and S3 and ECR refuse to delete non-empty
resources. Disable the guards first, then destroy. The first command does not
delete any data.

```bash
terraform -chdir=terraform/environments/aws apply   -var protect_state=false
terraform -chdir=terraform/environments/aws destroy -var protect_state=false
```

Keep `protect_state = true` for production. A final snapshot or retained S3
versions left behind keep billing until they are deleted explicitly.

### 11. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Unable to locate credentials` | no profile or expired SSO | `aws sso login --profile platform`, export `AWS_PROFILE` |
| `kubectl` returns Unauthorized | principal not mapped into EKS | set `TF_VAR_admin_principal_arn` to your IAM role ARN and re-apply |
| `ImagePullBackOff` | node role lacks ECR read or wrong image | check the node role policy and the ECR repository URL |
| Product returns S3 access denied | IRSA annotation missing or role policy wrong | check the `product` ServiceAccount annotation and the media bucket ARN |
| Exchange crash-loops | provider URL missing or a required key absent | set `DEPLOY_EXCHANGE_PROVIDER_URL`; set the key and `DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY=true` only if the provider requires auth |
| Frontend loads but `/api` returns 404 | `/api` is not routed through CloudFront | set `TF_VAR_cloudfront_api_origin_domain` or a reachable `NEXT_PUBLIC_API_BASE_URL` |
| Browser upload rejected | page origin not in S3 CORS or upload URL origin not in the admin allowlist | CloudFront and aliases are added automatically; add extra origins with `TF_VAR_cors_allowed_origins`, and the exact S3 URL to `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` |
| Ingress has no address | no ingress controller | use the Terraform Gateway NLB (CloudFront `/api`), or install ingress-nginx/ALB controller |
| TLS certificate error | no certificate/secret | use `TF_VAR_create_dns=true` or supply `TF_VAR_acm_certificate_arn` and a TLS secret |
| HPA shows `<unknown>` | metrics-server not installed or not ready | `kubectl -n kube-system get deploy metrics-server`; re-run without `--skip-addons` |
| HPA replica stays `Pending` and no node appears | Cluster Autoscaler cannot see the group | check the CA logs, IRSA annotation and the `k8s.io/cluster-autoscaler/*` ASG tags |
| Cluster Autoscaler is `CrashLoopBackOff` | wrong IRSA role or region | check `kubectl -n kube-system logs deploy/cluster-autoscaler` and the node group tags |

## LocalStack rehearsal

### 1. Prerequisites

- Docker with the Compose plugin and access to `/var/run/docker.sock`.
- Terraform >= 1.10, AWS CLI v2, `kubectl`, `jq`, `curl`.
- A LocalStack **Student** or paid auth token. Hobby does not include EKS, ECR,
  RDS, ElastiCache or CloudFront.

### 2. Configure `.env`

```dotenv
LOCALSTACK_AUTH_TOKEN=...
LOCALSTACK_IMAGE=localstack/localstack:2026.10.8
LOCALSTACK_SERVICES=s3,cloudfront,rds,elasticache,eks,ecr,iam,sts,ec2
LOCALSTACK_ENDPOINT=http://localhost:4566
LOCALSTACK_HOST=localhost.localstack.cloud:4566
LOCALSTACK_HOST_IP=
```

Do not add dummy `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` to `.env`.
`localstack-up.sh` exports test credentials and endpoints for its own commands,
and `deploy-aws.sh` explicitly ignores them. `LOCALSTACK_HOST_IP` is optional:
when empty, the script uses the LocalStack container IP on the k3d network so
pods can reach RDS/ElastiCache and S3.

### 3. Start the rehearsal

```bash
scripts/localstack-up.sh
```

If a healthy LocalStack already answers on `LOCALSTACK_ENDPOINT`, the script
reuses it instead of starting another container. To re-apply manifests without
rebuilding images already present in LocalStack ECR:

```bash
SKIP_IMAGES=true scripts/localstack-up.sh
```

The script:

1. Starts `compose.localstack.yml`.
2. Waits for `http://localhost:4566/_localstack/health`.
3. Runs `terraform apply` in `terraform/environments/localstack`.
4. Logs Docker in to LocalStack ECR and pushes all six images.
5. Builds the exchange-provider mock image.
6. Exports the LocalStack EKS kubeconfig.
7. Creates `platform-secrets`.
8. Applies `k8s/overlays/localstack`.
9. Patches `platform-config` with LocalStack RDS/Redis/S3 values.
10. Sets image tags and restarts the workloads.

### 4. Verify

```bash
curl -fsS http://localhost:4566/_localstack/health | jq
kubectl get nodes
kubectl -n platform get pods,svc,ingress
kubectl -n platform port-forward svc/gateway 8080:8080
curl -fsS http://localhost:8080/actuator/health
```

Terraform outputs:

```bash
terraform -chdir=terraform/environments/localstack output
terraform -chdir=terraform/environments/localstack output -raw eks_cluster_name
terraform -chdir=terraform/environments/localstack output -json frontend_buckets | jq
```

LocalStack S3:

```bash
aws --endpoint-url http://localhost:4566 s3 ls
aws --endpoint-url http://localhost:4566 ecr describe-repositories
```

### 5. Frontends on LocalStack

```bash
FRONTEND_BUCKETS="$(terraform -chdir=terraform/environments/localstack output -json frontend_buckets)" \
CLOUDFRONT_DISTRIBUTION_ID="$(terraform -chdir=terraform/environments/localstack output -raw cloudfront_distribution_id)" \
AWS_ENDPOINT_URL=http://localhost:4566 \
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080 \
NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS=http://localhost:4566 \
scripts/sync-frontends.sh
```

The Gateway expects paths such as `/products`; nginx and CloudFront strip the
`/api` prefix in the deployed modes. Direct LocalStack access is usually through
`kubectl port-forward svc/gateway 8080:8080`, so build the frontends with
`NEXT_PUBLIC_API_BASE_URL=http://localhost:8080` and keep the port-forward open.

### 6. Stop and reset

```bash
scripts/localstack-down.sh
```

This destroys the Terraform stack and removes the LocalStack volume. If the
script reused an existing container, that container is not stopped; only the
emulated resources are destroyed. All emulated data, buckets and images in the
stack are lost.

### 7. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| LocalStack exits at startup | missing or invalid auth token | set `LOCALSTACK_AUTH_TOKEN`; Student/paid is required for EKS |
| Health check never passes | Docker socket or port conflict | check `docker compose logs localstack` and port 4566 |
| Terraform cannot create a resource | provider coverage gap | use `awslocal <service> ...` for that resource |
| Pods cannot reach RDS/Redis | endpoints resolve to `localhost` or use a stale port | set `LOCALSTACK_HOST_IP` to the LocalStack container IP; the script re-reads the current endpoint ports on every run |
| Images cannot be pulled | k3s cannot resolve/authenticate to LocalStack ECR | verify the registry host and LocalStack ECR login |
| CloudFront URL does not serve assets | LocalStack edge emulation | test through S3/gateway directly; treat CloudFront as configuration-only |
| Product image calls fail | SDK endpoint/path-style and HTTPS presign gap | see the limitation below |

!!! warning "Product image limitation"

    Product is a submodule service. Its S3 client uses the AWS SDK default
    credential chain and does not expose a public/presign endpoint override.
    The LocalStack overlay sets `AWS_ENDPOINT_URL` and dummy credentials, which
    covers SDK-version-compatible calls. The full browser presign flow also
    needs HTTPS and an exact `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` match. Validate
    image persistence through the API first, then add LocalStack TLS.

## Related

- [LocalStack rehearsal](localstack.md)
- [Deployment](deployment.md)
- [Infrastructure changes](changes.md)
- [Terraform modules](https://github.com/Microsserv52/platform/blob/main/terraform/README.md)
- [Kubernetes overlays](https://github.com/Microsserv52/platform/blob/main/k8s/README.md)

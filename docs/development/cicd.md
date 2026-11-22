---
icon: lucide/git-pull-request
---

# CI/CD

Continuous integration keeps every change buildable and tested. Continuous
delivery produces a deployable artifact and promotes it through controlled
environments.

## Pipeline stages

1. Checkout the root repository and submodules.
2. Validate formatting, documentation links and configuration.
3. Build and test each changed service.
4. Build a container image and scan it for vulnerabilities.
5. Tag the image with an immutable commit or release identifier.
6. Push the image to the container registry.
7. Deploy to a non-production environment.
8. Run smoke and integration tests.
9. Require approval before production promotion.
10. Publish deployment, test and rollback evidence.

Each runnable service repository owns its CI/CD workflow:
`account`, `auth`, `gateway`, and `order-service` run lint, format, tests,
coverage quality gates, CodeQL, and publish an immutable GHCR image tagged
with the source commit. The `order` contract runs the same checks except image
publishing because it is a library.

The platform repository owns cross-service validation and the infrastructure
definitions. Its integration job pulls `sha-<submodule-commit>` images from
GHCR and builds only when the matching image is unavailable. Deployment is
shell-first: `scripts/deploy-aws.sh` runs Terraform and applies the Kubernetes
overlay. The manual **Deploy to AWS EKS** workflow calls the same script with
OIDC credentials and does not run on a push.

## Pipeline rules

- Do not use `latest` as the only deployment identifier.
- Do not print secrets in workflow logs.
- Pin or review action versions.
- Cancel superseded work where safe.
- Make migrations backward-compatible and observable.
- Keep a previous image available for rollback.
- Ensure deployment status and commit SHA are visible.
- Grant service workflows `packages: write` and the platform workflow
  `packages: read`.

## Deployment verification

After deployment, verify Gateway health, authentication, product retrieval,
order creation and currency conversion. Record the deployed versions of all
services, not only the Gateway image.

## Deployment model in this repository

CI covers build, tests, coverage gates, CodeQL and image publishing for the
service repositories. Deployment is **shell-first**: `scripts/deploy-aws.sh`
runs Terraform, installs the cluster add-ons, builds and pushes images, creates
the runtime Secret and applies the Kubernetes overlay. The manual
**Deploy to AWS EKS** workflow (`workflow_dispatch`, `production` environment)
calls the same script with repository OIDC credentials; it does not run on a
push.

This is a deliberate trade-off, not an unstated gap:

- no long-lived AWS keys are stored in GitHub;
- the same script is used for the recorded deployment and for recovery;
- the operator sees the Terraform plan and rollout failures directly.

Staging is applied manually from `terraform/environments/staging` and
`k8s/overlays/staging`. No workflow provisions or deploys it, and the staging
job does not run in CI.

## EKS image publishing workflow

`.github/workflows/publish-eks-images.yml` is a manual `workflow_dispatch`
workflow that builds and pushes the six backend images to ECR. It does **not**
run Terraform, install add-ons, change Kubernetes workloads or deploy to EKS.

| Setting | Value |
| --- | --- |
| Trigger | Manual **Run workflow** |
| Input | `tag`; defaults to the full commit SHA |
| AWS access | OIDC role `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION` |
| Permissions | `contents: read`, `id-token: write` |
| Environment | `production` (approval rules and environment secrets apply) |
| Output | Six ECR images plus a digest table in the job summary |

The role needs ECR push permissions:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
ecr:DescribeRepositories
```

No EKS permissions are required for this workflow. Apply Terraform first so the
six repositories exist; the workflow fails with a clear message if they do not.

Deploy an already-published tag from the shell:

```bash
# Existing infrastructure
TAG=<tag> scripts/deploy-aws.sh --skip-terraform --skip-images

# Apply Terraform and add-ons, but reuse the CI-published images
TAG=<tag> scripts/deploy-aws.sh --skip-images
```

The image contexts match `scripts/build-and-push-images.sh`: order is built from
`./api` with `api/order-service/Dockerfile`; Product and Exchange are built from
their submodule directories. Tests and CodeQL remain in the normal CI jobs; this
workflow only publishes artifacts.

## Rollback

Images are tagged with the Git short SHA and ECR keeps prior tags. Roll back the
workloads with `kubectl set image` to the previous SHA; do not rebuild under an
old tag. The full procedure is in the
[deployment runbook](../infrastructure/runbook.md#9b-roll-back-an-application-release).
Infrastructure rollback means reverting the Terraform commit and applying it;
database migrations must be backward-compatible.

## Evidence to record

For every deployment record: UTC time, account and region, cluster name,
Terraform state location, image tags, add-on versions, node count, HPA state,
health-check result, cost estimate and any known gap. The
[delivery evidence](../project/delivery.md) page is the index.

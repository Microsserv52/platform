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

The repository currently publishes documentation through
[`.github/workflows/docs.yml`](../.github/workflows/docs.yml). Service
repositories should own their build and image workflows; the integration
repository should own cross-service validation and deployment coordination.

## Pipeline rules

- Do not use `latest` as the only deployment identifier.
- Do not print secrets in workflow logs.
- Pin or review action versions.
- Cancel superseded work where safe.
- Make migrations backward-compatible and observable.
- Keep a previous image available for rollback.
- Ensure deployment status and commit SHA are visible.

## Deployment verification

After deployment, verify Gateway health, authentication, product retrieval,
order creation and currency conversion. Record the deployed versions of all
services, not only the Gateway image.

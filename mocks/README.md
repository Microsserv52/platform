# Local mocks (platform root)

Deterministic stand-ins that let the integration stack and the individual
services run without third-party accounts. They are development and CI
fixtures only: no Kubernetes manifest deploys them and every mock refuses to
start when `ENV` or `APP_ENV` is `prod` or `production`.

| Mock | Used by | Purpose |
| --- | --- | --- |
| [`identity`](identity/) | Product standalone stack | Signs HS256 tokens with the same `JWT_SECRET` Product validates. |
| [`image-storage`](image-storage/) | Platform stack, Product standalone stack | Emulates S3-compatible blob storage for product images. |
| [`exchange-provider`](exchange-provider/) | Platform stack, Exchange standalone stack | Emulates the third-party exchange-rate provider, including failure modes. |

Mocks are consumed through the Compose files (`mocks/<name>` build contexts);
they are excluded from every image through each service's `.dockerignore`.

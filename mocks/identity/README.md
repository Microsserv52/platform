# Local identity mock

Deterministic HS256 token issuer used by the standalone Product Compose stack
and by the smoke test. It is not part of the Product service and must never be
deployed to production.

```bash
curl -s -X POST http://localhost:8081/token \
  -H 'Content-Type: application/json' \
  -d '{"sub":"0195ae95-5be7-7dd3-b35d-7a7d87c404fb","roles":["ROLE_ADMIN"]}'
```

The response contains `access_token`, `token_type` and `expires_in`. Tokens are
signed with `JWT_SECRET`, which Compose passes to both this mock and Product.

## Local only — never in production

The mock refuses to start when the environment declares production. If `ENV`
or `APP_ENV` is `prod` or `production` (case-insensitive), the process prints
`refusing to start: ...` and exits with status `1` before binding any port:

```bash
ENV=production python server.py   # exits 1
```

Compose never sets those variables for the `identity` service, the mock is not
part of the Product image, and no Kubernetes manifest or CI workflow deploys
it. Do not add `ENV`/`APP_ENV` to the Compose `identity` section and do not
bake this image into a deployment.

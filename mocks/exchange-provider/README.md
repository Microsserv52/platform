# Exchange provider mock (platform root)

Deterministic local stand-in for the third-party exchange-rate provider used by
the platform-root `compose.yml` service `exchange-provider-mock` and by the
Exchange standalone stack. It lets both run without a real provider key. It is
not part of any Kubernetes manifest, CI workflow or production deployment.

## Endpoints

| Path | Purpose |
| --- | --- |
| `GET /health` | Liveness probe used by Compose. |
| `GET /latest?base=USD&symbols=EUR` | Fixed USD-based rates, rebased on `base`, returned as `bid`/`ask` per currency. |
| `GET /v1/latest`, `GET /latest.json` | Provider-compatible aliases. |
| `GET /control`, `POST /control?mode=...` | Reads or switches the `MOCK_MODE` used by the failure-path tests. |

`GET /latest` defaults to `base=USD` and `symbols=EUR`. Rates are fixtures
relative to USD (EUR, BRL, GBP, JPY), not live financial data. Unsupported base
or quote currencies return HTTP `400` with an error code.

## Failure modes

`MOCK_MODE` (or `/control?mode=...`) accepts `ok`, `error`, `timeout`,
`malformed`, `rate_limit` and `unsupported`. `ok` is the default, so the
platform stack boots without extra configuration. `MOCK_API_KEY`, when set,
requires `Authorization: Bearer <key>`, matching the provider contract.

## Local only — never in production

The mock refuses to start when the environment declares production. If `ENV`
or `APP_ENV` is `prod` or `production` (case-insensitive), it prints
`refusing to start: ...` and exits with status `1` before binding the port:

```bash
ENV=production python server.py   # exits 1
```

The platform Compose stack does not set `ENV`/`APP_ENV` for this service. To
use a real provider instead, set `EXCHANGE_PROVIDER_URL` and
`EXCHANGE_PROVIDER_API_KEY` in `.env`; do not deploy this mock anywhere.

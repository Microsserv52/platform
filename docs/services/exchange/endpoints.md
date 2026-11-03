---
icon: lucide/route
---

# Endpoints

!!! warning "Attention"

    **To consume the API, the user must be authenticated.**

!!! info "GET /exchanges/{from}/{to}"

    Get the current exchange rate from one currency to another. E.g. `GET /exchanges/USD/EUR`.

    === "Response"

        ``` { .json .copy .select linenums='1' }
        {
            "sell": 0.82,
            "buy": 0.80,
            "date": "2021-09-01 14:23:42",
            "id-account": "0195ae95-5be7-7dd3-b35d-7a7d87c404fb"
        }
        ```
        ```bash
        Response code: 200 (ok)
        ```

    The `{from}` and `{to}` path parameters are ISO 4217 currency codes. The
    response is produced from the configured third-party provider and should
    include a timestamp for the rate used. Unsupported currencies should
    return `422 (unprocessable entity)`; provider failures should return an
    explicit `502 (bad gateway)` or equivalent service-unavailable response.

# Third-party service

Exchange must obtain rates from an external provider. The provider is an
implementation choice; the course exercise lists [AwesomeAPI](https://github.com/awesomeapibrasil/economy-api),
[ExchangeRate-API](https://www.exchangerate-api.com/), [Open Exchange
Rates](https://openexchangerates.org/) and [CurrencyLayer](https://currencylayer.com/)
as examples.

## Adapter requirements

- Configure the base URL and API key through environment variables.
- Set a connection and response timeout.
- Validate and normalize the provider response.
- Cache rates only for a documented, short period.
- Return an explicit error when the provider is unavailable or the currency is
  unsupported.
- Do not log API keys or full provider responses when they contain sensitive
  data.

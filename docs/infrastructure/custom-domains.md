---
icon: lucide/globe
---

# Custom domains

## Current limitation

**There is no custom domain and no stable branded URL.** The public application
uses the generated CloudFront hostname:

```text
https://d15ogksm4jp6sl.cloudfront.net/
https://d15ogksm4jp6sl.cloudfront.net/store/
https://d15ogksm4jp6sl.cloudfront.net/admin/
https://d15ogksm4jp6sl.cloudfront.net/api/
```

The Gateway NLB hostname is an internal origin, not a user-facing URL. Grafana
has no public hostname; use `kubectl port-forward` or the prepared ALB + Cognito
ingress once a domain exists.

Consequences:

- URLs change if the CloudFront distribution is recreated.
- There is no branded TLS certificate; CloudFront uses its default certificate.
- Cookies, CORS, CSP, Faro CORS and Cognito callbacks are tied to the CloudFront
  hostname.
- An ALB-backed Grafana cannot have a stable HTTPS hostname without an ACM
  certificate.
- Edge WAF and logging rules are harder to document and test against a changing
  hostname.

## What is needed to add one

### 1. Register the domain and DNS

- Register or transfer the domain to Route 53, or keep the registrar and create
  a Route 53 public hosted zone.
- Delegate the domain's name servers to the Route 53 zone.
- Decide the names, for example:
  - `app.example.com` for the frontend and API;
  - `grafana.example.com` for observability.

### 2. Request ACM certificates

- **CloudFront:** certificate in `us-east-1`.
- **ALB / regional endpoints:** certificate in the ALB region (`us-east-1` for
  this stack).
- Validate with DNS records in the hosted zone.
- ACM public certificates are free; Route 53 hosted zones cost about
  $0.50/month plus query charges.

### 3. Attach the CloudFront alias

Update the Terraform variables or console:

```bash
export TF_VAR_domain_name=app.example.com
export TF_VAR_hosted_zone_id=Z0123456789EXAMPLE
export TF_VAR_create_dns=true
```

The existing DNS module can create the ACM certificate and Route 53 alias when
`create_dns=true`. Confirm the module still matches the intended hostname and
that the certificate is in `us-east-1` for CloudFront.

If using an externally managed certificate, set `TF_VAR_acm_certificate_arn`
instead and create the alias record manually.

### 4. Update application origins

After the alias works:

- `TF_VAR_cors_allowed_origins` and the media bucket CORS origins;
- `NEXT_PUBLIC_API_BASE_URL` if the frontend must call an absolute API origin;
- `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` and product upload CORS;
- `SESSION_COOKIE_SECURE=true` and any cookie domain/path settings;
- Grafana `GF_SERVER_ROOT_URL`, cookie settings and allowed origins;
- Faro `cors_allowed_origins` and `NEXT_PUBLIC_FARO_URL`;
- Cognito callback and sign-out URLs for the Grafana ALB;
- WAF, CSP and any allowlists that contain the old hostname.

### 5. Publish and verify

1. Rebuild the static frontends with the final public origin values.
2. Sync them to S3 and invalidate CloudFront.
3. Verify HTTPS, HSTS, redirects and certificate chain.
4. Verify cookies are Secure and not sent cross-site unexpectedly.
5. Verify `/api/products`, login, order, admin upload and media download.
6. Verify Grafana only after Cognito authentication.
7. Keep the CloudFront hostname as a fallback until DNS TTLs and clients settle.

## Cost

| Item | Approximate |
| --- | ---: |
| Route 53 hosted zone | $0.50/month |
| Domain registration | ~$12/year, registrar-dependent |
| ACM public certificate | $0 |
| ALB for Grafana | ~$20/month, optional |
| AWS WAF | web ACL + request charges, optional |

## What is intentionally not done

- No domain is registered or transferred.
- No hosted zone or certificate is created.
- No CloudFront alias, ALB hostname or Cognito callback is configured.
- No DNS change is made by this repository.

Documenting the steps does not create the domain.

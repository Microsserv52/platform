---
icon: lucide/clipboard-check
---

# Product image verification

Product images use S3 for object storage and CloudFront for delivery. The
backend contract lives in [`api/product`](../../../api/product/); the browser
requests a presigned upload, sends the file with the required conditional
header and attaches the resulting object to the product. The frontend checks
below use the fixture server and do not provision S3 or CloudFront.

## Automated checks

Landing, Store and Admin pass formatting, ESLint, TypeScript, six unit tests,
static export and desktop/mobile browser suites. Pre-commit checks pass and the
Dockerfiles build. No additional frontend package or lockfile dependency is
required; the AWS SDK belongs to the Product backend.

The stdlib fixture tests run with:

```bash
python3 -m unittest discover -s tests/frontend -p 'test_*.py'
```

They cover upload, replace, content reads, alt edits, removal, unchanged other
products, missing CSRF, non-admin access, invalid size/type/dimensions, expired
tickets, wrong-length files and replay or overwrite rejection. The fixture keeps
bytes and tickets in memory and trusts client dimensions; these are contract
checks, not proof of S3 or Product security.

## Browser coverage

| State | Verified behavior |
| --- | --- |
| Public image | Decodes with nonzero width and the supplied alternative text |
| Failed fetch | Shows the unavailable-image fallback |
| Legacy product | Optional image field remains compatible |
| Manage image | Opens the product dialog for an administrator |
| Empty dialog | Save stays disabled until a valid selection |
| Invalid file | Shows JPEG/PNG and size validation |
| File selection | Previews the selected fixture image |
| Save | Requests authorization, sends the conditional PUT and attaches the object |
| Replace | Renders the new versioned URL |
| Alt edit | Updates metadata without another upload |
| Remove | Confirmation; Keep cancels, Confirm removes the reference |
| Cancel / Escape | Dismisses the overlay without saving |
| Theme | Light and dark dialogs render |
| Mobile | The page stays within the viewport and the dialog scrolls internally |

The media surface uses a neutral gray background so transparent images remain
visible in both themes. Cards crop consistently; the detail view contains the
entire image.

## Acceptance gaps

Real S3 credentials, IAM policy, CORS, lifecycle cleanup, concurrency protection
and CloudFront caching are verified only when the Product service runs against
the AWS bucket. The same UI flows must then run against the real services with
uploads enabled. The fixture is not evidence of cloud persistence.

## Related

- [Frontend verification](verification.md)
- [Product image handoff](../services/product/images.md)
- [Product images in the frontend](product-images.md)
- [Dependencies](dependencies.md)

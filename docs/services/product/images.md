---
icon: lucide/image-plus
---

# Image implementation handoff for the future Product service

The owner selected **S3 + CloudFront** and approved the AWS SDK. Product does
not exist yet, so this is the required backend contract, not a working S3
integration. Do not move product ownership into Gateway or a frontend repository.
The initial UI supports file uploads only; importing external URLs is deferred.

## Frontend contract

Existing product fields remain unchanged. Add a nullable/optional `image`:

```json
{
  "url": "/media/products/PRODUCT_UUID/ASSET_UUID/original.png",
  "alt": "A description of the product image",
  "width": 1200,
  "height": 800
}
```

The frontend accepts HTTPS image URLs and same-origin `/media/` paths. The local
fixture also uses `/api/products/{id}/image/content?version={uuid}`. That endpoint
is test infrastructure and is not required for S3 delivery. Old products without
`image` continue to render an explicit unavailable-image placeholder.

All following mutation routes are below `/products/{id}/image`, with Gateway's
public `/api` prefix added by browser clients. Product must enforce ROLE_ADMIN
itself, in addition to Gateway's existing write restrictions. Cookie requests
also require the Gateway CSRF exchange.

| Method / suffix       | Request                                                                                         | Successful response                                                                                                   |
| --------------------- | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| POST `/uploads`       | `fileName`, `contentType`, `size`, `width`, `height`                                            | 201: `uploadId` UUID, absolute `uploadUrl`, `uploadHeaders: {"If-None-Match":"*"}`; optional explicit UTC `expiresAt` |
| PUT to `uploadUrl`    | Raw file bytes; `Content-Type` equals the approved type; no API cookies or Authorization header | 200 or 204 from S3                                                                                                    |
| PUT at image route    | `uploadId`, `alt`                                                                               | 200: complete updated product, including `image`                                                                      |
| PATCH at image route  | `alt`                                                                                           | 200: complete updated product                                                                                         |
| DELETE at image route | No body                                                                                         | 200: complete updated product with `image: null`                                                                      |

Do not return 204 for image attachment, alt editing or removal: the UI validates
the returned product. Use 400/422 for invalid metadata/file, 401/403 for access,
404 for missing products/assets, 409 for stale/consumed tickets or conflicts,
413 for oversize files, and 429 for upload limits. Mutations do not auto-retry.
The `uploadUrl` is a short-lived capability, never the saved display URL.

## Required database changes

- Add image metadata in the Product-owned migration system. No migration has
  been executed or invented against an unknown Product schema.
- A product has at most one attached image. Track asset UUID, owning product,
  object key, content type, byte count, measured dimensions, alternative text,
  uploader identity, state and explicit UTC creation/expiry timestamps.
- Track pending upload tickets separately from the attached image. Generate keys
  server-side under `media/products/{productId}/{assetId}/`; never use a supplied
  filename as a storage path.
- Persist the immutable object key and metadata, then derive the public URL
  from the configured media origin/path. Avoid storing provider-specific signed
  URLs or image bytes/base64 in product JSON or PostgreSQL for this selected design.
- Product deletion detaches its reference. A retryable cleanup process deletes
  unreferenced old assets and expired pending uploads. Account for rollback and
  concurrent updates before deleting objects. Keep deletion/attachment idempotent
  and use optimistic locking so concurrent saves cannot silently lose references.
- Existing products migrate with no image. Rollback must retain asset records
  until recovery/retention decisions are made, not immediately destroy files.

## S3 implementation requirements

Use the official AWS SDK in Product's eventual implementation language. For a
Java service, use AWS SDK for Java v2's S3 client and S3 presigner with its
official BOM/setup. Select and lock a supported version when the service exists.
No AWS SDK belongs in the static frontend; none has been installed there.

1. Authorize the administrator and confirm the product exists before creating a
   ticket. Allow JPEG/PNG only, at most 5 MiB, up to 4096 pixels per side and
   16 million pixels. Frontend measurements are advisory, not proof.
2. Create a bounded-lifetime ticket with a unique immutable object key. Issue a
   presigned PUT scoped to that key, content type and `If-None-Match: *`.
   Enforce conditional writes in the bucket policy so a consumed object's bytes
   cannot subsequently be overwritten with the same upload authorization.
   The frontend forwards only that allowlisted conditional header, never arbitrary
   backend-supplied headers. Rate-limit ticket issuance.
3. At completion, verify ticket owner/product/expiry/state, object existence,
   actual length and content. Reject oversized, malformed or mislabeled files.
   In Java, native ImageIO can validate the selected JPEG/PNG formats; inspect
   dimensions before full decode. Do not trust S3 Content-Type metadata alone.
4. Atomically attach the validated asset and mark the ticket consumed. Until that
   succeeds, the old image remains the product's image. Prevent concurrent overwrite
   or post-validation replacement of the validated object using conditional S3
   writes/object versions and the database's attachment/version policy.
5. Return the updated product. Replacements use a new key/URL. Failed or abandoned
   uploads remain unattached and are removed by cleanup/lifecycle rules.

Use private S3 storage, backend workload identity and least-privilege prefix
access. CloudFront OAC reads the image origin. Configure CORS for the selected
frontend origin and PUT/Content-Type/If-None-Match; the upload client sends no cookies and
uses no-referrer. Backend logs/telemetry must not record signed query strings,
file bytes, credentials or private account data.

## CDN and environment configuration

Route `/media/*` on the same domain to the S3 origin with matching `media/`
object keys. Versioned image responses can use public long-lived immutable
caching, whereas product metadata remains revalidated through the API.
Alt-only changes do not change image bytes. Immediate removal from all CDN edges
requires explicit invalidation; deletion in admin must not promise immediate
purging of previously cached public files.

Ask the owner at deployment for AWS region, bucket, identity/IAM, domain,
CloudFront origin/behavior, CORS and lifecycle/retention values. Do not provision
cloud resources or introduce frontend Kubernetes deployment as part of this work.

Admin build values:

| Variable                                   | Meaning                                                                                               |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS` | Defaults false; enable only when the real contract is accepted. Explicitly true in local fixture mode |
| `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS`         | Comma-separated exact HTTPS S3 origins permitted for uploads; contains no credentials                 |

An HTTPS upload URL outside the allowlist is rejected before file transmission.
Local fixture mode has a narrow same-origin `/api/fixture-media-upload/` exception.
That test route uses in-memory tickets/files, trusts fixture dimensions and
does not prove real image validation, S3 persistence or production security.

## Acceptance when Product exists

- Implement these routes and migrations in Product; integrate its real repository
  and image into platform without replacing it with the fixture service.
- Verify public product/image reads and admin-only presign/attach/edit/remove,
  including ordinary users, expired sessions and CSRF failures.
- Test malformed files, mismatched MIME/size/dimensions, forged/reused/expired
  tickets, foreign product/account tickets, concurrent saves and cleanup failures.
- Verify actual S3 object validation, CORS, SDK credentials, retries, object-version
  protection, CloudFront headers and versioned cache behavior.
- Run browser upload, replace, alt-edit, cancel and remove flows against the real
  backend, not just UI fixtures. Only then enable uploads outside fixture mode.

## Official implementation references

- [AWS SDK for Java v2 setup](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/setup-project-maven.html)
- [Presigned S3 uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)
- [CloudFront origin access control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)

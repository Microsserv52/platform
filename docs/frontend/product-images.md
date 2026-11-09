---
icon: lucide/image
---

# Product image storage options

Selected storage: **Amazon S3**, with the AWS SDK approved by the owner.
CloudFront is the current image-delivery baseline. A potential move to Cloudflare
CDN remains open, independently of the selected Cloudflare security layer; R2
storage has not been selected. The Product
service will be created later. Frontend rendering and admin image management are
implemented against the [future Product contract](../services/product/images.md),
with a disposable local fixture for testing. Real S3 persistence is deferred to
that service. No cloud resource or paid feature has been provisioned, and no
unused AWS dependency has been installed in a frontend or Gateway.

## Options

| Option                           | Fit                                                                                                                                            | Tradeoff                                                                                                              |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Amazon S3 + CloudFront           | Recommended for alignment with the existing AWS backend; short-lived authorized upload URLs and private bucket delivery through CloudFront OAC | Requires AWS storage/CDN configuration and approval of the backend SDK                                                |
| Cloudflare R2 + Cloudflare cache | Alternative if Cloudflare will own image delivery; S3-compatible upload interface and cached custom-domain delivery                            | R2 presigned uploads use its S3 endpoint, separately from the public custom-domain delivery URL                       |
| Vercel Blob                      | Managed browser uploads if the owner chooses the Vercel ecosystem                                                                              | Needs an authenticated token-issuing backend and approval of its SDK; static Next.js exports cannot host this handler |
| Azure Blob Storage               | Managed object storage if Azure is preferred; supports HTTP image delivery                                                                     | Adds Azure configuration and a provider SDK; CDN/edge delivery must be configured separately                          |
| PostgreSQL bytea + API + CDN     | Viable for a small mock catalog without a separate object store                                                                                | Images increase database/backup traffic; cache misses read through the API and database; CDN needs an HTTP endpoint   |

The recommendation is an architectural judgement for this project, not a price
comparison. Region, expected storage/traffic and account plans must be known
before comparing actual costs.

PostgreSQL supports binary bytes through `bytea`, as well as a separate Large
Object facility. For small product images, `bytea` in a separate image table is
the simpler database option. Do not put base64 image strings in product JSON.
A CDN does not query PostgreSQL: an API must return the image bytes, content
type and caching headers over HTTP.

## Implemented frontend and selected backend behavior

Keep product records in their owning service. Persist an object key and image
metadata such as alternative text, content type, byte size and dimensions.
Expose a stable image URL to the frontend. Do not persist an expiring upload
URL as the product's display URL. With database storage, return a stable image
API URL instead.

1. An administrator selects a file and sees a preview.
2. The backend checks administrator permission and CSRF, validates the upload
   request and issues a narrowly scoped, expiring upload authorization.
3. After uploading, the backend verifies the actual stored file before attaching
   it to the product. Client-declared filename and content type are insufficient.
4. Catalog/detail views render the returned URL with dimensions and alternative text.
5. Replacing an image creates a new versioned key/URL, then changes the product
   reference. That allows long CDN caching without showing the previous image.
6. Removing/replacing images schedules safe cleanup after checking references;
   failed uploads do not destroy the existing image.

Storage credentials stay in backend configuration. Admin controls manage product
images, not cloud account secrets. The eventual CDN can route `/media/*` on the
shared domain to the image origin; the hosting/domain decision stays deferred.

The initial defaults are one image per product,
JPEG/PNG, at most 5 MB, preview/upload/replace/remove, editable alternative text,
and visible loading/error feedback. File uploads are implemented; URL importing remains deferred. It
requires a controlled server-side download process, validation, and protection
against requests to internal services. Saving an arbitrary remote URL alone
does not copy its contents into owned blob storage.

## Implementation prerequisites

- Create Product in its own future repository and implement the saved
  [backend handoff](../services/product/images.md), including migrations, the
  approved AWS SDK, validation, object cleanup and rollback.
- Accept the real backend contract before enabling uploads in a normal
  environment. `NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS` defaults false.
- Configure the exact HTTPS upload origins in admin's public build values;
  credentials stay in the backend. Ask the owner for deployment values later.
- The Docker fixture enables uploads explicitly. Files/tickets live in memory
  and reset on fixture restart; the fixture is not S3 or production validation.
- Preserve the mock-store notice and run real service/CDN acceptance before
  claiming cloud image persistence. See [image verification](image-verification.md).

## Official references

- [S3 authorized uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)
- [CloudFront S3 origin access control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)
- [R2 CDN caching](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/)
- [Vercel Blob browser uploads](https://vercel.com/docs/vercel-blob/client-upload)
- [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)
- [PostgreSQL binary storage](https://www.postgresql.org/docs/current/datatype-binary.html)

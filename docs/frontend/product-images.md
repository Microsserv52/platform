---
icon: lucide/image
---

# Product images

Product images use **Amazon S3** for storage and **CloudFront** for delivery.
The Product service in [`api/product`](../../../api/product/) implements the
upload contract; the frontend renders the returned URL with alternative text and
dimensions and exposes admin upload controls when
`NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS` is enabled.

Local Compose uses the HTTP image-storage mock in
[`mocks/image-storage`](../../../mocks/image-storage/). Its files and upload
tickets live in memory and reset on restart; it is not S3 and does not prove
cloud persistence. The full contract is in the
[Product image handoff](../services/product/images.md).

## Upload flow

1. An administrator selects a JPEG or PNG and sees a preview.
2. Product checks `ROLE_ADMIN` and CSRF, validates the request and returns a
   short-lived upload authorization.
3. The browser sends the file with the required conditional header.
4. Product re-reads the stored object, verifies its bytes and dimensions, and
   attaches it to the product.
5. Catalog and detail views render the returned URL with alternative text.
6. Replacing an image writes a new versioned key and changes the product
   reference; the previous object remains until lifecycle cleanup.

Product stores the object key, content type, byte size, dimensions and
alternative text. It does not store an expiring upload URL as the display URL.

## Limits

- One image per product.
- JPEG or PNG only, at most 5 MiB, at most 4096 px per side and at most 16
  million pixels.
- Upload, replace, remove and alternative-text editing are supported.
- External URL import is not implemented. It would require a server-side
  download, validation and protection against internal-network requests.
- Upload credentials stay in the backend; the browser receives only a scoped,
  expiring authorization.

## Deployment configuration

| Setting | Purpose |
| --- | --- |
| `PRODUCT_IMAGE_MODE=s3` | Selects the S3 backend; Compose defaults to `mock` with `PRODUCT_IMAGE_STORAGE_URL` |
| `PRODUCT_IMAGE_S3_BUCKET` | Private media bucket |
| `PRODUCT_IMAGE_S3_REGION` | Bucket region |
| `PRODUCT_IMAGE_S3_MEDIA_ORIGIN` | Optional public media origin; CloudFront in the AWS deployment |
| `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS` | Exact HTTPS origins allowed to upload from the admin build |

The media bucket blocks public access and is read through CloudFront OAC or
short-lived presigned URLs. CORS and bucket policy are managed by Terraform. The
[image verification](image-verification.md) page lists the fixture coverage and
the checks that require the real services.

## Related

- [Product image handoff](../services/product/images.md)
- [Image verification](image-verification.md)
- [Frontend overview](overview.md)

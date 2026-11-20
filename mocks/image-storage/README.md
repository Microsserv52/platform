# Image storage mock (platform root)

Deterministic local stand-in for the S3 blob storage used for product images,
used by the platform-root `compose.yml` service `image-storage`. It lets the
local stack run the full image flow (presigned upload → validate → attach)
without any AWS account. It is not part of any Kubernetes manifest, CI
workflow or production deployment.

Objects are stored as files under `IMAGE_STORAGE_DATA_DIR` (mounted as the
`image-storage-data` volume) so they survive restarts.

## Endpoints

| Path | Purpose |
| --- | --- |
| `GET /health` | Liveness probe used by Compose. |
| `PUT /upload/{key}` | Stage a pending upload. Honors `If-None-Match: *` (`412` when the key exists). |
| `GET /object/{key}` | Read an object (used by the Product service after upload). |
| `PUT /object/{key}` | Write an object. Honors `If-None-Match: *` (`412` when the key exists). |
| `DELETE /object/{key}` | Delete an object (`204`). |
| `GET /media/{key}` | Public read-only access served through the nginx `/media/` edge path. |

Objects are capped at 5 MiB, matching the Product image limit. The key must be
a relative path segment list (`pending/products/...` or `media/products/...`);
anything with `..`, backslashes or absolute paths is rejected.

## Local only — never in production

The mock refuses to start when the environment declares production. If `ENV`
or `APP_ENV` is `prod` or `production` (case-insensitive), it prints
`refusing to start: ...` and exits with status `1` before binding the port:

```bash
ENV=production python server.py   # exits 1
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `IMAGE_STORAGE_DATA_DIR` | `/data` | Where objects are stored. |
| `IMAGE_STORAGE_PORT` | `8090` | Port to bind. |

## Running locally

```bash
docker compose up image-storage
curl -X PUT --data-binary @tomato.jpg \
  -H 'Content-Type: image/jpeg' -H 'If-None-Match: *' \
  http://localhost:8090/upload/pending/products/00000000-0000-0000-0000-000000000001/asset/original.jpg
```

The Product service points at this mock through `PRODUCT_IMAGE_MODE=mock`
and `PRODUCT_IMAGE_STORAGE_URL=http://image-storage:8090`. The browser reads
attached images through the nginx `/media/` proxy, mirroring the public media
origin used in production (CloudFront). To use real AWS S3 instead, set
`PRODUCT_IMAGE_MODE=s3` and the `PRODUCT_IMAGE_S3_*` variables documented in
`api/product/docs/configuration.md`; do not deploy this mock anywhere.

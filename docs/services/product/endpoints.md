---
icon: lucide/route
---

# Endpoints

!!! warning "Attention"

    The selected frontend policy permits public catalog GETs and requires
    ROLE_ADMIN for product writes at Gateway. The Product service enforces the
    same policy itself, including every image mutation. See
    [image implementation handoff](images.md) and
    [integration limits](../../frontend/architecture.md#remaining-service-prerequisites).

The Product API must expose the following endpoints:

!!! info "POST /products"

    Create a new product.

    === "Request"

        ``` { .json .copy .select linenums='1' }
        {
            "name": "Tomato",
            "price": 10.12,
            "unit": "kg"
        }
        ```

    === "Response"

        ``` { .json .copy .select linenums='1' }
        {
            "id": "0195abfb-7074-73a9-9d26-b4b9fbaab0a8",
            "name": "Tomato",
            "price": 10.12,
            "unit": "kg"
        }
        ```
        ```bash
        Response code: 201 (created)
        ```

!!! info "GET /products"

    Get all products.

    === "Response"

        ``` { .json .copy .select linenums='1' }
        [
            {
                "id": "0195abfb-7074-73a9-9d26-b4b9fbaab0a8",
                "name": "Tomato",
                "price": 10.12,
                "unit": "kg"
            },
            {
                "id": "0195abfe-e416-7052-be3b-27cdaf12a984",
                "name": "Cheese",
                "price": 0.62,
                "unit": "slice"
            }
        ]
        ```
        ```bash
        Response code: 200 (ok)
        ```

!!! info "GET /products/{id}"

    Get a product by its ID.

    === "Response"

        ``` { .json .copy .select linenums='1' }
        {
            "id": "0195abfb-7074-73a9-9d26-b4b9fbaab0a8",
            "name": "Tomato",
            "price": 10.12,
            "unit": "kg"
        }
        ```
        ```bash
        Response code: 200 (ok)
        ```

!!! info "DELETE /products/{id}"

    Delete a product by its ID.

    ```bash
    Response code: 204 (no content)
    ```

## Images

Every product response includes an `image` field: `null` when the product has
no image, otherwise the object below. Only `image/jpeg` and `image/png` are
accepted, up to 5 MiB, 4096 px per side and 16 million pixels. Uploading is a
two-step presigned flow; see [image implementation handoff](images.md).

```json
{
  "url": "/media/media/products/0195abfb-7074-73a9-9d26-b4b9fbaab0a8/0195ac10-5c1f-7c2a-9f3d-9a5b0b0e7a13/original.jpg",
  "alt": "Fresh ripe tomatoes",
  "width": 1200,
  "height": 1000
}
```

!!! info "POST /products/{id}/image/uploads"

    Create a short-lived presigned upload ticket. `ROLE_ADMIN` required.

    === "Request"

        ``` { .json .copy .select linenums='1' }
        {
            "fileName": "tomato.jpg",
            "contentType": "image/jpeg",
            "size": 245678,
            "width": 1200,
            "height": 1000
        }
        ```

    === "Response"

        ``` { .json .copy .select linenums='1' }
        {
            "uploadId": "0195ac10-5c1f-7c2a-9f3d-9a5b0b0e7a11",
            "uploadUrl": "https://bucket.s3.eu-west-1.amazonaws.com/pending/products/...",
            "uploadHeaders": {"If-None-Match": "*"},
            "expiresAt": "2026-11-16T12:00:00Z"
        }
        ```
        ```bash
        Response code: 201 (created)
        ```

    `PUT` the raw bytes to `uploadUrl` with `Content-Type` and the returned
    `uploadHeaders`.

!!! info "POST /products/{id}/image"

    Validate the stored upload and attach it to the product. `ROLE_ADMIN`
    required. Replaces any existing image.

    === "Request"

        ``` { .json .copy .select linenums='1' }
        {
            "uploadId": "0195ac10-5c1f-7c2a-9f3d-9a5b0b0e7a11",
            "alt": "Fresh ripe tomatoes"
        }
        ```

    === "Response"

        ``` { .json .copy .select linenums='1' }
        {
            "id": "0195abfb-7074-73a9-9d26-b4b9fbaab0a8",
            "name": "Tomato",
            "price": 3.25,
            "unit": "kg",
            "image": {
                "url": "/media/media/products/0195abfb-7074-73a9-9d26-b4b9fbaab0a8/0195ac10-5c1f-7c2a-9f3d-9a5b0b0e7a13/original.jpg",
                "alt": "Fresh ripe tomatoes",
                "width": 1200,
                "height": 1000
            }
        }
        ```
        ```bash
        Response code: 200 (ok)
        ```

!!! info "PATCH /products/{id}/image"

    Change only the alt text. `ROLE_ADMIN` required. Returns the full product.

    === "Request"

        ``` { .json .copy .select linenums='1' }
        {
            "alt": "Ripe tomatoes on the vine"
        }
        ```

    ```bash
    Response code: 200 (ok)
    ```

!!! info "DELETE /products/{id}/image"

    Delete the stored image. `ROLE_ADMIN` required. Returns the full product with
    the image field set to `null`.

    ```bash
    Response code: 200 (ok)
    ```

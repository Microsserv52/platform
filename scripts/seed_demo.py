"""One-shot local demo bootstrap for the platform stack.

Logs in through the joined nginx endpoint with the Compose admin bootstrap,
then creates demo products, a demo customer and that customer's orders through
the real APIs. Opt-in via `docker compose --profile demo up demo-seeder`.

Idempotent: products are matched by name, the customer by email and orders by
content, so re-running after a partial failure only creates what is missing.
Refuses to run when ENV, APP_ENV or SPRING_PROFILES_ACTIVE marks production.
"""

import json
import os
import struct
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("DEMO_BASE_URL", "http://localhost:8080/api")
MANIFEST_PATH = os.environ.get(
    "DEMO_MANIFEST",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "demo-data.json"),
)
IMAGES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "images")
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@microsserv52.com")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "1berto52")
READINESS_TIMEOUT = float(os.environ.get("DEMO_READINESS_TIMEOUT_SECONDS", "120"))
PRODUCTION_MARKERS = {"prod", "production"}


def fail(message):
    print(f"demo seeder: {message}", file=sys.stderr)
    sys.exit(1)


def refuse_if_production():
    for name in ("ENV", "APP_ENV"):
        if os.environ.get(name, "").strip().lower() in PRODUCTION_MARKERS:
            fail(f"refusing to seed demo data: {name} marks a production environment")
    for token in os.environ.get("SPRING_PROFILES_ACTIVE", "").split(","):
        if token.strip().lower() in PRODUCTION_MARKERS:
            fail(
                "refusing to seed demo data: SPRING_PROFILES_ACTIVE marks a production environment"
            )


RETRY_STATUSES = {502, 503, 504}
RETRY_DELAY_SECONDS = 2


def call(method, path, token=None, body=None, retries=0):
    attempt = 0
    while True:
        try:
            status, payload = call_once(method, path, token, body)
        except urllib.error.URLError as error:
            if attempt >= retries:
                fail(f"{method} {path} is unreachable: {error.reason}")
            attempt += 1
            print(f"  {method} {path} is unreachable; retrying ({attempt}/{retries})")
            time.sleep(RETRY_DELAY_SECONDS)
            continue
        if status in RETRY_STATUSES and attempt < retries:
            attempt += 1
            print(
                f"  {method} {path} returned {status}; retrying ({attempt}/{retries})"
            )
            time.sleep(RETRY_DELAY_SECONDS)
            continue
        return status, payload


def call_once(method, path, token, body):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(BASE_URL + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = response.read()
            return response.status, json.loads(payload) if payload else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:200]
        return error.code, {"error": detail}


def wait_for_gateway():
    deadline = time.monotonic() + READINESS_TIMEOUT
    while time.monotonic() < deadline:
        status, _ = call("GET", "/products")
        if status == 200:
            return
        time.sleep(2)
    fail(
        f"gateway not ready at {BASE_URL} within {READINESS_TIMEOUT:.0f}s; start the main stack first"
    )


def login(email, password):
    status, body = call(
        "POST", "/auth/login", body={"email": email, "password": password}, retries=3
    )
    if status != 200:
        fail(
            f"login failed for {email}; is the Account admin bootstrap enabled (ADMIN_EMAIL/ADMIN_PASSWORD)?"
        )
    return body["accessToken"]


def image_dimensions(path):
    with open(path, "rb") as handle:
        header = handle.read(64)
        if header[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", header[16:24])
        if header[:2] == b"\xff\xd8":
            handle.seek(2)
            while True:
                marker = handle.read(2)
                if len(marker) != 2 or marker[0] != 0xFF:
                    raise ValueError("invalid JPEG stream")
                code = marker[1]
                if code in (0xD8, 0x01) or 0xD0 <= code <= 0xD7:
                    continue
                length = struct.unpack(">H", handle.read(2))[0]
                if code in (
                    0xC0,
                    0xC1,
                    0xC2,
                    0xC3,
                    0xC5,
                    0xC6,
                    0xC7,
                    0xC9,
                    0xCA,
                    0xCB,
                    0xCD,
                    0xCE,
                    0xCF,
                ):
                    fields = handle.read(5)
                    height, width = struct.unpack(">xHH", fields)
                    return width, height
                handle.seek(length - 2, 1)
    raise ValueError("unsupported image format")


def ensure_product_image(admin_token, product, image):
    status, body = call(
        "GET", "/products/" + product["id"], token=admin_token, retries=3
    )
    if status != 200:
        fail(f"product read failed for {product['name']}: {status} {body}")
    if body.get("image"):
        print(f"  image exists, skipping: {product['name']}")
        return
    path = os.path.join(IMAGES_DIR, image["file"])
    if not os.path.isfile(path):
        fail(f"image file not found for {product['name']}: {path}")
    with open(path, "rb") as handle:
        content = handle.read()
    width, height = image_dimensions(path)
    content_type = "image/png" if path.lower().endswith(".png") else "image/jpeg"
    status, ticket = call(
        "POST",
        "/products/" + product["id"] + "/image/uploads",
        token=admin_token,
        retries=3,
        body={
            "fileName": os.path.basename(image["file"]),
            "contentType": content_type,
            "size": len(content),
            "width": width,
            "height": height,
        },
    )
    if status != 201:
        fail(f"image upload ticket returned {status} for {product['name']}: {ticket}")
    request = urllib.request.Request(ticket["uploadUrl"], data=content, method="PUT")
    request.add_header("Content-Type", content_type)
    for header, value in ticket["uploadHeaders"].items():
        request.add_header(header, value)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if response.status not in (200, 201):
                fail(f"image upload returned {response.status} for {product['name']}")
    except urllib.error.HTTPError as error:
        fail(
            f"image upload failed for {product['name']}: {error.code} "
            + error.read().decode("utf-8", "replace")[:200]
        )
    status, body = call(
        "POST",
        "/products/" + product["id"] + "/image",
        token=admin_token,
        retries=1,
        body={"uploadId": ticket["uploadId"], "alt": image["alt"]},
    )
    if status != 200:
        fail(f"image attach returned {status} for {product['name']}: {body}")
    print(f"  image attached: {product['name']}")


def ensure_products(admin_token, manifest_products):
    products = {
        product["name"]: product for product in call("GET", "/products", retries=3)[1]
    }
    for product in manifest_products:
        name = product["name"]
        if name in products:
            print(f"  product exists, skipping: {name}")
            record = products[name]
        else:
            status, record = call(
                "POST",
                "/products",
                token=admin_token,
                retries=1,
                body={"name": name, "price": product["price"], "unit": product["unit"]},
            )
            if status != 201:
                fail(f"product creation returned {status} for {name}: {record}")
            print(f"  product created: {name}")
        if product.get("image"):
            ensure_product_image(admin_token, record, product["image"])
    return {name: product["id"] for name, product in products.items()}


def ensure_customer(admin_token, customer):
    status, accounts = call("GET", "/accounts", token=admin_token, retries=3)
    if status != 200:
        fail("GET /accounts failed; the admin token may lack ROLE_ADMIN")
    for account in accounts:
        if account["email"].lower() == customer["email"].lower():
            print(f"  customer exists, skipping: {customer['email']}")
            return account
    status, body = call(
        "POST",
        "/accounts",
        retries=1,
        body={
            "name": customer["name"],
            "email": customer["email"],
            "password": customer["password"],
        },
    )
    if status != 201:
        fail(f"customer creation returned {status} for {customer['email']}: {body}")
    print(f"  customer created: {customer['email']}")
    return body


def place_orders(customer_token, products, manifest_orders):
    id_to_name = {product_id: name for name, product_id in products.items()}
    existing = {
        tuple(
            sorted(
                (id_to_name.get(item["idProduct"], item["idProduct"]), item["quantity"])
                for item in order["items"]
            )
        )
        for order in call("GET", "/orders", token=customer_token, retries=3)[1]
    }
    for order in manifest_orders:
        signature = tuple(
            sorted((item["product"], item["quantity"]) for item in order["items"])
        )
        if signature in existing:
            print(f"  order exists, skipping: {signature}")
            continue
        status, body = call(
            "POST",
            "/orders",
            token=customer_token,
            body={
                "items": [
                    {
                        "idProduct": products[item["product"]],
                        "quantity": item["quantity"],
                    }
                    for item in order["items"]
                ]
            },
        )
        if status != 201:
            fail(f"order creation returned {status} for {signature}: {body}")
        print(f"  order created: {signature}")


def main():
    refuse_if_production()
    with open(MANIFEST_PATH, encoding="utf-8") as manifest_file:
        manifest = json.load(manifest_file)
    print(f"demo seeder: target {BASE_URL}")
    wait_for_gateway()
    admin_token = login(ADMIN_EMAIL, ADMIN_PASSWORD)
    print("admin login ok; seeding demo data")
    products = ensure_products(admin_token, manifest["products"])
    customer = ensure_customer(admin_token, manifest["customer"])
    customer_token = login(customer["email"], manifest["customer"]["password"])
    place_orders(customer_token, products, manifest["orders"])
    print(
        "demo seeder: done; open http://localhost:8080/store/ and sign in as the demo customer"
    )


if __name__ == "__main__":
    main()

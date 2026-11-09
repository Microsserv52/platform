"""Local frontend QA only. --fixtures uses disposable, in-memory API fixtures."""

import argparse
import json
import mimetypes
from datetime import datetime, timezone
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4
from time import monotonic

ROOT = Path(__file__).resolve().parent.parent.parent
PRODUCTS = [
    {"id": f"00000000-0000-4000-8000-{i:012d}", "name": name, "price": price, "unit": unit}
    for i, (name, price, unit) in enumerate([
        ("Fixture Tomato", 3.25, "kg"), ("Fixture Coffee", 8.50, "bag"),
        ("Fixture Notebook", 4.00, "item"), ("Fixture Canvas bag", 12.00, "item"),
    ], 1)
]
ORDERS = []
UPLOADS = {}
MEDIA = {}


class Handler(BaseHTTPRequestHandler):
    def respond(self, code, body=None, cookie=None):
        self.send_response(code)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Microsserv52-Test-Fixtures", "true")
        if cookie:
            self.send_header("Set-Cookie", cookie)
        if body is not None:
            self.send_header("Content-Type", "application/json")
        self.end_headers()
        if body is not None:
            self.wfile.write(json.dumps(body).encode())

    def fixture(self):
        path = urlsplit(self.path).path.removeprefix("/api").rstrip("/")
        cookie = SimpleCookie(self.headers.get("Cookie", ""))
        role = cookie.get("ms52-fixture")
        role = role.value if role else None
        profile = {"id": "00000000-0000-4000-8000-000000000100", "name": "Fixture Visitor", "email": "visitor@example.test", "roles": "ROLE_USER", "enabled": True}
        if role == "admin":
            profile.update(name="Fixture Administrator", email="admin@example.test", roles="ROLE_ADMIN")
        body = {}
        if self.command in ("POST", "PUT", "PATCH"):
            length = int(self.headers.get("Content-Length", "0"))
            if length > 10000:
                return self.respond(413)
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except ValueError:
                return self.respond(400)
        if self.command == "GET" and path == "/session/csrf":
            return self.respond(200, {"token": "fixture-csrf", "headerName": "X-XSRF-TOKEN"})
        if self.command in ("POST", "PUT", "PATCH", "DELETE") and self.headers.get("X-XSRF-TOKEN") != "fixture-csrf":
            return self.respond(403)
        if self.command == "POST" and path == "/session/login":
            if body.get("password") != "fixture-only":
                return self.respond(401)
            role = "admin" if body.get("email") == "admin@example.test" else "user"
            return self.respond(204, cookie=f"ms52-fixture={role}; Path=/api; HttpOnly; SameSite=Lax")
        if self.command == "DELETE" and path == "/session":
            return self.respond(204, cookie="ms52-fixture=; Path=/api; Max-Age=0; HttpOnly; SameSite=Lax")
        if self.command == "POST" and path == "/accounts":
            return self.respond(201, {**profile, "name": body.get("name", "Fixture Visitor"), "email": body.get("email", "visitor@example.test")})
        if self.command == "GET" and path == "/products":
            return self.respond(200, PRODUCTS)
        if self.command == "GET" and path.endswith("/image/content"):
            from urllib.parse import parse_qs
            version = parse_qs(urlsplit(self.path).query).get("version", [""])[0]
            media = MEDIA.get(version)
            if not media or media["productId"] != path.split("/")[2]:
                return self.respond(404)
            self.send_response(200)
            self.send_header("Content-Type", media["contentType"])
            self.send_header("Content-Length", str(len(media["bytes"])))
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return self.wfile.write(media["bytes"])
        if self.command == "GET" and path.startswith("/products/"):
            product = next((p for p in PRODUCTS if p["id"] == path.split("/")[-1]), None)
            return self.respond(200 if product else 404, product)
        if not role:
            return self.respond(401)
        if self.command == "GET" and path == "/session":
            return self.respond(200, profile)
        if self.command == "GET" and path == "/orders":
            return self.respond(200, ORDERS)
        if self.command == "GET" and path.startswith("/orders/"):
            order = next((o for o in ORDERS if o["id"] == path.split("/")[-1]), None)
            return self.respond(200 if order else 404, order)
        if self.command == "POST" and path == "/orders":
            items = []
            for item in body.get("items", []):
                product = next((p for p in PRODUCTS if p["id"] == item.get("idProduct")), None)
                if not product or not isinstance(item.get("quantity"), int) or item["quantity"] <= 0:
                    return self.respond(400)
                items.append({"id": str(uuid4()), "productId": product["id"], "quantity": item["quantity"], "total": round(product["price"] * item["quantity"], 2)})
            if not items:
                return self.respond(400)
            order = {"id": str(uuid4()), "date": datetime.now(timezone.utc).isoformat(), "currency": "USD", "items": items, "total": round(sum(i["total"] for i in items), 2)}
            ORDERS.insert(0, order)
            return self.respond(201, order)
        if role != "admin":
            return self.respond(403)
        if path.startswith("/products/") and "/image" in path:
            product = next((p for p in PRODUCTS if p["id"] == path.split("/")[2]), None)
            if not product:
                return self.respond(404)
            if self.command == "POST" and path.endswith("/image/uploads"):
                if body.get("contentType") not in ("image/png", "image/jpeg") or not 0 < body.get("size", 0) <= 5 * 1024 * 1024:
                    return self.respond(400)
                if not all(isinstance(body.get(key), int) and 0 < body[key] <= 4096 for key in ("width", "height")):
                    return self.respond(400)
                if len(UPLOADS) >= 20:
                    return self.respond(429)
                upload_id = str(uuid4())
                UPLOADS[upload_id] = {**body, "productId": product["id"], "created": monotonic()}
                return self.respond(201, {"uploadId": upload_id, "uploadUrl": "http://" + self.headers["Host"] + "/api/fixture-media-upload/" + upload_id, "uploadHeaders": {"If-None-Match": "*"}})
            if self.command == "DELETE":
                product["image"] = None
                return self.respond(200, product)
            alternative = body.get("alt", "").strip()
            if not alternative or len(alternative) > 200:
                return self.respond(400)
            if self.command == "PATCH" and product.get("image"):
                product["image"]["alt"] = alternative
                return self.respond(200, product)
            ticket = UPLOADS.get(body.get("uploadId"))
            if self.command == "PUT" and ticket and ticket["productId"] == product["id"] and "bytes" in ticket and monotonic() - ticket["created"] < 600:
                version = body["uploadId"]
                MEDIA[version] = ticket
                product["image"] = {"url": "/api/products/" + product["id"] + "/image/content?version=" + version, "alt": alternative, "width": ticket["width"], "height": ticket["height"]}
                del UPLOADS[version]
                return self.respond(200, product)
            return self.respond(400)
        if self.command == "GET" and path == "/accounts":
            return self.respond(200, [profile])
        if self.command == "POST" and path == "/products":
            if not body.get("name") or not body.get("unit") or not isinstance(body.get("price"), (int, float)) or body["price"] <= 0:
                return self.respond(400)
            product = {"id": str(uuid4()), "name": body["name"], "unit": body["unit"], "price": body["price"]}
            PRODUCTS.append(product)
            return self.respond(201, product)
        if self.command == "DELETE" and path.startswith("/products/"):
            PRODUCTS[:] = [p for p in PRODUCTS if p["id"] != path.split("/")[-1]]
            return self.respond(204)
        return self.respond(404)

    def do_GET(self):
        path = urlsplit(self.path).path
        if self.server.fixtures and (self.server.api_only or path.startswith("/api/")):
            return self.fixture()
        if self.server.api_only:
            return self.respond(404)
        if path in ("/store", "/admin"):
            self.send_response(308)
            self.send_header("Location", path + "/")
            self.end_headers()
            return
        app, relative = "landing", path.lstrip("/")
        for zone in ("store", "admin"):
            if path.startswith("/" + zone + "/"):
                app, relative = zone, path[len(zone) + 2:]
                break
        root = ROOT / "web" / app / "out"
        file = (root / relative).resolve()
        if not file.is_relative_to(root.resolve()):
            return self.respond(404)
        if file.is_dir():
            file = file / "index.html"
        if not file.is_file():
            return self.respond(404)
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(file)[0] or "application/octet-stream")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(file.read_bytes())

    def do_POST(self):
        if self.server.fixtures:
            return self.fixture()
        self.respond(503)

    def do_DELETE(self):
        if self.server.fixtures:
            return self.fixture()
        self.respond(503)

    def do_PATCH(self):
        if self.server.fixtures:
            return self.fixture()
        self.respond(503)

    def do_PUT(self):
        path = urlsplit(self.path).path.removeprefix("/api")
        if self.server.fixtures and path.startswith("/fixture-media-upload/"):
            ticket = UPLOADS.get(path.split("/")[-1])
            length = int(self.headers.get("Content-Length", "0"))
            if not ticket or monotonic() - ticket["created"] >= 600:
                return self.respond(403)
            if self.headers.get("If-None-Match") != "*" or "bytes" in ticket:
                return self.respond(412)
            if length != ticket["size"] or not 0 < length <= 5 * 1024 * 1024:
                return self.respond(400)
            ticket["bytes"] = self.rfile.read(length)
            return self.respond(204)
        if self.server.fixtures:
            return self.fixture()
        self.respond(503)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=4173)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--fixtures", action="store_true")
    parser.add_argument("--api-only", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.fixtures, server.api_only = args.fixtures, args.api_only
    print(f"Frontend QA: http://{args.host}:{args.port} (disposable fixtures: {args.fixtures})", flush=True)
    server.serve_forever()

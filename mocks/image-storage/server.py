"""Local S3-compatible blob mock for Product images (platform root).

Used by the platform-root `compose.yml` service `image-storage`. It lets the
local stack exercise the same object flow the Product service uses against AWS
S3, without touching real infrastructure. Objects are files on disk under
IMAGE_STORAGE_DATA_DIR (mounted as a volume) so they survive restarts.
"""

import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

DATA_DIR = os.environ.get("IMAGE_STORAGE_DATA_DIR", "/data")
PORT = int(os.environ.get("IMAGE_STORAGE_PORT", "8090"))
MAX_OBJECT_BYTES = 5 * 1024 * 1024
PRODUCTION_ENV_VALUES = {"prod", "production"}


def refuse_to_run_in_production() -> None:
    for name in ("ENV", "APP_ENV"):
        value = os.environ.get(name, "").strip().lower()
        if value in PRODUCTION_ENV_VALUES:
            raise SystemExit(
                f"refusing to start: {name}={value!r} marks a production "
                "environment and this mock is local-only"
            )


def object_path(key: str) -> str | None:
    if not key or key.startswith("/") or "\\" in key:
        return None
    parts = key.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return None
    path = os.path.realpath(os.path.join(DATA_DIR, *parts))
    if path != os.path.realpath(DATA_DIR) and not path.startswith(
        os.path.realpath(DATA_DIR) + os.sep
    ):
        return None
    return path


def content_type_of(path: str) -> str:
    sidecar = path + ".ctype"
    if os.path.isfile(sidecar):
        with open(sidecar, encoding="utf-8") as handle:
            return handle.read().strip()
    guessed, _ = mimetypes.guess_type(path)
    return guessed or "application/octet-stream"


class ImageStorageHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = unquote(urlparse(self.path).path)
        if path == "/health":
            self.send_json(200, {"status": "ok"})
            return
        for prefix in ("/media", "/object"):
            key = self.strip_prefix(path, prefix)
            if key is not None:
                self.serve_object(key)
                return
        self.send_error(404, "Not found")

    def do_PUT(self) -> None:
        path = unquote(urlparse(self.path).path)
        for prefix in ("/upload", "/object"):
            key = self.strip_prefix(path, prefix)
            if key is not None:
                self.store_object(key)
                return
        self.send_error(404, "Not found")

    def do_DELETE(self) -> None:
        path = unquote(urlparse(self.path).path)
        key = self.strip_prefix(path, "/object")
        if key is None:
            self.send_error(404, "Not found")
            return
        object_path_value = object_path(key)
        if object_path_value is not None and os.path.isfile(object_path_value):
            os.remove(object_path_value)
        if object_path_value is not None and os.path.isfile(
            object_path_value + ".ctype"
        ):
            os.remove(object_path_value + ".ctype")
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def strip_prefix(self, path: str, prefix: str) -> str | None:
        if not path.startswith(prefix + "/"):
            return None
        key = path[len(prefix) + 1 :]
        return key if key else None

    def serve_object(self, key: str) -> None:
        path = object_path(key)
        if path is None or not os.path.isfile(path):
            self.send_error(404, "Object not found")
            return
        with open(path, "rb") as handle:
            body = handle.read()
        self.send_response(200)
        self.send_header("Content-Type", content_type_of(path))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        self.end_headers()
        self.wfile.write(body)

    def store_object(self, key: str) -> None:
        path = object_path(key)
        if path is None:
            self.send_json(
                400, {"code": "INVALID_KEY", "message": "Invalid object key"}
            )
            return
        if self.headers.get("If-None-Match") == "*" and os.path.isfile(path):
            self.send_json(
                412, {"code": "PRECONDITION_FAILED", "message": "Object already exists"}
            )
            return
        try:
            length = int(self.headers.get("Content-Length") or "0")
        except ValueError:
            self.send_error(400, "Invalid Content-Length")
            return
        if length > MAX_OBJECT_BYTES:
            self.send_json(
                413, {"code": "OBJECT_TOO_LARGE", "message": "Object exceeds 5 MiB"}
            )
            return
        body = self.rfile.read(length) if length else b""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(body)
        content_type = self.headers.get("Content-Type")
        if content_type:
            with open(path + ".ctype", "w", encoding="utf-8") as handle:
                handle.write(content_type)
        self.send_response(201)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    refuse_to_run_in_production()
    os.makedirs(DATA_DIR, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), ImageStorageHandler).serve_forever()

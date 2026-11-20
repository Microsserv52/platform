"""Deterministic local identity mock for the Product standalone stack.

This service exists only for local development and CI. It signs short-lived
HS256 tokens with the same ``JWT_SECRET`` the Product service validates.
Never deploy it to production or reuse its defaults outside local Compose.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ.get("JWT_SECRET", "").encode()
DEFAULT_TTL_SECONDS = 3600
PRODUCTION_ENV_VALUES = {"prod", "production"}


def refuse_to_run_in_production() -> None:
    for name in ("ENV", "APP_ENV"):
        value = os.environ.get(name, "").strip().lower()
        if value in PRODUCTION_ENV_VALUES:
            raise SystemExit(
                f"refusing to start: {name}={value!r} marks a production "
                "environment and this mock is local-only"
            )


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _sign(payload: dict) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = (
        f"{_b64url(json.dumps(header, separators=(',', ':')).encode())}."
        f"{_b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    )
    signature = hmac.new(SECRET, signing_input.encode(), hashlib.sha256).digest()
    return f"{signing_input}.{_b64url(signature)}"


class IdentityHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "UP"})
            return
        self._send_json(404, {"code": "NOT_FOUND", "message": "Not found"})

    def do_POST(self) -> None:
        if self.path != "/token":
            self._send_json(404, {"code": "NOT_FOUND", "message": "Not found"})
            return
        if not SECRET:
            self._send_json(500, {"code": "MISCONFIGURED", "message": "JWT_SECRET is not set"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self._send_json(400, {"code": "INVALID_REQUEST", "message": "Invalid JSON body"})
            return

        subject = str(body.get("sub") or uuid.uuid4())
        roles = body.get("roles", ["ROLE_ADMIN"])
        if not isinstance(roles, list) or not all(isinstance(role, str) for role in roles):
            self._send_json(400, {"code": "INVALID_REQUEST", "message": "roles must be a list of strings"})
            return

        ttl = int(body.get("ttl_seconds", DEFAULT_TTL_SECONDS))
        ttl = max(60, min(ttl, 86400))
        now = int(time.time())
        token = _sign(
            {
                "sub": subject,
                "roles": roles,
                "iss": "local-identity-mock",
                "iat": now,
                "exp": now + ttl,
            }
        )
        self._send_json(
            200,
            {"access_token": token, "token_type": "Bearer", "expires_in": ttl},
        )

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    refuse_to_run_in_production()
    ThreadingHTTPServer(("0.0.0.0", 8080), IdentityHandler).serve_forever()

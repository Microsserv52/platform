"""Deterministic exchange-rate provider mock for local development and CI.

Never deploy this service. It exists so the Exchange adapter can be exercised
with success, timeout, failure and malformed-payload behavior without a real
provider key.
"""

from __future__ import annotations

import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

RATES = {
    "USD": 1.0,
    "EUR": 0.8176,
    "BRL": 5.10,
    "GBP": 0.79,
    "JPY": 150.0,
}
MODES = {"ok", "error", "timeout", "malformed", "rate_limit", "unsupported"}
MODE = os.environ.get("MOCK_MODE", "ok")
REQUIRED_KEY = os.environ.get("MOCK_API_KEY")
OBSERVED_AT = "2026-01-01T00:00:00Z"
PRODUCTION_ENV_VALUES = {"prod", "production"}


def refuse_to_run_in_production() -> None:
    for name in ("ENV", "APP_ENV"):
        value = os.environ.get(name, "").strip().lower()
        if value in PRODUCTION_ENV_VALUES:
            raise SystemExit(
                f"refusing to start: {name}={value!r} marks a production "
                "environment and this mock is local-only"
            )


class ProviderHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        request = urlparse(self.path)
        if request.path == "/health":
            self._json(200, {"status": "ok"})
            return
        if request.path == "/control":
            self._control(parse_qs(request.query))
            return
        if request.path not in ("/latest", "/v1/latest", "/latest.json"):
            self._json(404, {"code": "NOT_FOUND", "message": "Not found"})
            return
        if REQUIRED_KEY and self.headers.get("Authorization") != f"Bearer {REQUIRED_KEY}":
            self._json(401, {"code": "UNAUTHORIZED", "message": "Invalid provider key"})
            return
        if MODE == "error":
            self._json(503, {"code": "UNAVAILABLE", "message": "Provider unavailable"})
            return
        if MODE == "timeout":
            time.sleep(5)
        if MODE == "malformed":
            self._text(200, "not-json")
            return
        if MODE == "rate_limit":
            self._json(429, {"code": "RATE_LIMITED"}, headers={"Retry-After": "2"})
            return
        if MODE == "unsupported":
            self._json(400, {"code": "UNSUPPORTED", "message": "Unsupported currency"})
            return

        query = parse_qs(request.query)
        base = query.get("base", ["USD"])[0].upper()
        symbols = query.get("symbols", [None])[0]
        requested = [item.upper() for item in symbols.split(",")] if symbols else ["EUR"]
        if base not in RATES:
            self._json(400, {"code": "UNSUPPORTED", "message": "Unsupported base currency"})
            return
        if any(currency not in RATES for currency in requested):
            self._json(400, {"code": "UNSUPPORTED", "message": "Unsupported quote currency"})
            return

        rates = {}
        for currency in requested:
            mid = RATES[currency] / RATES[base]
            rates[currency] = {
                "bid": round(mid * 0.9975, 6),
                "ask": round(mid * 1.0025, 6),
            }
        self._json(200, {"base": base, "date": OBSERVED_AT, "rates": rates})

    def do_POST(self) -> None:
        request = urlparse(self.path)
        if request.path != "/control":
            self._json(404, {"code": "NOT_FOUND", "message": "Not found"})
            return
        self._control(parse_qs(request.query))

    def _control(self, query: dict[str, list[str]]) -> None:
        global MODE
        requested = query.get("mode", [None])[0]
        if requested is None:
            self._json(200, {"mode": MODE})
            return
        if requested not in MODES:
            self._json(400, {"code": "INVALID_MODE", "message": "Unknown mock mode"})
            return
        MODE = requested
        self._json(200, {"mode": MODE})

    def _json(
        self,
        status: int,
        payload: dict,
        headers: dict[str, str] | None = None,
    ) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def _text(self, status: int, body: str) -> None:
        encoded = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    refuse_to_run_in_production()
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), ProviderHandler).serve_forever()

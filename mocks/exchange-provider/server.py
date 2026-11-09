import json
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

RATES = {
    "EUR": 0.92,
    "BRL": 5.10,
    "GBP": 0.79,
    "JPY": 150.0,
}


class ExchangeProviderHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        request = urlparse(self.path)
        if request.path == "/health":
            self.send_json({"status": "ok"})
            return

        if request.path not in ("/latest", "/v1/latest", "/latest.json"):
            self.send_error(404, "Not found")
            return

        query = parse_qs(request.query)
        base = query.get("base", ["USD"])[0].upper()
        symbols = query.get("symbols", [None])[0]
        requested = [item.upper() for item in symbols.split(",")] if symbols else None
        rates = {currency: rate for currency, rate in RATES.items()}
        rates["USD"] = 1.0
        if requested:
            rates = {currency: rates[currency] for currency in requested if currency in rates}

        self.send_json({"base": base, "date": date.today().isoformat(), "rates": rates})

    def send_json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), ExchangeProviderHandler).serve_forever()

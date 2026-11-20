import importlib.util
import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen

source = Path(__file__).resolve().parents[2] / "mocks/exchange-provider/server.py"
spec = importlib.util.spec_from_file_location("exchange_provider", source)
provider = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provider)


def mid_rate(currency, base):
    return provider.RATES[currency] / provider.RATES[base]


class ExchangeProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), provider.ProviderHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self):
        provider.MODE = "ok"

    def get_json(self, path):
        with urlopen(self.base_url + path, timeout=5) as response:
            return json.load(response)

    def test_rebases_rates_and_filters_symbols(self):
        result = self.get_json("/latest?base=EUR&symbols=USD,BRL,EUR")
        self.assertEqual(result["base"], "EUR")
        self.assertEqual(set(result["rates"]), {"USD", "BRL", "EUR"})
        for currency in ("USD", "BRL", "EUR"):
            with self.subTest(currency=currency):
                mid = mid_rate(currency, "EUR")
                quote = result["rates"][currency]
                self.assertAlmostEqual(quote["bid"], round(mid * 0.9975, 6), places=6)
                self.assertAlmostEqual(quote["ask"], round(mid * 1.0025, 6), places=6)

    def test_rejects_unsupported_currencies(self):
        for path in ("/latest?base=XXX", "/latest?symbols=USD,XXX"):
            with self.subTest(path=path), self.assertRaises(HTTPError) as raised:
                self.get_json(path)
            self.assertEqual(raised.exception.code, 400)

    def test_health_and_default_quote(self):
        self.assertEqual(self.get_json("/health"), {"status": "ok"})
        result = self.get_json("/v1/latest")
        self.assertEqual(result["base"], "USD")
        self.assertEqual(set(result["rates"]), {"EUR"})

    def test_control_switches_modes(self):
        self.assertEqual(self.get_json("/control?mode=error"), {"mode": "error"})
        with self.assertRaises(HTTPError) as raised:
            self.get_json("/latest?base=USD&symbols=EUR")
        self.assertEqual(raised.exception.code, 503)
        self.assertEqual(self.get_json("/control?mode=ok"), {"mode": "ok"})


if __name__ == "__main__":
    unittest.main()

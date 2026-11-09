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


class ExchangeProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(
            ("127.0.0.1", 0), provider.ExchangeProviderHandler
        )
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def get_json(self, path):
        with urlopen(self.base_url + path, timeout=5) as response:
            return json.load(response)

    def test_rebases_rates_and_filters_symbols(self):
        result = self.get_json("/latest?base=EUR&symbols=USD,BRL,EUR")
        self.assertEqual(result["base"], "EUR")
        self.assertEqual(set(result["rates"]), {"USD", "BRL", "EUR"})
        self.assertAlmostEqual(result["rates"]["USD"], 1 / 0.92)
        self.assertAlmostEqual(result["rates"]["BRL"], 5.10 / 0.92)
        self.assertEqual(result["rates"]["EUR"], 1)

    def test_rejects_unsupported_currencies(self):
        for path in ("/latest?base=XXX", "/latest?symbols=USD,XXX"):
            with self.subTest(path=path), self.assertRaises(HTTPError) as raised:
                self.get_json(path)
            self.assertEqual(raised.exception.code, 400)

    def test_health_and_default_usd(self):
        self.assertEqual(self.get_json("/health"), {"status": "ok"})
        self.assertEqual(self.get_json("/v1/latest")["rates"]["USD"], 1)


if __name__ == "__main__":
    unittest.main()

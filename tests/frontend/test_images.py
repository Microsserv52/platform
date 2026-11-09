"""HTTP contract checks for disposable image fixtures, not AWS acceptance."""
import base64
import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from serve import Handler, MEDIA, UPLOADS, PRODUCTS


class ImageFixtures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.server.fixtures, cls.server.api_only = True, True
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = "http://127.0.0.1:" + str(cls.server.server_port)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self):
        UPLOADS.clear()
        MEDIA.clear()
        for product in PRODUCTS:
            product.pop("image", None)
        self.path = "/api/products/" + PRODUCTS[0]["id"] + "/image"
        self.png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1kAAAAASUVORK5CYII=")

    def request(self, path, method="GET", body=None, role="admin", csrf=True, headers=None):
        values = dict(headers or {})
        if role:
            values["Cookie"] = "ms52-fixture=" + role
        if csrf:
            values["X-XSRF-TOKEN"] = "fixture-csrf"
        if isinstance(body, dict):
            body = json.dumps(body).encode()
            values["Content-Type"] = "application/json"
        request = Request(path if path.startswith("http") else self.base + path, data=body, method=method, headers=values)
        try:
            response = urlopen(request, timeout=5)
        except HTTPError as error:
            response = error
        with response:
            data = response.read()
            parsed = json.loads(data) if data and response.headers.get_content_type() == "application/json" else data
            return response.status, parsed

    def ticket(self, **changes):
        body = {"fileName": "fixture.png", "contentType": "image/png", "size": len(self.png), "width": 1, "height": 1, **changes}
        return self.request(self.path + "/uploads", "POST", body)

    def test_upload_replace_alt_edit_and_remove(self):
        urls = []
        for alt in ("Initial fixture", "Replacement fixture"):
            status, ticket = self.ticket()
            self.assertEqual(status, 201)
            self.assertEqual(self.request(ticket["uploadUrl"], "PUT", self.png, role=None, headers=ticket["uploadHeaders"])[0], 204)
            self.assertEqual(self.request(ticket["uploadUrl"], "PUT", self.png, role=None, headers=ticket["uploadHeaders"])[0], 412)
            status, product = self.request(self.path, "PUT", {"uploadId": ticket["uploadId"], "alt": alt})
            self.assertEqual(status, 200)
            urls.append(product["image"]["url"])
            self.assertEqual(self.request(urls[-1], role=None)[1], self.png)
            self.assertEqual(self.request(self.path, "PUT", {"uploadId": ticket["uploadId"], "alt": alt})[0], 400)
        self.assertNotEqual(*urls)
        self.assertEqual(self.request(self.path, "PATCH", {"alt": "Edited fixture"})[1]["image"]["alt"], "Edited fixture")
        self.assertIsNone(self.request(self.path, "DELETE")[1]["image"])
        self.assertNotIn("image", {key: value for key, value in PRODUCTS[1].items()})

    def test_access_and_csrf_rejections(self):
        body = {"fileName": "fixture.png"}
        for role, expected in (("user", 403), (None, 401)):
            self.assertEqual(self.request(self.path + "/uploads", "POST", body, role=role)[0], expected)
        self.assertEqual(self.request(self.path + "/uploads", "POST", body, csrf=False)[0], 403)
        for method in ("PUT", "PATCH", "DELETE"):
            self.assertEqual(self.request(self.path, method, {}, csrf=False)[0], 403)

    def test_invalid_size_type_and_expired_ticket(self):
        for changes in ({"size": 0}, {"size": 6 * 1024 * 1024}, {"contentType": "image/svg+xml"}, {"width": 0}):
            self.assertEqual(self.ticket(**changes)[0], 400)
        status, ticket = self.ticket()
        self.assertEqual(status, 201)
        self.assertEqual(self.request(ticket["uploadUrl"], "PUT", b"wrong length", role=None, headers=ticket["uploadHeaders"])[0], 400)
        UPLOADS[ticket["uploadId"]]["created"] -= 601
        self.assertEqual(self.request(ticket["uploadUrl"], "PUT", self.png, role=None, headers=ticket["uploadHeaders"])[0], 403)


if __name__ == "__main__":
    unittest.main()

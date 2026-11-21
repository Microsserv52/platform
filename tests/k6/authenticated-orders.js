import http from "k6/http";
import { check, sleep } from "k6";

// Authenticated order flow. This writes demo orders, so run it only against a
// disposable or local environment with an explicit owner decision.
const baseUrl = (__ENV.BASE_URL || "http://localhost:8080").replace(/\/$/, "");
const email = __ENV.DEMO_EMAIL || "demo@microsserv52.com";
const password = __ENV.DEMO_PASSWORD || "demo-customer-password";

http.setResponseCallback(http.expectedStatuses(200, 201));

export const options = {
  scenarios: {
    orders: {
      executor: "constant-arrival-rate",
      rate: Number(__ENV.RATE || 5),
      timeUnit: "1s",
      duration: __ENV.DURATION || "1m",
      preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 10),
      maxVUs: Number(__ENV.MAX_VUS || 50),
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1500", "p(99)<3000"],
    checks: ["rate>0.95"],
  },
};

export function setup() {
  const login = http.post(
    `${baseUrl}/api/auth/login`,
    JSON.stringify({ email, password }),
    { headers: { "Content-Type": "application/json" } },
  );
  check(login, { "login succeeds": (res) => res.status === 200 });
  const token = login.json("accessToken");

  const products = http.get(`${baseUrl}/api/products`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  check(products, { "catalog is available": (res) => res.status === 200 });
  const catalog = products.json();
  if (!Array.isArray(catalog) || catalog.length === 0) {
    throw new Error("no products available for the authenticated order test");
  }

  const product = catalog[0];
  return { token, productId: product.id, productName: product.name };
}

export default function (data) {
  const response = http.post(
    `${baseUrl}/api/orders`,
    JSON.stringify({ items: [{ idProduct: data.productId, quantity: 1 }] }),
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${data.token}`,
      },
      tags: { flow: "create-order", product: data.productName },
    },
  );
  check(response, {
    "order is created": (res) => res.status === 201,
  });
  sleep(0.1);
}

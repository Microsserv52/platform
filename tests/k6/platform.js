import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = (__ENV.BASE_URL || "http://localhost:8080").replace(/\/$/, "");
const protectedPaths = (__ENV.PROTECTED_PATHS || "/products,/exchange/USD/EUR")
  .split(",")
  .map((path) => path.trim())
  .filter(Boolean);

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 499 }));

export const options = {
  scenarios: {
    steady: {
      executor: "constant-arrival-rate",
      rate: Number(__ENV.RATE || 10),
      timeUnit: "1s",
      duration: __ENV.DURATION || "2m",
      preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 10),
      maxVUs: Number(__ENV.MAX_VUS || 50),
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<1000", "p(99)<2000"],
    checks: ["rate>0.95"],
  },
};

export default function () {
  for (const path of protectedPaths) {
    const response = http.get(`${baseUrl}${path}`);
    check(response, {
      "request returns an expected API response": (res) =>
        [200, 401, 403, 404].includes(res.status),
    });
  }
  sleep(0.1);
}

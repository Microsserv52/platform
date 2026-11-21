---
icon: lucide/timer-reset
---

# Load testing

Load tests validate capacity and expose bottlenecks. They must be reproducible
and must not target production without explicit authorization.

## Scenarios

Start with representative flows:

1. Unauthenticated health check.
2. Login and token validation.
3. Browse products.
4. Create an order with valid products.
5. Retrieve an order in USD.
6. Retrieve an order converted through Exchange.

Define arrival rate or concurrent users, duration, warm-up, dataset and
acceptable thresholds before running the test.

For this platform, record the expected peak and a headroom target before the
test. A component may remain the measured bottleneck and still pass if it
supports the required peak with the agreed latency and error-rate margin. The
goal is not to remove every bottleneck; it is to keep every known bottleneck
below the system requirement or make its failure mode safe and observable.

## Measurements

Record throughput, p50/p95/p99 latency, HTTP status distribution, timeouts,
dependency latency, CPU, memory, replicas, database connections and provider
errors. Also record ingress/controller saturation, CPU throttling, HPA
activity, pod evictions, and the remaining headroom at the narrowest
component. Include the exact commit, image tags, cluster size and region.

## Read-only k6 catalog baseline

The repository includes [`tests/k6/platform.js`](../../tests/k6/platform.js).
It exercises the public catalog at `/api/products` through the Compose edge.
Only HTTP 200 counts as success: authentication errors, missing routes and server
errors fail the checks. Use `PATHS=/products` when calling Gateway directly.
This read-only baseline does not verify order creation or authenticated capacity.
`RATE` counts iterations per second; each iteration sends one request per path.

Install k6 using the official instructions for your operating system, then run
the local Compose baseline:

```bash
docker compose up --build -d
k6 run \
  --env BASE_URL=http://localhost:8080 \
  --env RATE=10 \
  --env DURATION=2m \
  tests/k6/platform.js
docker compose down
```

For an authenticated scenario, extend the script with the API login/session
flow and CSRF handling for writes; do not commit credentials, cookies or tokens.
The default script is intentionally read-only and does not create test data.

## Kubernetes HPA exercise

The manifests in `k8s/base/hpa.yaml` configure HPA for Gateway, Order, Account,
Auth, Product and Exchange with two minimum replicas, six maximum replicas and a
70% CPU target. `k8s/base/pdb.yaml` preserves one available replica during
voluntary disruption. MicroK8s supports these manifests, but HPA requires the
cluster to be running and Metrics Server to be enabled:

```bash
microk8s start
microk8s status --wait-ready
microk8s enable dns metrics-server ingress
microk8s kubectl get nodes
microk8s kubectl top pods -n platform
```

Load the application images into MicroK8s or configure registry references
first. Then deploy the local test environment and HPA:

```bash
microk8s kubectl apply -k k8s/overlays/microk8s
microk8s kubectl get hpa -n platform --watch
```

In a controlled non-production namespace, generate load from the host and
observe scaling:

```bash
k6 run \
  --env BASE_URL=http://<microk8s-ingress-address> \
  --env PATHS=/products \
  --env RATE=50 \
  --env DURATION=10m \
  tests/k6/platform.js
microk8s kubectl get deployment gateway -n platform -w
microk8s kubectl get hpa gateway -n platform
```

Record initial and peak replica counts, HPA current/desired CPU, node count,
scale-up latency, p95/p99 latency, error rate, pod evictions and node capacity.
The test passes only when the defined peak request rate and latency/error SLOs
are met with headroom; scaling alone is not evidence of sufficient capacity.

Set `RATE` from the [capacity envelope](../infrastructure/costs.md#traffic-scaling-and-capacity).
The HPA starts at ≈ 2.1 cores of aggregate application CPU, which is about
210 req/s if a request costs 10 ms of CPU. Below ~200 req/s the HPA stays at its
two-replica minimum and the test measures only the baseline. The two-node
baseline is already at that HPA minimum; the third replica stays `Pending`
until Cluster Autoscaler adds a node. Replace the 10 ms planning value with the
CPU time measured by `kubectl top pods` during the run.

If the ingress addon is not exposing a host address, use port forwarding for a
controlled test:

```bash
microk8s kubectl -n platform port-forward service/gateway 18080:8080
k6 run --env BASE_URL=http://127.0.0.1:18080 --env PATHS=/products tests/k6/platform.js
```

## Kubernetes exercise

The course material demonstrates an HPA for Gateway and a temporary in-cluster
load generator. Do not create a second HPA when `k8s/base/hpa.yaml` is installed. The following is
suitable only for a separate controlled namespace without the managed HPA:

```bash
kubectl autoscale deployment gateway --cpu-percent=50 --min=1 --max=10
kubectl get hpa gateway
kubectl -n kube-system get deploy metrics-server cluster-autoscaler
kubectl get nodes
kubectl get pods -l app=gateway --watch
```

Use k6 for formal results. A loop with `wget` is useful as a smoke experiment
but is not sufficient evidence for capacity or SLA claims. Delete temporary
HPAs and load-generator pods after testing; keep the managed HPA manifests when
they are part of the production deployment.

## Execution plan and status

| Scenario | Workload | Primary evidence | Status |
| --- | --- | --- | --- |
| Catalogue baseline | 50–100 req/s, 10 min | p50/p95/p99, errors, pods, nodes | Not run |
| HPA trigger | 200–250 req/s, 15 min | HPA desired/current replicas, CPU, pending pods | Not run |
| Node autoscaling | Hold above HPA minimum | node count 2 → 3, pod scheduling time | Not run |
| Order write | 20–50 concurrent users | order p95, DB pool wait, errors | Not run |
| Provider failure | Exchange timeout/error injection | Exchange error rate, fallback behavior | Not run |
| Scale-down | Stop load, observe | HPA stabilization, node scale-down time | Not run |

For each run record the Git SHA, image tags, cluster/node count, `RATE`,
`DURATION`, k6 summary JSON, `kubectl top pods`, HPA and node timelines. Store
the artifacts under the run record or a linked issue; do not commit credentials
or raw personal data.

The capacity envelope in [Costs, PaaS and SLA](../infrastructure/costs.md#traffic-scaling-and-capacity)
is a planning input, not a result. Until these rows are run, the project must
not claim a supported request rate or user count.

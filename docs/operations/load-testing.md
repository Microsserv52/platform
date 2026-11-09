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

## k6 baseline

The repository includes [`tests/k6/platform.js`](../../tests/k6/platform.js).
It exercises the Gateway through the configured public URL and accepts the
expected unauthenticated responses while measuring latency and errors.

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

For an authenticated scenario, extend the script with the login flow and pass
the resulting token in `Authorization`; do not commit credentials or tokens.
The default script is intentionally read-only and does not create test data.

## Kubernetes HPA exercise

The manifests in `k8s/70-hpa.yaml` configure HPA for Gateway, Order, Account and
Auth with three minimum replicas, ten maximum replicas and a 60% CPU target.
The manifests in `k8s/71-pdb.yaml` preserve two available replicas during
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
microk8s kubectl apply -f k8s/00-namespace-config.yaml
microk8s kubectl apply -f k8s/05-redis.yaml
microk8s kubectl apply -f k8s/10-database.yaml
microk8s kubectl apply -f k8s/20-account.yaml
microk8s kubectl apply -f k8s/30-auth.yaml
microk8s kubectl apply -f k8s/40-order.yaml
microk8s kubectl apply -f k8s/50-gateway.yaml
microk8s kubectl apply -f k8s/60-ingress.yaml
microk8s kubectl apply -f k8s/70-hpa.yaml
microk8s kubectl apply -f k8s/71-pdb.yaml
microk8s kubectl get hpa -n platform --watch
```

In a controlled non-production namespace, generate load from the host and
observe scaling:

```bash
k6 run \
  --env BASE_URL=http://<microk8s-ingress-address> \
  --env RATE=50 \
  --env DURATION=10m \
  tests/k6/platform.js
microk8s kubectl get deployment gateway -n platform -w
microk8s kubectl get hpa gateway -n platform
```

Record initial and peak replica counts, HPA current/desired CPU, scale-up
latency, p95/p99 latency, error rate, pod evictions and node capacity. The
test passes only when the defined peak request rate and latency/error SLOs are
met with headroom; scaling alone is not evidence of sufficient capacity.

If the ingress addon is not exposing a host address, use port forwarding for a
controlled test:

```bash
microk8s kubectl -n platform port-forward service/gateway 18080:8080
k6 run --env BASE_URL=http://127.0.0.1:18080 tests/k6/platform.js
```

## Kubernetes exercise

The course material demonstrates an HPA for Gateway and a temporary in-cluster
load generator. The following is suitable only for a controlled test
namespace:

```bash
kubectl autoscale deployment gateway --cpu-percent=50 --min=1 --max=10
kubectl get hpa gateway
kubectl get pods -l app=gateway --watch
```

Use k6 for formal results. A loop with `wget` is useful as a smoke experiment
but is not sufficient evidence for capacity or SLA claims. Delete temporary
HPAs and load-generator pods after testing; keep the managed HPA manifests when
they are part of the production deployment.

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

## Kubernetes exercise

The course material demonstrates an HPA for Gateway and a temporary in-cluster
load generator. The following is suitable only for a controlled test
namespace:

```bash
kubectl autoscale deployment gateway --cpu-percent=50 --min=1 --max=10
kubectl get hpa gateway
kubectl get pods -l app=gateway --watch
```

Use a maintained load-testing tool for formal results. A loop with `wget` is
useful as a smoke experiment but is not sufficient evidence for capacity or
SLA claims. Delete temporary HPAs and load-generator pods after testing.

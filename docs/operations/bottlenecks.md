---
icon: lucide/gauge
---

# Bottlenecks and performance

This study describes where the current platform can become constrained and
what has been done about each constraint. It is an architecture assessment,
not a measured capacity claim: no representative production load-test result
is recorded yet. A bottleneck is acceptable when its capacity is demonstrably
above the system's required peak, even if it remains the narrowest part of the
request path.

## Status definitions

| Status | Meaning |
| --- | --- |
| **Mitigated** | A control is present and the risk is bounded, but it still needs load-test evidence. |
| **Residual** | The risk is reduced, but the component remains a likely limiting resource. |
| **Unmitigated** | The architecture or deployment currently has no control for the risk. |
| **External** | The limit is owned by a dependency and cannot be removed by this repository. |

## Current bottleneck study

| Bottleneck | Why it can limit the platform | Current mitigation | Status | What must be verified |
| --- | --- | --- | --- | --- |
| Public Ingress/Gateway path | Every request enters through the edge and Gateway; connection queues, TLS and routing work are concentrated there. | Gateway has three replicas in Kubernetes; only Gateway is public; resource requests/limits are defined. | **Residual** | p95/p99 latency, active connections, 5xx rate and ingress/controller throughput during peak traffic. |
| Synchronous request chain | Order creation depends on Product, and currency conversion depends on Exchange. One slow dependency increases end-to-end latency. | Services are separated and independently replicated; dependency latency is observable by design. Redis is now available as a shared cache endpoint, but service-level cache logic is not implemented in this repository. | **Residual** | Trace `POST /orders` and converted-order reads; add cache-aside policies only for safe read data; set and test timeouts, bounded retries and failure behavior. |
| External Exchange provider | Provider quotas, latency, outages and rate freshness directly affect conversion requests. | Local Compose uses a deterministic mock; production keeps the provider behind Exchange rather than exposing it directly. Redis can store short-lived rates after Exchange implements cache-aside behavior. | **External** | Provider quota, timeout, error rate and fallback/cache policy. A provider outage cannot be eliminated here; the user-facing degraded behavior must be explicit. |
| PostgreSQL persistence | Connection pools, locks, indexes, I/O and a single writer can serialize account, product and order work. | Kubernetes applications use three replicas and resource bounds; EKS is expected to use managed PostgreSQL/RDS. | **Residual** | Pool saturation, query latency, lock waits, CPU, I/O, storage growth, backup and failover behavior. |
| Database availability | The local `10-database.yaml` has one PostgreSQL replica and no persistent volume, so a pod loss loses availability and can lose local data. | The manifest is documented as MicroK8s-only; EKS skips it and uses external PostgreSQL/RDS. | **Unmitigated locally / mitigated by production boundary** | Use persistent storage and backups for MicroK8s, or verify RDS Multi-AZ, backups and recovery objectives for EKS. |
| Application CPU and memory | A container can be throttled or evicted if its limit is too low, or starve neighbors if it has no bound. | All five Kubernetes Deployments define requests of `250m` CPU/`256Mi` memory and limits of `500m` CPU/`512Mi` memory. | **Mitigated** | Compare utilization and throttling against limits; tune values from a representative workload. |
| Replica scaling | Fixed three-replica application Deployments can saturate during a burst and do not automatically add capacity. | HPA manifests now target Gateway, Order, Account and Auth at 60% CPU with 3-10 replicas. | **Mitigated** | Install Metrics Server and use k6 to verify scale-up latency, scale-down stabilization and node capacity. |
| Rolling disruption | A rollout or node drain can remove too much capacity if replicas are unavailable simultaneously. | PDBs now require two available pods for Gateway, Order, Account and Auth. | **Mitigated** | Add topology spread constraints and verify drain/rollout behavior in a non-production namespace. |
| Product and Exchange image availability | These services are external repositories and are not built from this checkout; missing images prevent the local or production topology from starting. | Compose and EKS accept explicit image/URL configuration; the local Exchange provider mock removes the provider dependency, not the Exchange service dependency. | **Residual** | Pin and scan immutable images, verify registry access, and run a pre-deployment dependency check. |
| Cross-zone network traffic | Calls between services or a database in different availability zones add latency and transfer cost. | Internal services remain cluster-internal; EKS is designed for private subnets and multi-AZ placement. | **Residual** | Measure dependency latency by zone and evaluate placement, connection reuse and data-transfer cost. |
| Logging, serialization and payload size | Excessive logs or large payloads consume CPU, network and storage and increase tail latency. | Structured, low-cardinality observability requirements are documented. | **Unmitigated** | Enforce sampling/redaction, payload limits and log-volume alerts; compare overhead under load. |
| Cache correctness and invalidation | Stale product or exchange data can be worse than a slow request; cache stampedes can move load to the database/provider. | Compose and Kubernetes expose `CACHE_REDIS_URL`; cache implementation, TTLs and invalidation remain service-owned. | **Unmitigated** | Define per-resource TTLs, keys, invalidation, stampede protection and hit-rate/error metrics before enabling caching. |

### Capacity interpretation

The current Kubernetes requests reserve at least:

- `3 × 250m = 750m` CPU and `3 × 256Mi = 768Mi` memory per application
  Deployment (Account, Auth, Order and Gateway);
- `3.0` CPU cores and `3Gi` memory across those four application
  Deployments, before the database, ingress controller, system pods and
  external Product/Exchange workloads are included;
- a database request of `250m` CPU and `256Mi` memory in the local-only
  PostgreSQL manifest.

These are scheduling reservations, not measured throughput. The Gateway and
Ingress remain architectural choke points, but that is acceptable only if
measured peak traffic remains below their tested capacity with the required
latency and error-rate headroom. The project must not claim that three
replicas support a user count until the load-test evidence demonstrates it.

## Required mitigation backlog

The following work is required before a production capacity claim:

1. Define peak requests per second, concurrent users, dataset size and SLOs.
2. Run the flows in [Load testing](load-testing.md), including login, product
   browsing, order creation and converted-order reads.
3. Run the HPA and k6 procedure in [Load testing](load-testing.md).
4. Configure explicit timeout, bounded retry and degraded-response behavior
   for Product, Exchange and the database.
5. Implement service-owned cache-aside behavior and verify hit rate, freshness
   and invalidation for each cached resource.
6. Verify PostgreSQL indexes, pool sizes, backups, failover and recovery.
7. Repeat the tests after each change and retain the results with image tags,
   cluster size and region.

## Investigation procedure

1. Define the user flow and success criteria.
2. Record software versions, dataset size, region and test configuration.
3. Establish baseline throughput, latency, errors and resource usage.
4. Locate the limiting resource using metrics and traces.
5. Apply the smallest safe change.
6. Repeat the same workload and compare p50, p95, p99, throughput and errors.
7. Document the result, trade-offs and rollback plan.

Do not claim a bottleneck was fixed from a single successful request or from
CPU utilization alone.

## Performance record

Each experiment should record:

| Field | Example |
| --- | --- |
| Flow | `POST /orders` |
| Workload | 50 concurrent users, 10 minutes |
| Baseline | p95 800 ms, 2% errors |
| Change | Add product lookup index |
| Result | p95 240 ms, 0% errors |
| Trade-off | Additional storage |
| Evidence | Dashboard, trace or load-test artifact |

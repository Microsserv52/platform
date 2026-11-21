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

| Status          | Meaning                                                                              |
| --------------- | ------------------------------------------------------------------------------------ |
| **Mitigated**   | A control is present and the risk is bounded, but it still needs load-test evidence. |
| **Residual**    | The risk is reduced, but the component remains a likely limiting resource.           |
| **Unmitigated** | The architecture or deployment currently has no control for the risk.                |
| **External**    | The limit is owned by a dependency and cannot be removed by this repository.         |

## Current bottleneck study

| Bottleneck                              | Why it can limit the platform                                                                                                                         | Current mitigation                                                                                                                                                                                                       | Status                                                     | What must be verified                                                                                                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Public Ingress/Gateway path             | Every request enters through the edge and Gateway; connection queues, TLS and routing work are concentrated there.                                    | Gateway has two replicas in Kubernetes; only Gateway is public; resource requests/limits are defined.                                                                                                                  | **Residual**                                               | p95/p99 latency, active connections, 5xx rate and ingress/controller throughput during peak traffic.                                                            |
| Synchronous request chain               | Order creation depends on Product, and currency conversion depends on Exchange. One slow dependency increases end-to-end latency.                     | Services are separated and independently replicated; dependency latency is observable by design. Redis is now available as a shared cache endpoint, but service-level cache logic is not implemented in this repository. | **Residual**                                               | Trace `POST /orders` and converted-order reads; add cache-aside policies only for safe read data; set and test timeouts, bounded retries and failure behavior.  |
| External Exchange provider              | Provider quotas, latency, outages and rate freshness directly affect conversion requests.                                                             | Local Compose uses a deterministic mock; production keeps the provider behind Exchange rather than exposing it directly. Redis can store short-lived rates after Exchange implements cache-aside behavior.               | **External**                                               | Provider quota, timeout, error rate and fallback/cache policy. A provider outage cannot be eliminated here; the user-facing degraded behavior must be explicit. |
| PostgreSQL persistence                  | Connection pools, locks, indexes, I/O and a single writer can serialize account, product and order work.                                              | Kubernetes applications use two replicas and resource bounds; EKS is expected to use managed PostgreSQL/RDS.                                                                                                           | **Residual**                                               | Pool saturation, query latency, lock waits, CPU, I/O, storage growth, backup and failover behavior.                                                             |
| Database availability                   | The local `10-database.yaml` has one PostgreSQL replica and no persistent volume, so a pod loss loses availability and can lose local data.           | The manifest is documented as MicroK8s-only; EKS skips it and uses external PostgreSQL/RDS.                                                                                                                              | **Unmitigated locally / mitigated by production boundary** | Use persistent storage and backups for MicroK8s, or verify RDS Multi-AZ, backups and recovery objectives for EKS.                                               |
| Application CPU and memory              | A container can be throttled or evicted if its limit is too low, or starve neighbors if it has no bound.                                              | All six Kubernetes Deployments (Account, Auth, Gateway, Order, Product, Exchange) define requests of `250m` CPU/`256Mi` memory and limits of `500m` CPU/`512Mi` memory.                                                                                                    | **Mitigated**                                              | Compare utilization and throttling against limits; tune values from a representative workload.                                                                  |
| Replica scaling                         | The two-replica application baseline can saturate during a burst; HPAs and Cluster Autoscaler add capacity.                                        | HPAs target all six services at 70% CPU with 2-6 replicas. Cluster Autoscaler moves the node group from 2 to 6 nodes when pods stay Pending.                                                                                                                                 | **Residual**                                               | Verify metrics-server, Cluster Autoscaler, k6 scale-up latency, scale-down stabilization and node capacity.                                                       |
| Rolling disruption                      | A rollout or node drain can remove too much capacity if replicas are unavailable simultaneously.                                                      | PDBs require one available pod for each of the six services.                                                                                                                                                | **Mitigated**                                              | Add topology spread constraints and verify drain/rollout behavior in a non-production namespace.                                                                |
| Database connections                    | Hikari pools per pod and PostgreSQL `max_connections` cap how many replicas can use the shared database.                                              | Pool of 10 per pod on three database-backed services; `db.t4g.micro` allows 112 connections. Four replicas per service need 120 and fail.                                                                                | **Unmitigated**                                            | Lower the pool to 5 per pod (90 connections at six replicas) or resize RDS before scaling past three; watch pool wait time and connection errors.                |
| Product and Exchange image availability | These services are submodules and the deployment scripts build them from this checkout; missing images or registry access prevent the local or production topology from starting. | Compose and EKS accept explicit image/URL configuration; the local Exchange provider mock removes the provider dependency, not the Exchange service dependency.                                                          | **Residual**                                               | Pin and scan immutable images, verify registry access, and run a pre-deployment dependency check.                                                               |
| Cross-zone network traffic              | Calls between services or a database in different availability zones add latency and transfer cost.                                                   | Internal services remain cluster-internal; EKS is designed for private subnets and multi-AZ placement.                                                                                                                   | **Residual**                                               | Measure dependency latency by zone and evaluate placement, connection reuse and data-transfer cost.                                                             |
| Logging, serialization and payload size | Excessive logs or large payloads consume CPU, network and storage and increase tail latency.                                                          | Structured, low-cardinality observability requirements are documented.                                                                                                                                                   | **Unmitigated**                                            | Enforce sampling/redaction, payload limits and log-volume alerts; compare overhead under load.                                                                  |
| Cache correctness and invalidation      | Stale product or exchange data can be worse than a slow request; cache stampedes can move load to the database/provider.                              | Compose and Kubernetes expose `CACHE_REDIS_URL`; cache implementation, TTLs and invalidation remain service-owned.                                                                                                       | **Unmitigated**                                            | Define per-resource TTLs, keys, invalidation, stampede protection and hit-rate/error metrics before enabling caching.                                           |

### Capacity interpretation

The current Kubernetes requests reserve at least:

- `2 × 250m = 500m` CPU and `2 × 256Mi = 512Mi` memory per application
  Deployment (Account, Auth, Gateway, Order, Product, Exchange);
- `3.0` CPU cores and `3Gi` memory across those six Deployments at the
  two-replica baseline, before the database, ingress controller, metrics-server,
  Cluster Autoscaler and system pods are included;
- a database request of `250m` CPU and `256Mi` memory in the local-only
  PostgreSQL manifest.

These are scheduling reservations, not measured throughput. The Gateway and
Ingress remain architectural choke points, but that is acceptable only if
measured peak traffic remains below their tested capacity with the required
latency and error-rate headroom. The project must not claim that three
replicas support a user count until the load-test evidence demonstrates it.
The [capacity envelope](../infrastructure/costs.md#traffic-scaling-and-capacity)
gives planning request rates and the HPA, node and database limits; a
fourth replica per database-backed service exceeds the RDS connection limit
before CPU does.

## Selected next architecture work

[Redis carts](../services/cart/index.md) are temporary authoritative state, not
a cache of PostgreSQL orders. The dedicated Cart service and seven-day TTL are
selected but not implemented. [Kafka post-order work](../project/asynchronous-events.md)
is proposed to decouple side effects after the order commit; it does not remove
Product lookup or database limits from checkout. The [observability
stack](observability.md) measures these paths locally; Grafana Cloud ingestion
is prepared for sustained retention. [Cloudflare security](../infrastructure/cloudflare.md)
is selected for edge protection; capacity and DDoS behavior still require
configuration and verification. Domain and static CDN remain open.

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

| Field     | Example                                |
| --------- | -------------------------------------- |
| Flow      | `POST /orders`                         |
| Workload  | 50 concurrent users, 10 minutes        |
| Baseline  | p95 800 ms, 2% errors                  |
| Change    | Add product lookup index               |
| Result    | p95 240 ms, 0% errors                  |
| Trade-off | Additional storage                     |
| Evidence  | Dashboard, trace or load-test artifact |

## Bottleneck ownership and evidence plan

The public repository intentionally does not store member names. Each row is a
claimable area for the final submission; assign one row per member in the LMS or
presentation material and attach the measured evidence there.

| Area | Bottleneck 1 | Bottleneck 2 | Current evidence | Next evidence |
| --- | --- | --- | --- | --- |
| Account / Auth | Database connection pool (pool 8 × DB services caps replicas) | Login/JWT/session latency | Pool tuning measured 2026-11-21 | k6 login + profile run, pool wait metrics |
| Order / Product | PostgreSQL locks and single-writer contention | Product image/S3 path and catalogue latency | Catalog read path measured 2026-11-21 | k6 checkout run, `pg_stat_activity`, Product p95 |
| Gateway / Platform | Ingress and Gateway connection queues | HPA/node capacity (three-node observed) | k6 at 300–400 req/s, HPA/node timeline 2026-11-21 | Higher `MAX_VUS` run and ingress test |
| Exchange / Data | External provider quota and latency | Redis cache stampede / eviction | Provider adapter and metrics exposed | Provider error injection, Redis hit ratio |
| Cross-cutting | NAT/egress and payload size | Log volume and serialization cost | Cost model only | NAT bytes, log volume, p95 under load |

Status is **planned / partially evidenced**, not fixed. A row is complete only
after the same workload is run before and after a change with the metrics,
errors and rollback recorded.

## Measured evidence — 2026-11-21

Read-only catalog test against the AWS deployment (`b8fe3c3`, three nodes).

| Bottleneck | Baseline (50 req/s) | Peak (400 req/s target) | Evidence |
| --- | --- | --- | --- |
| Product read path | 2–4 replicas, p95 313 ms | **6/6 replicas**, p95 1.25 s at 300 req/s, 0 errors | k6 + HPA timeline |
| Gateway | 2 replicas, low CPU | **3 replicas**, ~100% of request at peak | HPA + `kubectl top` |
| Database connections | 56 | Pool 10: 71 + slot exhaustion; Pool 5: Hikari waiting 62, 107 5xx; **Pool 8: 52/112, 0 errors** | CloudWatch + service logs |
| Node capacity | 3 nodes | 3 nodes; no autoscaler event | Cluster Autoscaler/monitor log |
| Load generator | 17 dropped | 4,049 dropped (pool 10) / 11,930 (pool 8) at `MAX_VUS=200` | k6 summaries |

The first high run used pool 10: it returned 0 HTTP errors at 383 req/s but RDS
rejected new connections and two Product pods crash-looped. Pool 5 removed the
RDS-slot error but created per-pod Hikari exhaustion (107 real 5xx). **Pool 8 is
retained**: Product 6/6, 0 errors, 52/112 RDS connections, p95 1.25 s.

The remaining measured ceiling is the Product HPA maximum and node CPU, not the
database: Product is pinned at 6 replicas and p95 exceeds 1 s at ~300 req/s,
while RDS has connection and CPU headroom. The next test should raise the
Product HPA/node maximum, increase k6 `MAX_VUS`, and add an authenticated order
flow.

Raw evidence and the full 50/400 req/s timeline are in
[Load testing](load-testing.md#measured-results-2026-11-21).

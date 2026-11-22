---
icon: lucide/gauge
---

# Bottlenecks and performance

The platform has several architectural limits. The table records the current
control for each one and whether the limit is mitigated, residual or external.
Scheduling reservations and single successful requests are not throughput
evidence.

| Constraint | Current control | State |
| --- | --- | --- |
| Public ingress and Gateway | Two Gateway replicas; only Gateway is public; requests and limits are set | Residual |
| Synchronous request chain | Order calls Product and Exchange; services are replicated and traces expose dependency latency | Residual |
| External Exchange provider | Provider stays behind Exchange; Compose uses a deterministic mock | External |
| PostgreSQL persistence | Managed RDS in AWS; two replicas per service; pool of 8 per database-backed pod | Residual |
| Local database availability | MicroK8s PostgreSQL is a disposable single replica; EKS uses RDS | Unmitigated locally |
| Application CPU and memory | All six Deployments request `250m` CPU / `256Mi` memory and limit `500m` / `512Mi` | Mitigated |
| Replica scaling | HPA scales 2–6 replicas at 70% CPU; Cluster Autoscaler moves the node group 2–6 | Residual |
| Rolling disruption | PDB keeps one pod available per service | Mitigated |
| Database connections | Pool 8 × pods; `db.t4g.micro` allows 112 connections | Residual |
| Product and Exchange images | Images are submodules built by the deploy scripts; Compose and EKS accept explicit image values | Residual |
| Cross-zone traffic | Services stay cluster-internal; EKS uses private subnets and multi-AZ placement | Residual |
| Logging and payload size | Structured, low-cardinality requirements are documented | Unmitigated |
| Cache correctness | `CACHE_REDIS_URL` is exposed; `CACHE_ENABLED=false` and no service-level cache logic exists | Unmitigated |

## Capacity

The two-replica baseline reserves `3.0` CPU cores and `3Gi` memory across the six
application Deployments, before the database, ingress controller, metrics-server,
Cluster Autoscaler and system pods. The local PostgreSQL manifest requests `250m`
CPU and `256Mi` memory. These are scheduling reservations, not measured
throughput.

The [capacity envelope](../infrastructure/costs.md#traffic-scaling-and-capacity)
gives planning request rates and the HPA, node and database limits. A fourth
replica per database-backed service exceeds the RDS connection ceiling before it
exceeds CPU.

## Measured AWS result

A read-only catalog run against the three-node AWS deployment with 50 req/s
baseline and a 400 req/s target produced:

| Constraint | Baseline | Peak |
| --- | --- | --- |
| Product read path | 2–4 replicas, p95 313 ms | 6/6 replicas, p95 1.25 s at 300 req/s, 0 errors |
| Gateway | 2 replicas, low CPU | 3 replicas, about 100% of requests at peak |
| Database connections | 56 | Pool 8: 52/112, 0 errors |
| Node capacity | 3 nodes | 3 nodes; no autoscaler event |
| Load generator | 17 dropped | 11,930 dropped at `MAX_VUS=200` |

Pool 10 returned no HTTP errors at 383 req/s but exhausted RDS connection slots
and crash-looped two Product pods. Pool 5 removed the RDS-slot error but caused
Hikari exhaustion and 107 real 5xx responses. Pool 8 is the retained setting.

The measured ceiling is the Product HPA maximum and node CPU, not the database:
Product stays at 6 replicas and p95 exceeds 1 s at about 300 req/s while RDS
keeps connection and CPU headroom. The deployment has no authenticated order
load test at the same scale.

## Limits of this evidence

The run covers catalog reads at one cluster size and region. It does not cover
authenticated checkout, write-heavy workloads, failover, sustained peak traffic
or provider outages, and it is not a capacity guarantee. The k6 scenarios in
[Load testing](load-testing.md) define the repeatable flows and the remaining
measurements.

## Related

- [Load testing](load-testing.md)
- [Observability](observability.md)
- [Costs and capacity](../infrastructure/costs.md)
- [Service observability requirements](../services/observability-requirements.md)

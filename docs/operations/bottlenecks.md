---
icon: lucide/gauge
---

# Bottlenecks and performance

The course project allocates substantial effort to identifying and addressing
bottlenecks. Performance work must be evidence-based: measure a baseline,
change one relevant variable, then compare the result.

## Candidate bottlenecks

- Gateway connection limits and request routing;
- synchronous Order-to-Product calls;
- database indexes, connection pools and lock contention;
- Exchange provider latency, quotas and availability;
- cold starts and insufficient pod resources;
- network traffic between availability zones;
- serialization, logging and excessive payload size.

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

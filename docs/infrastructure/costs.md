---
icon: lucide/badge-dollar-sign
---

# Costs, PaaS and SLA

## Cost plan

!!! note "Dated estimate: 2026-11-20"

    Region `us-east-1`, on-demand Linux list prices, 730 hours per month, no
    credits or Savings Plans; free-tier allowances are called out explicitly.
    Inputs are the resources in
    [`terraform/environments/aws`](https://github.com/Microsserv52/platform/blob/main/terraform/environments/aws)
    and the workloads in [`k8s/base`](https://github.com/Microsserv52/platform/blob/main/k8s/base).
    Re-check the total in the [AWS Pricing Calculator](https://calculator.aws/)
    before provisioning and validate actual spend with
    [Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
    and [AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/).

### Deployment profile

| Setting         | Current value                              | Cost effect                                  |
| --------------- | ------------------------------------------ | -------------------------------------------- |
| Node group      | 2 × `t3.medium`, min 2, max 6              | $61 base; each extra node +$30 + $1.60 EBS   |
| Capacity type   | `ON_DEMAND` (`SPOT` optional)              | Spot cuts the node line by ≈ 60%             |
| HPA             | 2–6 replicas, 70% CPU, six services        | scales pods; installed with `metrics-server` |
| Node autoscaler | Cluster Autoscaler, 2–6 nodes              | adds nodes when pods stay `Pending`          |
| Pod resources   | 250m/500m CPU, 256Mi/512Mi                 | 3.0 vCPU at the two-replica baseline         |
| Database        | `db.t4g.micro`, 112 connections, pool 10   | caps at ≈ 3.7 replicas per database service  |
| Cache           | 1 × `cache.t4g.micro`                      | no replica or failover                       |
| Teardown guard  | `protect_state = true`                     | `destroy` needs `false` applied first        |
| Frontend/edge   | S3 + CloudFront `PriceClass_100`           | 1 TB + 10M requests per month free           |

!!! note "Live deployment: 2026-11-21"

    EKS, RDS, ElastiCache, NAT, S3, ECR and CloudFront are provisioned. The
    autoscaler ran three `t3.medium` nodes during rollout; the two-node baseline
    is the steady target. The internet-facing Gateway NLB adds the load-balancer
    line to the estimate. At the two-node steady state the run-rate is
    ≈ $240/month; at three nodes ≈ $270/month. The AWS Budget is
    configured at USD 150, so destroy or schedule the stack after the demo.

### Continuous operation

| Resource              | Configuration                              | Assumption                                                    | USD/month  | Owner      |
| --------------------- | ------------------------------------------ | ------------------------------------------------------------- | ---------: | ---------- |
| EKS control plane     | 1 cluster                                  | Standard Kubernetes support, $0.10/hour                       |         73 | Platform   |
| Worker nodes          | 2 × `t3.medium`                            | ON_DEMAND, 4 vCPU / 8 GiB, 730 hours                          |         61 | Platform   |
| Node root volumes     | 2 × 20 GB gp3                              | $0.080/GB-month                                               |          3 | Platform   |
| NAT gateway           | 1                                          | $0.045/hour, $0.005/hour public IPv4, 50 GB processed         |         39 | Platform   |
| PostgreSQL            | `db.t4g.micro`, Single-AZ                  | $0.016/hour, 20 GB gp3, 7-day backups                         |         14 | Data       |
| Redis                 | 1 × `cache.t4g.micro`                      | $0.016/hour, no replica, no backup                            |         12 | Data       |
| Network Load Balancer | 1 for ingress-nginx, outside Terraform     | $0.0225/hour, 2 public IPv4, ~1 LCU                           |         28 | Platform   |
| CloudFront            | 1 distribution, `PriceClass_100`           | 50 GB + 1M HTTPS requests (1 TB / 10M requests free tier)     |        0–5 | Platform   |
| S3                    | 4 buckets (media + 3 frontends)            | ~5 GB stored, versioning, low request volume                  |          1 | Platform   |
| ECR                   | 6 repositories                            | ~5 GB stored, scan-on-push                                    |          2 | Platform   |
| CloudWatch Logs       | Container logs                             | ~5 GB ingest, short retention                                 |          3 | Operations |
| Route 53 + ACM        | 1 hosted zone, 1 certificate               | Optional (`create_dns`), ACM certificate free                 |          1 | Platform   |
| **Total**             |                                            | **≈ $0.33 per running hour, ≈ $7.90 per day**                 |   **≈ 240** |           |

More than half of the bill is hourly infrastructure that runs with zero
traffic: the EKS cluster, NAT gateway and load balancer cost ≈ $140/month
together, and the two nodes add ≈ $64. Traffic volume (CloudFront, S3, ECR,
egress) is a small share of the demo bill; running hours and cleanup dominate.

### Budget guardrail

!!! warning "Monthly budget: USD 150"

    The account has an AWS Budget named `Limit budget 100`, configured at
    **USD 150/month** (set 2026-11-20). It is the planning cap for this project:
    validate spend in Cost Explorer and treat a forecast above USD 150 as an
    incident.

A budget is an alerting guardrail; it does not stop resources by itself. The
continuous-operation estimate (≈ $240/month, ≈ $7.90/day) crosses the cap after
about 19 days. Staying inside USD 150 requires the scheduled profile
(≈ $80/month), destroying the stack after the demo, or Spot workers on a shorter
schedule. A six-node peak (≈ $365/month run-rate) consumes the budget in about
12 days.

### Node sizing

The example variables now ship 2 × `t3.medium` with `node_min_size = 2` and
`node_max_size = 6`, and the Cluster Autoscaler moves the node count inside
that range. Each service requests 250m CPU / 256Mi and deploys 2 replicas, so
the baseline requests 3.0 vCPU before kube-system and the ingress controller.
Two nodes fit that baseline; the autoscaler adds a node when a rollout or HPA
surge leaves pods `Pending`.

| Node group                   |  Node cost | Fits                                                                      |
| ---------------------------- | ---------: | ------------------------------------------------------------------------- |
| 2 × `t3.small` (older default) |       30 | No: 4 vCPU total leaves no room for system pods above the 3.0 vCPU apps.  |
| 2 × `t3.medium` (default)    |         61 | HPA minimum (12 pods); Cluster Autoscaler adds nodes for scale-up.        |
| 3 × `t3.medium`              |         91 | One spare node for small bursts without waiting for a new node.           |
| 6 × `t3.medium`              |        182 | HPA maximum (36 pods); normally reached through the autoscaler.           |

Add ≈ $1.60/month per node for its 20 GB gp3 root volume. `t3` is burstable and
throttles once CPU credits are spent; switch the load-test node group to a
fixed-performance family such as `m7i` or `m6i`. `node_capacity_type = "SPOT"`
cuts the node line by roughly 60%, at the cost of possible interruptions; keep
`ON_DEMAND` when measuring latency and autoscaling.

### Traffic, scaling and capacity

!!! important "Planning envelope, not measured capacity"

    The repository has no representative load-test result yet. Replace the CPU
    cost per request with the value measured by the
    [load-testing procedure](../operations/load-testing.md) before using these
    numbers for an SLA or a capacity claim.

Assumptions:

- One active user makes ≈ 0.2 API requests/s (one call every 5 seconds); static
  assets are served by CloudFront and are not counted.
- An API request costs 10 ms of CPU. Use 5 ms for light reads and 25–50 ms for
  order/write flows.
- HPA target is 70% of the 250m request = 175m per pod, for 2–6 replicas across
  six services.
- `t3.medium` allocatable is ≈ 1.93 vCPU; kube-system, metrics-server,
  Cluster Autoscaler and ingress request ≈ 0.8 vCPU across the baseline nodes.
- Three services use the shared database, with a Hikari pool of 10 per pod and
  RDS `max_connections = 112` on `db.t4g.micro`.

#### Where each limit is hit

| Checkpoint                     | App CPU        | Replicas/service | Pods  | API req/s @10 ms | Concurrent users |
| ------------------------------ | -------------: | ---------------: | ----: | ---------------: | ---------------: |
| HPA starts scaling             |       2.1 cores |            2 → 3 | 12–18 |             ~210 |           ~1,050 |
| 2-node baseline (HPA minimum)  |       2.1 cores |                2 |    12 |             ~210 |           ~1,050 |
| RDS connection ceiling         |              — |             ~3.7 |   ~22 |             ~370 |           ~1,850 |
| HPA maximum, 6 nodes, pool ≤ 5 |       6.3 cores |                6 |    36 |             ~630 |           ~3,150 |

- The HPA trigger at the two-replica steady state is
  `2 replicas × 6 services × 0.175 cores = 2.1 cores` of aggregate application
  CPU; `req/s = cores ÷ CPU-seconds per request`.
- The two-node baseline is `2 × 1.93 = 3.86 vCPU` allocatable. The app requests
  3.0 vCPU and system add-ons request ≈ 0.8 vCPU, so the baseline is nearly
  full. A third replica per service requests another 1.5 vCPU and stays
  `Pending` until the Cluster Autoscaler adds a node.
- The database allows `112 ÷ (3 services × 10 connections) ≈ 3.7` replicas per
  database-backed service. A fourth replica per service needs 120 connections
  and fails. Lower the Hikari pool to 5, or move to `db.t4g.small`, before
  scaling past three.
- The HPA maximum needs six nodes and the pool fix. Three nodes support about
  20 pods; six nodes support the full 36-pod HPA maximum. With uneven load the
  database limit can be reached before the CPU limit.

#### Request rate by CPU cost

| CPU per request | HPA starts / 2-node baseline | HPA max, 6 nodes |
| --------------- | ---------------------------: | ---------------: |
| 5 ms            |                  420 req/s |        1,260 req/s |
| 10 ms           |                  210 req/s |          630 req/s |
| 25 ms           |                   84 req/s |          250 req/s |
| 50 ms           |                   42 req/s |          125 req/s |

Divide requests/s by 0.2 to get concurrent users: at 10 ms the HPA starts at
about 1,050 users and the two-node baseline is already at that capacity; the
Cluster Autoscaler adds a node before the third replica can run. A course demo
with 50–100 concurrent users generates 10–20 req/s, or 0.1–0.2 cores — an order
of magnitude below the trigger. A four-hour demo at 20 req/s is ≈ 288k requests
(~14 GB), well inside the free tier. The HPA stays at its minimum and the
autoscaler never adds a node; the bill is the fixed cluster and node floor.
Demonstrating a scale-up requires roughly 200 req/s, or a much higher CPU cost
per request.

#### Cost by load tier

| Load profile                          | Nodes | USD/month |
| ------------------------------------- | ----: | --------: |
| Demo, below ~1,050 concurrent users   |     2 |     ≈ 240 |
| Two-node baseline (~1,050 users)      |     2 |     ≈ 240 |
| Peak with six nodes pre-provisioned   |     6 |     ≈ 365 |
| Cluster Autoscaler 2 → 6, off-peak    |     2 |     ≈ 240 |
| Cluster Autoscaler 2 → 6, at peak     |     6 |     ≈ 365 |
| Spot workers, two nodes               |     2 |     ≈ 205 |
| Spot workers, six nodes               |     6 |     ≈ 255 |

Every continuous row is above the USD 150 budget; only the scheduled or
destroyed profiles fit. Autoscaling pods alone does not change the bill: the
node count and the fixed EKS/NAT/NLB/RDS/Redis charges do. Only the node
autoscaler (or teardown) moves the node line, and it saves money only if the
average node count falls — a 2 → 6 autoscaler with a floor of two has little
idle saving, it caps peak spend and makes the two-node baseline viable.

#### Traffic-driven costs

| Monthly requests | Data at 50 KB/request | CloudFront |
| ---------------: | --------------------: | ---------: |
|              1 M |                 50 GB |  $0 (free) |
|             10 M |                500 GB |     ≈ $1   |
|             25 M |               1.25 TB |     ≈ $33  |
|             50 M |                2.5 TB |    ≈ $160  |
|            100 M |                  5 TB |    ≈ $415  |

CloudFront includes 1 TB of transfer, 10 M HTTPS requests and 2 M function
invocations per month; the Function adds $0.10 per million calls after that. A
two-hour load test at 350 req/s is ≈ 2.5 M requests (~125 GB) and stays free;
only sustained month-long traffic grows this line. Requests that bypass
CloudFront pay $0.09/GB egress plus NAT processing.

#### Autoscalers

`scripts/deploy-aws.sh` installs both add-ons by default:

- **metrics-server** in `kube-system`, so the HPAs receive CPU metrics.
- **Cluster Autoscaler** in `kube-system`, using the IRSA role created by the
  `eks` Terraform module. The node group carries the standard
  `k8s.io/cluster-autoscaler/*` tags and the group is bounded at 2–6 nodes.

Use `--skip-addons` when add-ons are managed separately. Verify:

```bash
kubectl -n kube-system get deploy metrics-server cluster-autoscaler
kubectl top nodes
kubectl -n platform get hpa
aws autoscaling describe-auto-scaling-groups \
  --filters Name=tag-key,Values=k8s.io/cluster-autoscaler/enabled
```

The HPA evaluates every 15 s and waits 5 min before scaling down. Cluster
Autoscaler reacts to a `Pending` pod in ≈ 10 s; a new node takes ≈ 60–90 s and a
new Spring Boot pod ≈ 20–40 s, so a spike takes 1.5–3 minutes to reach full
capacity. Fix the database ceiling (pool 5 or a larger RDS class) before
scaling past three replicas per service, and re-derive the request table from a
k6 run.

### Autoscaling and "scale to zero"

The cluster now has HPAs and a node autoscaler, but it still cannot bring the
bill to zero:

- EKS has no stopped state. The control plane, NAT gateway, load balancer, RDS
  and Redis stay up while the cluster exists: ≈ $175/month before compute.
- Worker nodes are only ≈ $64 of ≈ $240, so scaling them to the two-node floor
  saves little; a 2 → 6 autoscaler caps peak spend rather than idle spend.
- CPU-based HPA cannot use `minReplicas: 0`, and unscheduled pods report no CPU
  metrics. Reaching zero nodes would also require moving CoreDNS, the ingress
  controller and the autoscaler to Fargate: they keep a node alive, and a
  Cluster Autoscaler cannot run on the empty group it is supposed to fill.
- The NLB bills for as long as the ingress controller exists, even with no
  targets behind it.

True zero is teardown: destroy the stack (optionally keeping only the final
snapshot). For load tests, Cluster Autoscaler buys elasticity, not idleness.

### Scheduled operation

A demo or staging-like schedule of 10 hours × 5 days (≈ 217 hours/month) costs
≈ **$80/month** for the same stack, leaving ≈ $70 under the USD 150 budget:
compute, NAT, database, cache and load balancer are billed only while up, while
S3, ECR, EBS, DNS and snapshots bill for the full month. Stopping is not
zero-cost, and it is not the same as deleting:

- EKS has no stop; stop paying the cluster fee only by destroying the cluster.
- RDS stops automatically restart after 7 days and still bills storage and
  backups.
- ElastiCache has no stop; delete and recreate the cluster.
- A released NAT gateway or load balancer recreated with a new address breaks
  DNS and allow-lists.

### Free tier and billing traps

- Never free tier: EKS control plane, NAT gateway, load balancer, public IPv4,
  ECR and the Route 53 hosted zone.
- A new account's 12-month free tier may cover `db.t4g.micro` (750 hours),
  30 GB EBS and 5 GB S3, and CloudFront's 1 TB + 10M requests per month is
  always free. Do not budget on free tier.
- EKS extended support is $0.60/hour (≈ $438/month) once a Kubernetes version
  leaves standard support 14 months after release. Keep `kubernetes_version`
  upgraded; `1.35` is within standard support at this estimate's date.
- Internet egress is $0.09/GB and NAT data processing $0.045/GB. Serve public
  assets through CloudFront and keep image pulls and S3 traffic off the NAT
  where possible.
- Public IPv4 addresses bill at $0.005/hour each; the NAT gateway and the load
  balancer add several.

### Teardown

!!! warning "The stack is protected by default"

    `protect_state = true` keeps RDS deletion protection and its final
    snapshot, and blocks deleting non-empty S3 buckets and ECR repositories.
    Disable the guards and destroy in two steps:

```bash
terraform -chdir=terraform/environments/aws apply   -var protect_state=false
terraform -chdir=terraform/environments/aws destroy -var protect_state=false
```

The first command deletes no data; it only changes the guards. Keep the default
for production. A final snapshot (~$0.095/GB-month) and any retained S3
versions keep billing until they are deleted explicitly.

## Staging estimate

The [planned staging environment](staging.md) is a separate, scheduled
deployment with synthetic data and a fixed monthly cap. Its region, classes and
cap remain undecided; no free-tier eligibility is assumed. Two reference
points from this estimate:

| Option                                                | Indicative cost                                                        |
| ----------------------------------------------------- | ---------------------------------------------------------------------- |
| Dedicated small EKS, 10 h × 5 d                       | ≈ $80/month for this stack, plus observability and AWS edge charges |
| Single VM for MicroK8s, 4 vCPU / 16 GiB, same schedule | ≈ $45–60/month, plus EBS, snapshots and separate observability charges  |

The single-VM option avoids the $73 cluster fee and the managed database/cache
fees but must fit seven JVMs, Kafka and collection agents, and it gives up
EKS/IRSA parity. Scheduled EKS is closer in price than a 24/7 comparison
suggests because the cluster fee also stops when the cluster is destroyed.

Estimate compute/database running hours separately from full-month storage,
backups, networking, security plans, static hosting and self-hosted
observability storage. An external scheduler must reconcile RDS stop/start behavior; shutdown
is not zero-cost. Set budget alerts and manual resizing approval rather than
autoscaling the database or application resources. All implementation remains
on the staging TODO checklist.

## PaaS decisions

| Capability | Selected service | Why | Trade-off / boundary |
| --- | --- | --- | --- |
| Kubernetes control plane | Amazon EKS | Managed API server and control plane; the same manifests run locally and on AWS | $0.10/hour cluster fee; no stopped state; AWS-specific IAM/IRSA |
| Container registry | Amazon ECR | IAM-native pull/push, scan-on-push, lifecycle policy | AWS lock-in; images must be mirrored for another cloud |
| Relational database | Amazon RDS PostgreSQL | Managed backups, patching, PITR and Multi-AZ option | No superuser; connection ceiling on `db.t4g.micro`; storage and backup cost |
| Cache | Amazon ElastiCache Redis | Managed Redis endpoint shared by the services | Single node has no failover; no stop state |
| Object storage | Amazon S3 | Versioning, lifecycle, presigned uploads, private buckets | Egress through CloudFront; bucket policies and CORS must be managed |
| CDN and TLS | Amazon CloudFront | OAC for private buckets, one distribution, default certificate | Edge invalidation and cache behaviour must be tested; no custom domain/ACM yet |
| Network | Terraform VPC, NAT gateway, private subnets | Private workloads with controlled egress | NAT is a fixed hourly cost; AWS Load Balancer Controller is not installed |
| DNS and certificates | Route 53 + ACM (optional) | DNS validation and free public certificates | Domain approval is external to this repository |
| Secrets | Kubernetes `platform-secrets` + AWS Secrets Manager for Grafana | Managed Grafana credentials and runtime application secrets | Application secret rotation/audit is still manual |
| CI | GitHub Actions | Tests, CodeQL, image publishing | Deployment is deliberately shell-first; there is no CI deploy workflow |
| Observability | Self-hosted Prometheus, Mimir, Loki, Tempo, Pyroscope, Grafana, Alloy and blackbox | Prometheus-compatible metrics, long-term Mimir, logs, traces, profiles, Faro, five dashboards, unified alerting | Local stack implemented; EKS manifests prepared but not applied; Java OTel traces and Faro active, Exchange traces and Pyroscope agents pending |
| Documentation | Zensical + GitHub Pages | Versioned docs built from `docs/` | Public site only after merge to `main` |

The full observability stack adds roughly 70 GiB of `gp3` storage (Prometheus,
Grafana, Mimir, Loki, Tempo, Pyroscope, Alloy), about 1.5–2 vCPU and 3–4 GiB of
requests, and is expected to add a third `t3.medium` node. Budget approximately
**$280/month** at the two-node application baseline plus observability, before
optional AWS WAF or an ALB for Grafana. There is no custom domain; Route 53 and
ACM are not currently billed. See [Custom domains](custom-domains.md).

AWS WAF is not attached; Terraform prepares it behind `enable_waf = false`. A CloudFront web ACL with three managed rule groups and
one rate rule costs about **$9.60/month at 1M requests** and **$15/month at
10M requests** (plus CloudWatch Logs). Continuous 300 req/s would cost roughly
$476/month in WAF request fees alone. The prepared Faro path reuses the existing
NLB and CloudFront, so it adds no load-balancer base fee; demo traffic is under
$5/month. See
[AWS observability assessment](aws-observability-assessment.md).

The account budget is named `Limit budget 100` but is configured at **USD 150**.
Actual spend reads `$0.00` because billing ingestion is delayed; the forecast at
the time of the assessment was `$0.07`.

The Terraform boundary is explicit: EKS, ECR, RDS, ElastiCache, S3, CloudFront,
VPC/NAT and IAM are provisioned by Terraform. Kubernetes workloads, HPAs,
Cluster Autoscaler, metrics-server and the optional ingress controller are
applied after the cluster exists. Secrets are runtime Kubernetes objects, not
Terraform outputs beyond the generated RDS password.

## SLA and SLO

!!! info "Targets and local measurements"

    The local stack now measures every service. All six services expose
    Prometheus metrics, and the five dashboards plus unified alert rules are
    provisioned from `observability/`. The live AWS stack has not had the
    observability overlay applied, so the table remains a target contract rather
    than a claim about production traffic.

### Service-level objectives

| Service / flow | SLI | SLO (28 days) | Error budget | Measurement source |
| --- | --- | --- | --- | --- |
| Public API availability | successful responses / all responses | **99.5%** | 3 h 22 min | Gateway/Service RED metrics (implemented) |
| Product reads | fraction of `GET /products*` under 300 ms | **p95 < 300 ms** | 5% of requests | Product `/actuator/prometheus` (implemented) |
| Order writes | fraction of successful order requests under 800 ms | **p95 < 800 ms** | 5% of requests | Order Prometheus metric (implemented) |
| API error rate | 5xx responses / all responses | **< 1%** | 5% of the 28-day window | Gateway/Service RED metrics (implemented) |
| Exchange provider | successful provider calls / all calls | **99%** | 1% | Exchange `/metrics` |
| Readiness | ready pods / desired pods per service | **≥ 99%** | 1% | kube-state-metrics (AWS values prepared) |
| Recovery | RDS point-in-time restore | **RTO 1 h, RPO ≤ 5 min** | — | RDS automated backups (7-day retention) |

### Alert plan

The local stack implements these rules in Grafana unified alerting. The AWS
deployment reuses them; contact points and SMTP values remain deployment
secrets.

| Signal | Condition | Route | Owner |
| --- | --- | --- | --- |
| Availability burn rate | 14.4× over 1 h + 5 m | page | service owner |
| Availability burn rate | 6× over 6 h + 30 m | page | service owner |
| Availability burn rate | 1× over 3 d + 6 h | ticket | service owner |
| Error rate | 5xx > 1% for 10 m | page | gateway owner |
| Latency | p95 > 300 ms for 15 m | ticket | service owner |
| Readiness | any service below 99% ready for 10 m | page | platform owner |
| HPA capacity | HPA at `maxReplicas` for 15 m | ticket | platform owner |
| Database saturation | pool wait time or connection errors for 10 m | page | data owner |
| Exchange provider | provider error rate > 1% for 10 m | page | exchange owner |

Every page alert carries a `runbook_url` and the platform owner; inhibit page
alerts when the dependency alert is already active. The implemented dashboards
are Platform overview, Service RED, SLO/error budget, Synthetic health and
Dependencies. HPA/node capacity is available from kube-state-metrics and
node-exporter in the AWS values. See [Observability](../operations/observability.md)
and [Grafana on AWS](../operations/grafana-aws.md).

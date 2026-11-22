---
icon: lucide/clipboard-check
---

# Delivery evidence

The course delivery must be documented on GitHub and reviewed by the group.
This page is the index for the evidence that should accompany the final
submission.

## Required evidence

- [ ] Contributors and service ownership.
- [x] Architecture diagram and repository map.
- [x] API contracts and examples.
- [x] Local setup and deployment runbook.
- [x] AWS account, region and resource inventory without secrets.
- [x] EKS topology and Kubernetes manifests or commands.
- [ ] CI/CD pipeline runs and rollback procedure.
- [x] Load-test scenarios, raw results and interpretation (catalog read and authenticated order write).
- [x] Bottleneck investigation and before/after comparison (catalog read path).
- [ ] Cost estimate, actual spend and PaaS decisions.
- [x] SLO/SLA definitions and observability dashboards (local stack and AWS-ready IaC).
- [x] Test strategy and final verification.
- [x] Known limitations.

## 2026.2 requirements status

Status is deliberately evidence-based; a design or a plan is not marked as
delivered.

| Requirement | Status | Evidence / action |
| --- | --- | --- |
| Gateway, Auth, Account, Exchange | Met | Service contracts and tests in the submodules |
| Bottlenecks | Partial | Catalog read path measured at 50 and 400 req/s; authenticated order flow measured; provider-failure flow still pending |
| AWS provisioning | Provisioned | Terraform state, resource inventory and budget in this page |
| EKS deployment | Provisioned | EKS 1.35, two nodes, metrics-server and Cluster Autoscaler; rollout evidence below |
| CI/CD | Partial by design | CI tests/CodeQL/GHCR, manual **Publish EKS images** and manual **Deploy to AWS EKS** workflows; deployment remains operator-approved |
| Load tests | Partial | Read-only catalog baseline, HPA run and authenticated order flow completed; provider-failure flow pending |
| PaaS, costs and SLA | Documented | [Costs, PaaS and SLA](../infrastructure/costs.md); actual spend pending |
| Documentation | Published | `https://microsserv52.github.io/platform/`; LocalStack, runbook, observability and Grafana AWS pages are on `main` |
| Public application URL | Available | `https://d15ogksm4jp6sl.cloudfront.net/` (landing), `/store/`, `/admin/`, `/api` |
| Grafana / SLI dashboard | Implemented locally; AWS prepared | Prometheus, Mimir, Loki, Tempo, Pyroscope, Graphite, Telegraf, Grafana, Alloy, blackbox, eight dashboards and unified alerts; see [Observability](../operations/observability.md) and [Grafana on AWS](../operations/grafana-aws.md) |
| Team names, AI disclosure, presentation | Out of repository scope | Intentionally excluded by the project owner |

The observability gap is closed in the repository: all six services expose
metrics, Java services export OpenTelemetry traces, the frontends use Faro, and
the local stack hosts Prometheus, Mimir, Loki, Tempo, Pyroscope and Grafana. The
AWS path is prepared with EBS CSI, Secrets Manager, Helm values, LGTM manifests
and a Cognito/ALB example. The AWS stack is not applied; Exchange traces and
Pyroscope language agents remain pending.

## Deployment evidence

The deployment was run from the root repository with `scripts/deploy-aws.sh`.
Endpoint names are listed in [Service URLs](../infrastructure/service-urls.md).
The first apply was interrupted by the operator, so the already-created EKS
cluster and RDS instance were imported into state and the remaining resources
were applied. No resources were deleted or recreated unnecessarily.

| Item | Evidence |
| --- | --- |
| Account / region | `730335608828` / `us-east-1` |
| Terraform state | `s3://platform-tfstate-730335608828/platform/aws.tfstate` |
| EKS | `platform`, Kubernetes `1.35`, node group `platform-default` |
| Nodes | 3 × `t3.medium` observed during rollout; autoscaler range 2–6 (steady baseline 2) |
| Add-ons | metrics-server `3.14.0` / `0.9.0`; Cluster Autoscaler `9.60.0` / `1.37.0` |
| RDS | `platform-postgres.cf0a6omck937.us-east-1.rds.amazonaws.com:5432` |
| ElastiCache | `platform-redis.wkuz0g.0001.use1.cache.amazonaws.com:6379` |
| CloudFront | `E2HCWED02TM6CL`, `d15ogksm4jp6sl.cloudfront.net` |
| Budget | AWS Budget `Limit budget 100`, configured at **USD 150/month** |
| Load balancer | Gateway NLB `platform-gateway-ecaafe88209b53bc.elb.us-east-1.amazonaws.com` (HTTP 80, CloudFront origin) |

### Images

All six images use tag `b8fe3c3` and are present once in ECR:

| Service | Digest (short) |
| --- | --- |
| account | `sha256:e1263b8d57a6…` |
| auth | `sha256:4d68e4b5cfe4…` |
| gateway | `sha256:3cebd4ca40ee…` |
| order | `sha256:a0c2b5acc71a…` |
| product | `sha256:fb954434c440…` |
| exchange | `sha256:7c552df2ea43…` |

### Verification

```text
kubectl -n platform get deploy
account 2/2, auth 2/2, exchange 2/2, gateway 2/2, order 2/2, product 2/2

kubectl -n platform port-forward svc/gateway 8080:8080
curl http://localhost:8080/actuator/health
{"groups":["liveness","readiness"],"status":"UP"}

curl -o /dev/null -w '%{http_code}' http://localhost:8080/products
200

kubectl top nodes
2 nodes at steady state (3 during the load-test rollout), 2–3% CPU and 37–49% memory at idle

kubectl -n kube-system get deploy
metrics-server 1/1, cluster-autoscaler-aws-cluster-autoscaler 1/1
```

Public frontend and API verification:

```text
GET https://d15ogksm4jp6sl.cloudfront.net/         200  landing
GET https://d15ogksm4jp6sl.cloudfront.net/store/   200  store
GET https://d15ogksm4jp6sl.cloudfront.net/admin/   200  admin
GET https://d15ogksm4jp6sl.cloudfront.net/api/products          200
GET https://d15ogksm4jp6sl.cloudfront.net/api/actuator/health  200 UP
```

The ASG carries `k8s.io/cluster-autoscaler/enabled` and
`k8s.io/cluster-autoscaler/platform`; min 2, max 6, desired 3 at the time of the
check. All six HPAs report CPU after the rollout settled (0–3% at idle), and no
pod has restarted.

### Load-test evidence

- Baseline: 50 req/s, 2 min, 5,984 requests, 0 errors, p95 313 ms.
- Original pool 10: 382.7 req/s, 0 HTTP errors, p95 602 ms, but Product at 6
  replicas exhausted RDS slots and two pods crash-looped.
- Pool 5: 209.8 req/s, 107 HTTP errors (0.42%), p95 2.21 s; Hikari exhausted.
- **Pool 8 retained**: 299.6 req/s, 36,071 requests, **0 errors**, p95 1.25 s;
  Product 6/6, RDS 52/112 connections, no restarts.
- Gateway scaled 2 → 3; Product 2 → 6; account/auth/order/exchange stayed at 2.
- Node count stayed 3; Cluster Autoscaler did not add a node.
- k6 dropped 11,930 iterations at `MAX_VUS=200`; server throughput is a lower
  bound.
- S3 CORS preflight from the CloudFront origin returned 200 with
  `PUT`/`GET`/`HEAD`, `Content-Type`, `If-None-Match` and `ETag` allowed.
- Authenticated order flow, local Compose: 601 orders at 5/s, **0 errors**,
  p95 634 ms, p99 1.05 s; a clean 5/s rerun measured p95 48 ms and p99 378 ms.
  Raw log: [authenticated orders](../operations/load-test-results/2026-11-21-authenticated-orders.log);
  summary: [JSON](../operations/load-test-results/2026-11-21-authenticated-orders-summary.json).
- Admin image upload acceptance passed locally: ticket 201, signed PUT 200,
  attach 200, media download 200 (27,740 bytes), cleanup 204. Log:
  [admin upload](../operations/verification/2026-11-21-admin-upload.log).

The remaining measured ceiling is Product's HPA maximum and node CPU; the
database has headroom after the pool tune. Provider-failure and authenticated
AWS write flows are still pending, and AWS image upload still needs an admin
account and a browser acceptance run.

Raw logs and summaries:
[baseline](../operations/load-test-results/2026-11-21-baseline.log),
[pool 10](../operations/load-test-results/2026-11-21-high.log),
[pool 5](../operations/load-test-results/2026-11-21-high-pool5.log),
[pool 8](../operations/load-test-results/2026-11-21-high-pool8.log),
[pool 8 summary](../operations/load-test-results/2026-11-21-high-pool8-summary.json).
Full analysis: [Load testing](../operations/load-testing.md#measured-results-2026-11-21).

### Resource and cost audit

Exactly one VPC, NAT gateway, EKS cluster, RDS instance, ElastiCache cluster and
CloudFront distribution exist. There are four application S3 buckets, one
Terraform state bucket, six ECR repositories and no duplicate stacks.

At the observed two-node steady state the run-rate is approximately
**$240/month** (EKS $73, nodes $61 + EBS, NLB, RDS, ElastiCache, NAT, storage).
The full observability stack adds about 70 GiB of EBS and likely a third node,
so budget approximately **$280/month**. The internet-facing Gateway NLB is included in the estimate; CloudFront serves the public frontend and `/api`. The account budget is configured at USD 150 (its name says 100), so
the stack must be destroyed or scheduled after the demo.

### Observability evidence — 2026-11-21

The local Compose stack was started with the `observability` profile and
verified end to end:

```text
Prometheus targets: 12 up, 0 unhealthy
Grafana: 13.3.1, database ok; datasources: Prometheus, Mimir, Loki, Tempo, Pyroscope
Mimir: /ready and remote-write query return series
Dashboards: Platform overview, Service RED, SLO and error budget,
            Synthetic health, Dependencies
Alert rules: 8 provisioned; notification policy -> platform-email
Recording rules: 13 healthy
Synthetic probes: 5/5 successful (landing, store, admin, catalog, health)
Loki: container logs received; Tempo: OTel spans from gateway, auth, account, order and product
Pyroscope: ready; Alloy: OTLP, Faro and log pipelines ready
Faro: landing, store and admin builds use http://localhost:8080/faro/collect;
preflight returns 204 and a headless browser POSTed twice to /faro/collect (202)
```

- [Observability verification log](../operations/verification/2026-11-21-observability.log)
- [Local stack guide](../operations/observability.md)
- [AWS deployment plan](../operations/grafana-aws.md)
- [AWS Faro/WAF/cost assessment](../infrastructure/aws-observability-assessment.md)

## Known limitations

These are deliberate gaps, not hidden claims:

- **NLB origin is HTTP internally.** CloudFront terminates viewer TLS and
  reaches the Terraform NLB over HTTP. The NLB security group only allows the
  AWS CloudFront origin-facing prefix list; direct NLB access times out.
- **No custom domain.** The public URL is the CloudFront hostname. Adding one
  needs a domain, Route 53 hosted zone, ACM certificate, CloudFront alias and
  updates to CORS, cookies, Cognito and Faro origins. See
  [Custom domains](../infrastructure/custom-domains.md).
- **Grafana AWS stack is prepared, not applied.** The repository has the Helm
  values, manifests, EBS CSI flag, Secrets Manager containers and Cognito ingress
  example. Applying them provisions AWS resources and is a separate operator
  action.
- **Exchange traces and profiles need agents.** The Java services load the
  OpenTelemetry agent; Exchange (Python) still exports metrics/logs only, and
  Pyroscope needs language agents and an overhead decision.
- **Provider-failure and authenticated AWS write load tests are pending.** The
  read and authenticated order paths were measured locally; the live AWS write
  path and Exchange failure mode were not.
- **Image upload is verified locally, not in AWS.** The local ticket → signed
  PUT → attach → download flow passed. The AWS S3/CloudFront browser flow still
  needs an admin account and an acceptance run.
- **NetworkPolicy is limited.** The observability manifests allow scrape traffic,
  but platform services are still reachable inside the cluster and are not fully
  isolated.
- **EBS CSI is optional.** It is wired behind `enable_observability` and has not
  been applied to the live cluster.
- **Deployment is manual.** The **Publish EKS images** workflow builds and
  pushes images, and the **Deploy to AWS EKS** workflow calls the deploy script
  on dispatch. Neither runs on a push. See
  [CI/CD](../development/cicd.md#eks-image-publishing-workflow).
- **Database scaling ceiling.** Four replicas per database-backed service exceed
  the `db.t4g.micro` connection limit until the pool is reduced or RDS resized.
- **Staging is configuration-only.** The Terraform environment in
  `terraform/environments/staging` and the overlay in `k8s/overlays/staging`
  define a private one-replica deployment with its own RDS, ElastiCache, S3,
  ECR and observability storage. No CI/CD workflow provisions or deploys it, so
  a running staging environment is not part of the delivery evidence.

## Staging configuration

The [staging environment](../infrastructure/staging.md) uses the same service
images, contracts and probes as production at one replica per service. It has no
public edge; access is through the EKS endpoint and `kubectl port-forward`.
Applying the Terraform environment and the Kubernetes overlay is a manual
operator action. The environment uses `deployment.environment=staging`, synthetic
data and separate telemetry storage.

## AI disclosure

The course permits limited AI assistance for tasks such as boilerplate,
improvements and error fixing. The delivery must state:

- which artifacts or code were assisted by AI;
- what prompts or task descriptions were used when relevant;
- what the group reviewed, tested and changed;
- which parts were implemented directly by group members.

Every group member must understand and be able to defend the complete project,
including AI-assisted work.

## Reproducibility

For each claim, link to a commit, pull request, workflow run, dashboard export,
load-test report or command output. Include the date, environment and version.
Never include credentials, private tokens or personal data in evidence.

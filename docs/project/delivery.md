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
- [ ] Load-test scenarios, raw results and interpretation.
- [ ] Bottleneck investigation and before/after comparison.
- [ ] Cost estimate, actual spend and PaaS decisions.
- [ ] SLO/SLA definitions and observability dashboards.
- [x] Test strategy and final verification.
- [x] Known limitations and future work.

## 2026.2 requirements status

Status is deliberately evidence-based; a design or a plan is not marked as
delivered.

| Requirement | Status | Evidence / action |
| --- | --- | --- |
| Gateway, Auth, Account, Exchange | Met | Service contracts and tests in the submodules |
| Bottlenecks | Partial | Analysis table updated; before/after measurements still pending |
| AWS provisioning | Provisioned | Terraform state, resource inventory and budget in this page |
| EKS deployment | Provisioned | EKS 1.35, two nodes, metrics-server and Cluster Autoscaler; rollout evidence below |
| CI/CD | Partial by design | CI tests/CodeQL/GHCR; AWS deployment is shell-first and documented; no deploy workflow |
| Load tests | Not run | k6 procedure and capacity envelope ready; raw results pending |
| PaaS, costs and SLA | Documented | [Costs, PaaS and SLA](../infrastructure/costs.md); actual spend pending |
| Documentation | Branch only | LocalStack, runbook and changes pages exist on this branch; merge to `main` republishes Pages |
| Public application URL | Not available | No ingress controller or frontend publish yet; backend is reachable by port-forward |
| Grafana / SLI dashboard | Not implemented | Explicitly out of this change; SLO targets and alert plan are documented |
| Team names, AI disclosure, presentation | Out of repository scope | Intentionally excluded by the project owner |

The Grafana gap remains the largest quality item: Product and Exchange expose
metrics, but Gateway, Auth, Account and Order need Prometheus instrumentation
before the SLOs can be measured. That work is planned, not claimed.

## Deployment evidence — 2026-11-21

The deployment was run from the root repository with `scripts/deploy-aws.sh`.
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
| Budget | AWS Budget `Limit budget 100` (USD 100/month) |
| Load balancer | none installed; no public ingress |

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
3 nodes, 2–3% CPU and 37–49% memory during the idle check

kubectl -n kube-system get deploy
metrics-server 1/1, cluster-autoscaler-aws-cluster-autoscaler 1/1
```

The ASG carries `k8s.io/cluster-autoscaler/enabled` and
`k8s.io/cluster-autoscaler/platform`; min 2, max 6, desired 3 at the time of the
check. All six HPAs report CPU after the rollout settled (0–3% at idle), and no
pod has restarted.

### Resource and cost audit

Exactly one VPC, NAT gateway, EKS cluster, RDS instance, ElastiCache cluster and
CloudFront distribution exist. There are four application S3 buckets, one
Terraform state bucket, six ECR repositories and no duplicate stacks.

At three nodes the steady run-rate is approximately **$240/month** (EKS $73,
nodes $91 + EBS, RDS, ElastiCache, NAT, storage); at the two-node baseline it is
about **$210/month**. There is no ingress NLB. The account budget is USD 100, so
the stack must be destroyed or scheduled after the demo.

## Known limitations and next work

These are deliberate gaps, not hidden claims:

- **No public application URL.** The cluster has no ingress controller or load
  balancer, and the static frontends are not published. The backend is reachable
  by `kubectl port-forward`; CloudFront serves only the buckets after a frontend
  sync.
- **No Grafana/Alloy stack.** Product and Exchange expose metrics; Gateway,
  Auth, Account and Order do not yet expose Prometheus metrics, so the SLO
  targets in [Costs, PaaS and SLA](../infrastructure/costs.md#sla-and-slo) are
  not measured.
- **No load-test results or HPA/Cluster Autoscaler timeline.** The procedure and
  capacity envelope are ready; the execution plan is marked "not run".
- **No tracing and no NetworkPolicy.** The manifests keep services
  cluster-internal but do not enforce network isolation.
- **No EBS CSI / persistent volumes.** The workloads are stateless; RDS and S3
  hold persistent data.
- **No CI deploy workflow.** This is intentional; the shell deployment is the
  single path. See [CI/CD](../development/cicd.md#deployment-model-in-this-repository).
- **Image upload is not verified end to end.** The S3/CloudFront configuration
  is provisioned, but the browser presign flow still needs an acceptance run.
- **Database scaling ceiling.** Four replicas per database-backed service exceed
  the `db.t4g.micro` connection limit until the pool is reduced or RDS resized.
- **No staging environment.** The developer-only staging plan remains a backlog
  item.

## Staging backlog — not implemented

- [ ] Implement and accept the [developer-only staging plan](../infrastructure/staging.md):
      fixed small copies of all production business services, scheduled availability,
      synthetic seed data, Cloudflare Access, separate Grafana Cloud observability,
      Faro errors enabled and Umami/usage analytics disabled.
- [ ] Record the approved budget/schedule, hosting/parity tradeoffs, isolation
      tests, independent telemetry gates, recovery/rollback and operating evidence.

These items are TODO; documenting the plan does not complete them.

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

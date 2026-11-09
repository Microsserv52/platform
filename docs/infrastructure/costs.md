---
icon: lucide/badge-dollar-sign
---

# Costs, PaaS and SLA

## Cost plan

Estimate monthly costs for the selected AWS region and expected utilization.
Include EKS control plane, worker nodes or Fargate, load balancers, storage,
data transfer, registry, database, logs, metrics and NAT gateways.

Use the [AWS Pricing Calculator](https://calculator.aws/) before provisioning
and validate the estimate with [Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
and [AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/).

| Resource          | Quantity | Assumption               | Monthly estimate | Owner      |
| ----------------- | -------: | ------------------------ | ---------------: | ---------- |
| EKS control plane |        1 | Environment and region   |              TBD | Platform   |
| Worker nodes      |      TBD | Instance type and hours  |              TBD | Platform   |
| Database          |      TBD | Engine, size and backups |              TBD | Data       |
| Load balancer     |      TBD | Requests and hours       |              TBD | Platform   |
| Logs and metrics  |      TBD | Retention and ingestion  |              TBD | Operations |

Update the table with evidence and date whenever the architecture changes.

## Staging estimate — TODO

The [planned staging environment](staging.md) uses scheduled availability and
fixed small resources with synthetic data. Exact hours, region, classes and
monthly cap remain undecided; no price or free-tier eligibility is assumed.
Compare the proposed single-node MicroK8s cost-first option with dedicated EKS,
including the managed cluster fee, private egress and operational work.

Estimate compute/database running hours separately from full-month storage,
backups, networking, security plans, static hosting and isolated Grafana Cloud
charges. An external scheduler must reconcile RDS stop/start behavior; shutdown
is not zero-cost. Set budget alerts and manual resizing approval rather than
autoscaling the database or application resources. All implementation remains
on the staging TODO checklist.

## PaaS decisions

Document which managed services are used as PaaS, why they were selected, what
operational work they remove, and their cost and portability trade-offs. EKS,
managed databases, managed load balancers and managed observability are
possible examples; do not label a service PaaS without explaining the boundary.

## SLA and SLO

Define service-level objectives before claiming an SLA:

- availability target;
- latency target for the main flows;
- acceptable error rate;
- recovery time and recovery point objectives;
- maintenance and dependency exclusions;
- measurement window and monitoring source.

The SLA document must link each objective to an observable metric and an
incident response or rollback procedure.

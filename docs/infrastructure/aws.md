---
icon: lucide/cloud
---

# AWS setup

For the operational commands, see the [deployment runbook](runbook.md). This
page is a checklist for the project environment, not a replacement for the
official AWS documentation.

## Account and access

- Create a dedicated project account or isolated environment.
- Enable MFA for human users.
- Prefer IAM roles and short-lived credentials over long-lived access keys.
- Configure AWS CLI with a named profile and an explicit region.
- Apply least-privilege policies and record who can access production resources.
- The account has a USD 100/month AWS Budget; see the
  [budget guardrail](costs.md#budget-guardrail). Keep billing alerts active
  before creating infrastructure.

Never commit `~/.aws`, access keys, kubeconfig files or credentials to Git.

```bash
aws configure --profile platform
aws configure list --profile platform
aws sts get-caller-identity --profile platform
```

## Provisioning

AWS infrastructure is declared in [`terraform/`](https://github.com/Microsserv52/platform/blob/main/terraform/README.md):
VPC/subnets, EKS, ECR, RDS, ElastiCache, S3, CloudFront, IAM/IRSA and optional
Route 53/ACM. Apply it against LocalStack for the rehearsal or against a real
account for production. Kubernetes workloads live in [`k8s/`](https://github.com/Microsserv52/platform/blob/main/k8s/README.md)
and are applied by the deployment scripts. A manual **Publish EKS images**
workflow builds and pushes ECR images; there is no CI deploy step.

## Deployed environment (2026-11-21)

The current account contains exactly one of each resource below; no duplicate
stacks were created.

| Item | Value |
| --- | --- |
| AWS account / region | `730335608828` / `us-east-1` |
| Terraform state | `s3://platform-tfstate-730335608828/platform/aws.tfstate` |
| EKS | `platform`, Kubernetes `1.35`, node group `platform-default` |
| Nodes | 2 × `t3.medium` baseline (Cluster Autoscaler range 2–6; a third node may appear during rollout) |
| Add-ons | metrics-server `3.14.0` / `0.9.0`; Cluster Autoscaler `9.60.0` / `1.37.0` |
| RDS | `platform-postgres.cf0a6omck937.us-east-1.rds.amazonaws.com:5432` |
| ElastiCache | `platform-redis.wkuz0g.0001.use1.cache.amazonaws.com:6379` |
| S3 | `platform-media-730335608828`, `platform-landing-…`, `platform-store-…`, `platform-admin-…` |
| ECR | `730335608828.dkr.ecr.us-east-1.amazonaws.com` (6 repositories) |
| CloudFront | `E2HCWED02TM6CL`, `d15ogksm4jp6sl.cloudfront.net` (frontend and `/api`) |
| Public frontend/API | `https://d15ogksm4jp6sl.cloudfront.net/`; `/store/`, `/admin/`, `/api` |
| NAT gateway | 1 |
| Load balancer | Gateway NLB `platform-gateway-ecaafe88209b53bc.elb.us-east-1.amazonaws.com` (internet-facing, HTTP 80, CloudFront-only SG) |
| Budget | AWS Budget `Limit budget 100` (USD 100/month) |

The workload rollout and cost evidence are recorded in
[delivery evidence](../project/delivery.md). The public, internal and AWS
endpoint map is in [Service URLs](service-urls.md).

## Resource inventory

Record the region, owner, environment, purpose, monthly estimate and deletion
procedure for every AWS resource. At minimum consider VPC, subnets, NAT or
internet gateways, EKS control plane, node groups, load balancer, registry,
database and monitoring.

Tag resources with `Project`, `Environment`, `Owner` and `ManagedBy`.

## Operational safety

- Use infrastructure templates or documented repeatable commands.
- Keep application pods in private subnets.
- Keep public load balancers in public subnets.
- Back up persistent data and test restoration.
- Restrict security groups and network policies.
- Define a teardown checklist to avoid unexpected charges.

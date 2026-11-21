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
and are applied by the deployment scripts; there is no CI/CD deploy workflow.

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

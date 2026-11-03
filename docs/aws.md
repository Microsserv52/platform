---
icon: lucide/cloud
---

# AWS setup

The course exercise expects the project to use AWS, EKS, CI/CD, load testing
and cost analysis. This page is a checklist for the project environment, not a
replacement for the official AWS documentation.

## Account and access

- Create a dedicated project account or isolated environment.
- Enable MFA for human users.
- Prefer IAM roles and short-lived credentials over long-lived access keys.
- Configure AWS CLI with a named profile and an explicit region.
- Apply least-privilege policies and record who can access production resources.
- Configure billing alerts before creating infrastructure.

Never commit `~/.aws`, access keys, kubeconfig files or credentials to Git.

```bash
aws configure --profile platform
aws configure list --profile platform
aws sts get-caller-identity --profile platform
```

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

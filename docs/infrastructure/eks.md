---
icon: lucide/boxes
---

# EKS and Kubernetes

The reference topology uses an EKS cluster with two public subnets for load
balancers and two private subnets for application pods. Spread workloads across
availability zones when capacity and budget allow.

## Setup sequence

1. Create the EKS IAM role.
2. Create a VPC with public and private subnets in the selected region.
3. Create the EKS control plane.
4. Create a node-group role with only required permissions.
5. Create a node group in private subnets.
6. Configure local access and verify nodes.

```bash
aws eks update-kubeconfig --name <cluster> --region <region> --profile platform
kubectl config current-context
kubectl get nodes
kubectl get pods --all-namespaces
```

## Workload requirements

Every deployment should define:

- readiness and liveness probes;
- CPU and memory requests and limits;
- replica count appropriate to the environment;
- a rolling update strategy;
- a PodDisruptionBudget for critical services;
- non-root security context where supported;
- configuration through ConfigMaps and Secrets;
- network policies and an explicit service account.

Use an ingress or load balancer only for the Gateway. Keep internal services
cluster-internal.

## Autoscaling

Horizontal Pod Autoscaling must be driven by a meaningful resource or custom
metric and verified under load. Record minimum and maximum replicas, target,
scale-up and scale-down behavior. Delete temporary test resources after the
experiment.

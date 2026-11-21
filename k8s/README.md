# Kubernetes deployment

For the full AWS and LocalStack operational sequence, see the
[deployment runbook](../docs/infrastructure/runbook.md). For the staging
configuration, see the [staging environment](../docs/infrastructure/staging.md).

Kubernetes runs the backend during the LocalStack rehearsal and in real AWS EKS.
Configuration is shared through Kustomize:

```text
k8s/
  base/                 # workloads, Services, Ingress, HPA, PDB, ConfigMap
  overlays/
    microk8s/           # local PostgreSQL and Redis, nginx ingress
    localstack/         # LocalStack EKS, Traefik ingress, exchange mock
    aws/                # EKS, nginx ingress, IRSA service account
    staging/            # one replica per service, private staging configuration
  observability/        # Grafana, blackbox, ServiceMonitors, Probe
```

## Apply an overlay

The `aws` and `microk8s` overlays expect an nginx ingress controller; install it
first (for EKS, the ingress-nginx controller or an AWS Load Balancer Controller
with matching annotations). The `localstack` overlay expects the Traefik
controller that LocalStack EKS provides.

```bash
kubectl apply -k k8s/overlays/microk8s
kubectl apply -k k8s/overlays/localstack
kubectl apply -k k8s/overlays/aws
kubectl apply -k k8s/overlays/staging
```

For MicroK8s, also build the media mock image:

```bash
docker build -t microsserv52-image-storage:local mocks/image-storage
```

Neither overlay contains credentials. Create the runtime secret first:

```bash
JWT_SECRET="$(openssl rand -base64 48)" \
INTERNAL_SERVICE_SECRET="$(openssl rand -base64 32)" \
SPRING_DATASOURCE_URL="jdbc:postgresql://database:5432/platform" \
SPRING_DATASOURCE_USERNAME=admin \
SPRING_DATASOURCE_PASSWORD="$(openssl rand -base64 24)" \
CACHE_REDIS_URL=redis://redis:6379 \
scripts/create-platform-secrets.sh
```

`platform-secrets` contains `JWT_SECRET`, `INTERNAL_SERVICE_SECRET`,
`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`,
`SPRING_DATASOURCE_PASSWORD` and `CACHE_REDIS_URL`.
`EXCHANGE_PROVIDER_API_KEY` is included only when the provider requires it;
the Exchange Deployment treats that secret key as optional.

## Observability

`k8s/observability` deploys Mimir, Loki, Tempo, Pyroscope, Alloy, Grafana,
blackbox, ServiceMonitors and synthetic probes. Prometheus comes from
`kube-prometheus-stack` and remote-writes to Mimir. The base overlay also adds
the OpenTelemetry Java agent init container to the five Java Deployments. It is
installed after `kube-prometheus-stack`:

```bash
scripts/install-observability.sh
# LocalStack EKS rehearsal:
scripts/install-observability.sh --localstack
```

The observability PVCs use `gp3` on AWS and `local-path` in the LocalStack
overlay. Grafana is ClusterIP only. The ALB + Cognito option and the
custom-domain prerequisite are documented in
[Grafana on AWS](../docs/operations/grafana-aws.md). See
[Observability](../docs/operations/observability.md) for the dashboards, alerts
and local Compose profile.

## Workloads

| Workload               | Replicas | Notes                                       |
| ---------------------- | -------- | ------------------------------------------- |
| `gateway`, `auth`, `account`, `order`, `product`, `exchange` | 2 | HPA 2–6 and PDB in production |
| `gateway`, `auth`, `account`, `order`, `product`, `exchange` | 1 | `staging` overlay; HPA fixed at 1 |
| `database`, `redis`    | 1        | `microk8s` overlay only, disposable         |
| `exchange-mock`        | 1        | `localstack` overlay only                   |

Frontends are static exports served by S3 and CloudFront, not pods. The demo
seeder is never deployed.

## Overlay differences

| Setting            | microk8s                  | localstack                  | aws                                  | staging                              |
| ------------------ | ------------------------- | --------------------------- | ------------------------------------ | ------------------------------------ |
| Ingress class      | `nginx` (base)            | `traefik`                   | `nginx` with TLS redirect annotation | `nginx`, cluster-internal            |
| Public API         | port-forward only         | LocalStack ingress          | `gateway-public` NodePort behind Terraform NLB | port-forward only          |
| Database           | local `database`          | LocalStack RDS              | RDS                                  | private RDS                          |
| Cache              | local `redis`             | LocalStack ElastiCache      | ElastiCache                          | private ElastiCache                  |
| Image source       | local images              | LocalStack ECR              | ECR                                  | staging ECR                          |
| S3 credentials     | not used                  | dummy env values            | Product IRSA service account         | Product IRSA service account         |
| Product image mode | `s3` (bucket placeholder) | `s3` (LocalStack bucket)    | `s3` (real bucket)                   | `s3` (private staging bucket)        |
| Replicas           | 2                         | 1                           | 2, HPA 2–6                           | 1, HPA fixed at 1                    |

## Runtime configuration

The base ConfigMap holds internal service URLs, cache toggles and Product image
settings. Endpoints that depend on infrastructure are patched after apply by
the deployment scripts:

```bash
kubectl -n platform patch configmap platform-config --type merge -p '{"data":{...}}'
```

The Ingress rewrites `/api/(.*)` to `/$1` because the Gateway serves `/products`,
not `/api/products`. Compose's nginx and the CloudFront function perform the
same prefix strip.

`SPRING_PROFILES_ACTIVE=prod` is set on the Product Deployment so it enables the
S3 backend and structured logging. `ADMIN_EMAIL` and `ADMIN_PASSWORD` must never
be set in the cluster; promote real accounts with SQL.

## Autoscaling

The production HPAs scale all six services from 2 to 6 replicas at 70% CPU. The
`staging` overlay pins each HPA to one replica and there is no Cluster Autoscaler.
`scripts/deploy-aws.sh` installs `metrics-server` and Cluster Autoscaler by
default; pass `--skip-addons` when you manage them separately. Terraform
creates the autoscaler IRSA role and tags the managed node group with
`k8s.io/cluster-autoscaler/enabled` and
`k8s.io/cluster-autoscaler/<cluster>`, so the autoscaler discovers the group
automatically and moves it between 2 and 6 nodes.

For MicroK8s, enable metrics-server (`microk8s enable metrics-server`); there is
no node autoscaler in the single-node overlay. Verify an EKS deployment with:

```bash
kubectl -n kube-system get deploy metrics-server cluster-autoscaler
kubectl top nodes
kubectl -n platform get hpa
aws autoscaling describe-auto-scaling-groups \
  --filters Name=tag-key,Values=k8s.io/cluster-autoscaler/enabled
```

The two-node baseline fits the 12-pod HPA minimum. A third replica per service
requests more CPU than the baseline has, so it stays `Pending` until Cluster
Autoscaler adds a node. The shared RDS instance allows about 3.7 replicas per
database-backed service; lower the Hikari pool or resize RDS before scaling
past three. Check the
[capacity envelope](../docs/infrastructure/costs.md#traffic-scaling-and-capacity)
before a load test.

## LocalStack constraints

- LocalStack EKS is k3s, not real EKS; VPC and security groups are metadata.
- The single node carries a control-plane taint. The `localstack` overlay adds
  the toleration and sets one replica per deployment. HPA stays idle without
  `metrics-server`, and Cluster Autoscaler is not installed for LocalStack.
- CloudFront is provisioned through the API but edge delivery is emulated.
- RDS and ElastiCache ports are dynamic and published on loopback. The deployment
  script reads the current endpoints and uses the LocalStack container IP so
  pods can reach them.
- LocalStack does not install an ingress controller. Use
  `kubectl port-forward svc/gateway 8080:8080` and call `/products` directly.
- Product S3 server-side calls need `AWS_ENDPOINT_URL` support from the AWS SDK;
  the browser presign flow also needs an HTTPS origin in
  `NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS`. Validate this path before claiming full
  image-upload parity.

## Real EKS

Terraform creates the cluster, node group, access entry, Product IRSA role and
the Cluster Autoscaler IRSA role. The deploy script installs `metrics-server`
and Cluster Autoscaler, annotates the `product` service account with the IRSA
role and patches the ConfigMap with the real RDS, Redis, S3 and CloudFront
values. See [`../terraform/README.md`](../terraform/README.md).

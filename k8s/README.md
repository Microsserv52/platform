# Kubernetes deployment

Kubernetes is the production backend. It does not use local Compose defaults:
database credentials, JWT credentials, and the production database URL must
come from a Kubernetes Secret or the deployment workflow. Product and Exchange
are external services and their production base URLs must be configured as
`PRODUCT_URL` and `EXCHANGE_URL`.

The manifest targets MicroK8s with the Nginx ingress addon and can be adapted
to AWS EKS by replacing local image names with registry references.

Create the required runtime secret without committing credentials:

```bash
microk8s kubectl create namespace platform
microk8s kubectl -n platform create secret generic platform-secrets \
  --from-literal=JWT_SECRET="$(openssl rand -base64 48)" \
  --from-literal=INTERNAL_SERVICE_SECRET="$(openssl rand -base64 32)" \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:postgresql://database:5432/platform" \
  --from-literal=SPRING_DATASOURCE_USERNAME="admin"
```

For local MicroK8s, set `PRODUCT_URL` and `EXCHANGE_URL` in
`00-namespace-config.yaml` to reachable service URLs, then apply:

```bash
microk8s start
microk8s status --wait-ready
microk8s enable dns metrics-server ingress
microk8s kubectl apply -f k8s/
```

The HPA resources in `70-hpa.yaml` require the `metrics-server` addon. Verify
it before testing autoscaling:

```bash
microk8s kubectl top nodes
microk8s kubectl top pods -n platform
microk8s kubectl get hpa -n platform
```

For a local HPA test, load the application images into MicroK8s or change the
manifest image references to registry images, deploy `70-hpa.yaml` and
`71-pdb.yaml`, then generate traffic with the k6 procedure in
[`load-testing.md`](../docs/operations/load-testing.md). HPA cannot scale a
Deployment whose pods are not running and ready.

The Kubernetes resources are split by responsibility:

- `00-namespace-config.yaml`: namespace and shared service configuration.
- `10-database.yaml`: PostgreSQL Service and Deployment.
- `20-account.yaml`, `30-auth.yaml`, `40-order.yaml`, and `50-gateway.yaml`: each
  microservice's Service and Deployment.
- `60-ingress.yaml`: Nginx Ingress for the gateway.

The `10-database.yaml` PostgreSQL deployment is intended only for local
MicroK8s. Do not apply it to EKS; EKS uses the production database URL in
`SPRING_DATASOURCE_URL`.

For EKS, configure these GitHub Actions secrets:

- `AWS_REGION`
- `AWS_DEPLOY_ROLE_ARN`
- `EKS_CLUSTER_NAME`
- `JWT_SECRET`
- `INTERNAL_SERVICE_SECRET`
- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`

Also configure repository variables `PRODUCT_URL` and `EXCHANGE_URL`. Run the
manual `Deploy to AWS EKS` workflow. It deploys the application manifests,
skips the local PostgreSQL deployment, and patches the ConfigMap with the
external service URLs. Use an AWS Load Balancer Controller or Nginx Ingress
Controller for the `Ingress` resource.

### Redis options

Local MicroK8s includes the single-replica `05-redis.yaml` deployment and
advertises `redis://redis:6379` through `CACHE_REDIS_URL`. This is suitable for
development and cache experiments only; it has no high-availability guarantee.

For EKS, set the `REDIS_URL` repository variable to a reachable managed or
external Redis endpoint, such as Redis Cloud or Amazon ElastiCache. The EKS
workflow patches `CACHE_REDIS_URL` with that value and does not deploy the
single-replica local Redis manifest.

The current platform repository only wires the endpoint into service
configuration. Each service must implement and test cache-aside behavior,
TTL, invalidation and stampede protection before Redis provides a functional
performance mitigation.

The Exchange provider URL and credentials are configuration for the external
Exchange service itself. Configure them in that service's deployment or secret
manager; they are not stored in this platform repository.

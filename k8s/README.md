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
microk8s kubectl apply -f k8s/
```

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

The Exchange provider URL and credentials are configuration for the external
Exchange service itself. Configure them in that service's deployment or secret
manager; they are not stored in this platform repository.

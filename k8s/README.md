# Kubernetes deployment

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
microk8s kubectl apply -f k8s/
```

The Kubernetes resources are split by responsibility:

- `00-namespace-config.yaml`: namespace and shared service configuration.
- `10-database.yaml`: PostgreSQL Service and Deployment.
- `20-account.yaml`, `30-auth.yaml`, `40-order.yaml`, and `50-gateway.yaml`: each
  microservice's Service and Deployment.
- `60-ingress.yaml`: Nginx Ingress for the gateway.

For EKS, configure the GitHub Actions secrets listed in `.env.example` and
run the manual `Deploy to AWS EKS` workflow. Set
`SPRING_DATASOURCE_URL` to an Amazon RDS PostgreSQL endpoint; the in-cluster
PostgreSQL deployment is intended for local MicroK8s only. Use an AWS Load
Balancer Controller or Nginx Ingress Controller for the `Ingress` resource.

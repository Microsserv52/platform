# Kubernetes deployment

The manifest targets MicroK8s with the Nginx ingress addon and can be adapted
to AWS EKS by replacing local image names with registry references.

Create the required runtime secret without committing credentials:

```bash
microk8s kubectl create namespace platform
microk8s kubectl -n platform create secret generic platform-secrets \
  --from-literal=JWT_SECRET="$(openssl rand -base64 48)" \
  --from-literal=INTERNAL_SERVICE_SECRET="$(openssl rand -base64 32)" \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)"
microk8s kubectl apply -f k8s/platform.yaml
```

For EKS, push the four images to ECR, change the image names in
`platform.yaml`, and use an AWS Load Balancer Controller or Nginx Ingress
Controller for the `Ingress` resource.

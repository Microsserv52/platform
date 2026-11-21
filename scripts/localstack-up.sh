#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

require_terraform
require_cmd docker
require_cmd aws
require_cmd jq
require_cmd curl

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"
export AWS_ENDPOINT_URL_S3="$LOCALSTACK_ENDPOINT"

echo "starting LocalStack"
docker compose -f "$ROOT_DIR/compose.localstack.yml" up -d

echo "waiting for LocalStack"
for _ in $(seq 1 60); do
  if curl -fsS "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
curl -fsS "$LOCALSTACK_ENDPOINT/_localstack/health" >/dev/null || {
  echo "error: LocalStack did not become healthy" >&2
  exit 1
}

terraform -chdir="$TF_LOCALSTACK" init -input=false
terraform -chdir="$TF_LOCALSTACK" apply -auto-approve

REGISTRY="$(tf_out "$TF_LOCALSTACK" registry)"
CLUSTER_NAME="$(tf_out "$TF_LOCALSTACK" eks_cluster_name)"
RDS_ENDPOINT="$(tf_out "$TF_LOCALSTACK" rds_endpoint)"
RDS_PORT="$(tf_out "$TF_LOCALSTACK" rds_port)"
RDS_DB_NAME="$(tf_out "$TF_LOCALSTACK" rds_db_name)"
RDS_USERNAME="$(tf_out "$TF_LOCALSTACK" rds_username)"
RDS_PASSWORD="$(tf_out "$TF_LOCALSTACK" rds_password)"
REDIS_ENDPOINT="$(tf_out "$TF_LOCALSTACK" redis_endpoint)"
REDIS_PORT="$(tf_out "$TF_LOCALSTACK" redis_port)"
MEDIA_BUCKET="$(tf_out "$TF_LOCALSTACK" media_bucket | jq -r '.bucket')"
CLOUDFRONT_DOMAIN="$(tf_out "$TF_LOCALSTACK" cloudfront_domain_name)"
TAG="${TAG:-$(git -C "$ROOT_DIR" rev-parse --short HEAD)}"

LOCALSTACK_NETWORK="${LOCALSTACK_NETWORK:-platform-localstack_default}"
HOST_GATEWAY="${LOCALSTACK_HOST_GATEWAY:-$(
  docker network inspect "$LOCALSTACK_NETWORK" --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null \
    || docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'
)}"
RDS_HOST="$RDS_ENDPOINT"
REDIS_HOST="$REDIS_ENDPOINT"
if [[ "$RDS_ENDPOINT" == *localhost* || "$RDS_ENDPOINT" == "127.0.0.1" ]]; then RDS_HOST="$HOST_GATEWAY"; fi
if [[ "$REDIS_ENDPOINT" == *localhost* || "$REDIS_ENDPOINT" == "127.0.0.1" ]]; then REDIS_HOST="$HOST_GATEWAY"; fi

aws --endpoint-url "$LOCALSTACK_ENDPOINT" ecr get-login-password \
  | docker login --username AWS --password-stdin "$REGISTRY"

export REGISTRY
PUSH=true "$ROOT_DIR/scripts/build-and-push-images.sh"
docker build -t microsserv52-exchange-provider-mock:local "$ROOT_DIR/mocks/exchange-provider"

aws --endpoint-url "$LOCALSTACK_ENDPOINT" eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

export SPRING_DATASOURCE_URL="jdbc:postgresql://$RDS_HOST:$RDS_PORT/$RDS_DB_NAME"
export SPRING_DATASOURCE_USERNAME="$RDS_USERNAME"
export SPRING_DATASOURCE_PASSWORD="$RDS_PASSWORD"
export CACHE_REDIS_URL="redis://$REDIS_HOST:$REDIS_PORT"
"$ROOT_DIR/scripts/create-platform-secrets.sh"

kubectl apply -k "$ROOT_DIR/k8s/overlays/localstack"

kubectl -n "$NAMESPACE" patch configmap platform-config --type merge -p "$(jq -n \
  --arg mediaBucket "$MEDIA_BUCKET" \
  --arg region "$AWS_REGION" \
  --arg mediaOrigin "http://$CLOUDFRONT_DOMAIN" \
  --arg endpoint "http://$HOST_GATEWAY:4566" \
  '{data: {PRODUCT_IMAGE_S3_BUCKET: $mediaBucket, PRODUCT_IMAGE_S3_REGION: $region, PRODUCT_IMAGE_S3_MEDIA_ORIGIN: $mediaOrigin, AWS_ENDPOINT_URL: $endpoint, AWS_ENDPOINT_URL_S3: $endpoint, AWS_ACCESS_KEY_ID: "test", AWS_SECRET_ACCESS_KEY: "test"}}')"

for svc in account auth gateway order product exchange; do
  kubectl -n "$NAMESPACE" set image "deployment/$svc" "$svc=$REGISTRY/$svc:$TAG"
  kubectl -n "$NAMESPACE" rollout restart "deployment/$svc"
done
kubectl -n "$NAMESPACE" rollout status deployment/gateway --timeout=300s

echo
echo "LocalStack rehearsal is up"
echo "  endpoint:   $LOCALSTACK_ENDPOINT"
echo "  frontend:   http://$CLOUDFRONT_DOMAIN"
echo "  api:        kubectl -n $NAMESPACE port-forward svc/gateway 8080:8080"
echo "  rds:        $RDS_HOST:$RDS_PORT (pods); $RDS_ENDPOINT:$RDS_PORT (host)"
echo "  redis:      $REDIS_HOST:$REDIS_PORT (pods); $REDIS_ENDPOINT:$REDIS_PORT (host)"

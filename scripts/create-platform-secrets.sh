#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${SPRING_DATASOURCE_URL:?SPRING_DATASOURCE_URL is required}"
: "${SPRING_DATASOURCE_USERNAME:?SPRING_DATASOURCE_USERNAME is required}"
: "${SPRING_DATASOURCE_PASSWORD:?SPRING_DATASOURCE_PASSWORD is required}"
: "${CACHE_REDIS_URL:?CACHE_REDIS_URL is required}"

JWT_SECRET="${JWT_SECRET:-$(random_secret 48)}"
INTERNAL_SERVICE_SECRET="${INTERNAL_SERVICE_SECRET:-$(random_secret 32)}"

SECRET_ARGS=(
  --from-literal=JWT_SECRET="$JWT_SECRET"
  --from-literal=INTERNAL_SERVICE_SECRET="$INTERNAL_SERVICE_SECRET"
  --from-literal=CACHE_REDIS_URL="$CACHE_REDIS_URL"
  --from-literal=SPRING_DATASOURCE_URL="$SPRING_DATASOURCE_URL"
  --from-literal=SPRING_DATASOURCE_USERNAME="$SPRING_DATASOURCE_USERNAME"
  --from-literal=SPRING_DATASOURCE_PASSWORD="$SPRING_DATASOURCE_PASSWORD"
)

if [[ -n "${EXCHANGE_PROVIDER_API_KEY:-}" ]]; then
  SECRET_ARGS+=(--from-literal=EXCHANGE_PROVIDER_API_KEY="$EXCHANGE_PROVIDER_API_KEY")
fi

ensure_namespace
kubectl -n "$NAMESPACE" create secret generic platform-secrets \
  "${SECRET_ARGS[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

if [[ -n "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
  kubectl -n "$NAMESPACE" create secret generic grafana-admin \
    --from-literal="admin-user=${GRAFANA_ADMIN_USER:-admin}" \
    --from-literal="admin-password=${GRAFANA_ADMIN_PASSWORD}" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "grafana-admin applied in namespace $NAMESPACE"
fi

echo "platform-secrets applied in namespace $NAMESPACE"

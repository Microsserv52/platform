#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${SPRING_DATASOURCE_URL:?SPRING_DATASOURCE_URL is required}"
: "${SPRING_DATASOURCE_USERNAME:?SPRING_DATASOURCE_USERNAME is required}"
: "${SPRING_DATASOURCE_PASSWORD:?SPRING_DATASOURCE_PASSWORD is required}"
: "${CACHE_REDIS_URL:?CACHE_REDIS_URL is required}"

ensure_namespace

secret_value() {
  local key="$1"
  kubectl -n "$NAMESPACE" get secret platform-secrets \
    -o "jsonpath={.data.${key}}" 2>/dev/null | base64 --decode
}

if [[ -z "${JWT_SECRET:-}" ]]; then
  JWT_SECRET="$(secret_value JWT_SECRET)"
fi
if [[ -z "${INTERNAL_SERVICE_SECRET:-}" ]]; then
  INTERNAL_SERVICE_SECRET="$(secret_value INTERNAL_SERVICE_SECRET)"
fi
if [[ -z "$JWT_SECRET" || -z "$INTERNAL_SERVICE_SECRET" ]]; then
  cat >&2 <<'EOF'
error: JWT_SECRET and INTERNAL_SERVICE_SECRET must be supplied through the
environment or an existing platform-secrets Secret; refusing to generate new
values because that would invalidate sessions and internal authentication.
EOF
  exit 1
fi

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

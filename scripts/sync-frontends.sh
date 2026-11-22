#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

: "${FRONTEND_BUCKETS:?FRONTEND_BUCKETS JSON is required}"

API_BASE_URL="${NEXT_PUBLIC_API_BASE_URL:-/api}"
DISPLAY_TIME_ZONE="${NEXT_PUBLIC_DISPLAY_TIME_ZONE:-UTC}"
APP_ENV="${NEXT_PUBLIC_APP_ENV:-production}"
APP_VERSION="${NEXT_PUBLIC_APP_VERSION:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"
ENABLE_UPLOADS="${NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS:-true}"
UPLOAD_ORIGINS="${NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS:-}"

export NEXT_PUBLIC_API_BASE_URL="$API_BASE_URL"
export NEXT_PUBLIC_DISPLAY_TIME_ZONE="$DISPLAY_TIME_ZONE"
export NEXT_PUBLIC_APP_ENV="$APP_ENV"
export NEXT_PUBLIC_APP_VERSION="$APP_VERSION"
export NEXT_PUBLIC_ENABLE_TELEMETRY="${NEXT_PUBLIC_ENABLE_TELEMETRY:-false}"
export NEXT_PUBLIC_FARO_URL="${NEXT_PUBLIC_FARO_URL:-}"
export NEXT_PUBLIC_UMAMI_SCRIPT_URL="${NEXT_PUBLIC_UMAMI_SCRIPT_URL:-}"
export NEXT_PUBLIC_UMAMI_WEBSITE_ID="${NEXT_PUBLIC_UMAMI_WEBSITE_ID:-}"
export NEXT_PUBLIC_UMAMI_DOMAINS="${NEXT_PUBLIC_UMAMI_DOMAINS:-}"
export NEXT_PUBLIC_GRAFANA_DASHBOARD_URL="${NEXT_PUBLIC_GRAFANA_DASHBOARD_URL:-}"
export NEXT_PUBLIC_UMAMI_DASHBOARD_URL="${NEXT_PUBLIC_UMAMI_DASHBOARD_URL:-}"
export NEXT_PUBLIC_ENABLE_PRODUCT_IMAGE_UPLOADS="$ENABLE_UPLOADS"
export NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS="$UPLOAD_ORIGINS"

AWS_ARGS=()
if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
  AWS_ARGS+=(--endpoint-url "$AWS_ENDPOINT_URL")
fi

for site in landing store admin; do
  bucket="$(jq -r --arg site "$site" '.[$site].bucket' <<<"$FRONTEND_BUCKETS")"
  dir="$ROOT_DIR/web/$site"

  echo "building $site"
  (cd "$dir" && npm ci --no-audit --no-fund && npm run build)

  echo "uploading $site to s3://$bucket"
  aws "${AWS_ARGS[@]}" s3 sync "$dir/out" "s3://$bucket" --delete
done

if [[ -n "${CLOUDFRONT_DISTRIBUTION_ID:-}" ]]; then
  echo "invalidating CloudFront"
  aws "${AWS_ARGS[@]}" cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
    --paths "/*" "/store/*" "/admin/*" "/media/*" >/dev/null
fi

echo "frontends deployed"

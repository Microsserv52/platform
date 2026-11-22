#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

SKIP_TERRAFORM=false
SKIP_IMAGES=false
SKIP_FRONTENDS=true
SKIP_ADDONS=false
LOGIN_ONLY=false
AUTO_APPROVE="-auto-approve"

for arg in "$@"; do
  case "$arg" in
    --skip-terraform) SKIP_TERRAFORM=true ;;
    --skip-images) SKIP_IMAGES=true ;;
    --skip-addons) SKIP_ADDONS=true ;;
    --frontends) SKIP_FRONTENDS=false ;;
    --no-auto-approve) AUTO_APPROVE="" ;;
    --login)
      if [[ -n "${AWS_PROFILE:-}" ]]; then
        aws sso login --profile "$AWS_PROFILE"
        LOGIN_ONLY=true
      else
        echo "set AWS_PROFILE to use --login with IAM Identity Center" >&2
        exit 1
      fi
      ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [[ "$LOGIN_ONLY" == "true" ]]; then
  echo "AWS login complete; re-run without --login to deploy."
  exit 0
fi

require_terraform
require_cmd aws
require_cmd docker
require_cmd jq

# Guard against a .env that still contains LocalStack dummy credentials.
if [[ "${AWS_ENDPOINT_URL:-}" == *localhost:4566* || "${AWS_ACCESS_KEY_ID:-}" == "test" ]]; then
  echo "warning: ignoring LocalStack AWS endpoint/credentials from .env" >&2
  unset AWS_ENDPOINT_URL AWS_ENDPOINT_URL_S3 AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
fi

aws sts get-caller-identity >/dev/null || {
  cat >&2 <<'EOF'
error: no AWS credentials found.
Use one of:
  aws sso login --profile platform && export AWS_PROFILE=platform
  aws configure --profile platform && export AWS_PROFILE=platform
then re-run scripts/deploy-aws.sh
EOF
  exit 1
}
AWS_REGION="${AWS_REGION:-$(aws configure get region || true)}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION

EXCHANGE_PROVIDER_URL_FOR_DEPLOY="${DEPLOY_EXCHANGE_PROVIDER_URL:-}"
if [[ -z "$EXCHANGE_PROVIDER_URL_FOR_DEPLOY" \
  && -n "${EXCHANGE_PROVIDER_URL:-}" \
  && "${EXCHANGE_PROVIDER_URL}" != *exchange-provider-mock* ]]; then
  EXCHANGE_PROVIDER_URL_FOR_DEPLOY="$EXCHANGE_PROVIDER_URL"
fi
if [[ -z "$EXCHANGE_PROVIDER_URL_FOR_DEPLOY" ]]; then
  echo "error: set DEPLOY_EXCHANGE_PROVIDER_URL" >&2
  echo "       (or a non-mock EXCHANGE_PROVIDER_URL; the Compose mock is not deployed to AWS)" >&2
  exit 1
fi
export DEPLOY_EXCHANGE_PROVIDER_URL="$EXCHANGE_PROVIDER_URL_FOR_DEPLOY"

TF_ARGS=()

if [[ "$SKIP_TERRAFORM" == "false" ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  TF_STATE_BUCKET="${TF_STATE_BUCKET:-${TF_VAR_project:-platform}-tfstate-$ACCOUNT_ID}"
  TF_STATE_KEY="${TF_STATE_KEY:-platform/aws.tfstate}"
  export TF_STATE_BUCKET TF_STATE_KEY
  "$ROOT_DIR/scripts/bootstrap-tf-state.sh"
  TF_ARGS+=(
    -backend-config="bucket=$TF_STATE_BUCKET"
    -backend-config="key=$TF_STATE_KEY"
    -backend-config="region=$AWS_REGION"
  )

  terraform -chdir="$TF_AWS" init -reconfigure "${TF_ARGS[@]}"

  export TF_VAR_aws_region="$AWS_REGION"

  terraform -chdir="$TF_AWS" apply $AUTO_APPROVE
fi

REGISTRY="$(tf_out "$TF_AWS" registry)"
RDS_ENDPOINT="$(tf_out "$TF_AWS" rds_endpoint)"
RDS_PORT="$(tf_out "$TF_AWS" rds_port)"
RDS_DB_NAME="$(tf_out "$TF_AWS" rds_db_name)"
RDS_USERNAME="$(tf_out "$TF_AWS" rds_username)"
RDS_PASSWORD="$(tf_out "$TF_AWS" rds_password)"
REDIS_ENDPOINT="$(tf_out "$TF_AWS" redis_endpoint)"
REDIS_PORT="$(tf_out "$TF_AWS" redis_port)"
CLUSTER_NAME="$(tf_out "$TF_AWS" eks_cluster_name)"
CLUSTER_AUTOSCALER_ROLE_ARN="$(tf_out "$TF_AWS" cluster_autoscaler_role_arn)"
IRSA_ROLE_ARN="$(tf_out "$TF_AWS" product_irsa_role_arn)"
MEDIA_BUCKET="$(tf_out_json "$TF_AWS" media_bucket | jq -r '.bucket')"
FRONTEND_BUCKETS="$(tf_out_json "$TF_AWS" frontend_buckets)"
DISTRIBUTION_ID="$(tf_out "$TF_AWS" cloudfront_distribution_id)"
CLOUDFRONT_DOMAIN="$(tf_out "$TF_AWS" cloudfront_domain_name)"
export REGISTRY TAG="${TAG:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
ensure_namespace

if [[ "$SKIP_ADDONS" == "false" ]]; then
  if [[ -z "$CLUSTER_AUTOSCALER_ROLE_ARN" ]]; then
    echo "warning: cluster_autoscaler_role_arn is empty; skipping addons" >&2
  else
    EKS_CLUSTER_NAME="$CLUSTER_NAME" \
    CLUSTER_AUTOSCALER_ROLE_ARN="$CLUSTER_AUTOSCALER_ROLE_ARN" \
      "$ROOT_DIR/scripts/install-aws-addons.sh"
  fi
fi

export SPRING_DATASOURCE_URL="jdbc:postgresql://$RDS_ENDPOINT:$RDS_PORT/$RDS_DB_NAME"
export SPRING_DATASOURCE_USERNAME="$RDS_USERNAME"
export SPRING_DATASOURCE_PASSWORD="$RDS_PASSWORD"
export CACHE_REDIS_URL="redis://$REDIS_ENDPOINT:$REDIS_PORT"

EXCHANGE_PROVIDER_REQUIRES_API_KEY="${DEPLOY_EXCHANGE_PROVIDER_REQUIRES_API_KEY:-false}"
if [[ -n "${DEPLOY_EXCHANGE_PROVIDER_API_KEY:-}" ]]; then
  export EXCHANGE_PROVIDER_API_KEY="$DEPLOY_EXCHANGE_PROVIDER_API_KEY"
else
  unset EXCHANGE_PROVIDER_API_KEY
fi
if [[ "$EXCHANGE_PROVIDER_REQUIRES_API_KEY" == "true" && -z "${EXCHANGE_PROVIDER_API_KEY:-}" ]]; then
  echo "error: the Exchange provider requires an API key; set DEPLOY_EXCHANGE_PROVIDER_API_KEY" >&2
  exit 1
fi
export EXCHANGE_PROVIDER_REQUIRES_API_KEY

"$ROOT_DIR/scripts/create-platform-secrets.sh"

if [[ "$SKIP_IMAGES" == "false" ]]; then
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"
  PUSH=true "$ROOT_DIR/scripts/build-and-push-images.sh"
fi

kubectl apply -k "$ROOT_DIR/k8s/overlays/aws"

CONFIG_PATCH="$(jq -n \
  --arg mediaBucket "$MEDIA_BUCKET" \
  --arg region "$AWS_REGION" \
  --arg mediaOrigin "https://$CLOUDFRONT_DOMAIN" \
  --arg exchangeUrl "$DEPLOY_EXCHANGE_PROVIDER_URL" \
  --arg requiresKey "$EXCHANGE_PROVIDER_REQUIRES_API_KEY" \
  '{data: {PRODUCT_IMAGE_S3_BUCKET: $mediaBucket, PRODUCT_IMAGE_S3_REGION: $region, PRODUCT_IMAGE_S3_MEDIA_ORIGIN: $mediaOrigin, EXCHANGE_PROVIDER_URL: $exchangeUrl, EXCHANGE_PROVIDER_REQUIRES_API_KEY: $requiresKey}}')"

kubectl -n "$NAMESPACE" patch configmap platform-config --type merge -p "$CONFIG_PATCH"

if [[ -n "$IRSA_ROLE_ARN" ]]; then
  kubectl -n "$NAMESPACE" annotate serviceaccount product \
    "eks.amazonaws.com/role-arn=$IRSA_ROLE_ARN" --overwrite
fi

for svc in account auth gateway order product exchange; do
  kubectl -n "$NAMESPACE" set image "deployment/$svc" "$svc=$REGISTRY/$svc:$TAG"
  kubectl -n "$NAMESPACE" rollout restart "deployment/$svc"
  kubectl -n "$NAMESPACE" rollout status "deployment/$svc" --timeout=300s
done

if [[ "$SKIP_FRONTENDS" == "false" ]]; then
  if [[ -z "${TF_VAR_cloudfront_api_origin_domain:-}" && "${NEXT_PUBLIC_API_BASE_URL:-/api}" == "/api" ]]; then
    echo "warning: /api is not routed through CloudFront; set TF_VAR_cloudfront_api_origin_domain" >&2
    echo "         or NEXT_PUBLIC_API_BASE_URL to the reachable API URL before building frontends" >&2
  fi
  if [[ -z "${NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS:-}" && -n "$MEDIA_BUCKET" ]]; then
    export NEXT_PUBLIC_IMAGE_UPLOAD_ORIGINS="https://$MEDIA_BUCKET.s3.$AWS_REGION.amazonaws.com"
  fi
  export FRONTEND_BUCKETS CLOUDFRONT_DISTRIBUTION_ID="$DISTRIBUTION_ID"
  "$ROOT_DIR/scripts/sync-frontends.sh"
fi

echo
echo "deployment complete"
echo "  api:        kubectl -n $NAMESPACE port-forward svc/gateway 8080:8080"
if [[ -n "$CLOUDFRONT_DOMAIN" ]]; then
  echo "  frontend:   https://$CLOUDFRONT_DOMAIN"
fi

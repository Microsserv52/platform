#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

: "${REGISTRY:?REGISTRY is required (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com)}"
TAG="${TAG:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"
PUSH="${PUSH:-true}"

build() {
  local name="$1" context="$2" dockerfile="${3:-Dockerfile}"
  echo "building $REGISTRY/$name:$TAG"
  docker build -t "$REGISTRY/$name:$TAG" -f "$context/$dockerfile" "$context"
  if [[ "$PUSH" == "true" ]]; then
    docker push "$REGISTRY/$name:$TAG"
  fi
}

build account "$ROOT_DIR/api/account"
build auth    "$ROOT_DIR/api/auth"
build gateway "$ROOT_DIR/api/gateway"
build order   "$ROOT_DIR/api" "order-service/Dockerfile"
build product "$ROOT_DIR/api/product"
build exchange "$ROOT_DIR/api/exchange"

echo "images ready with tag $TAG"

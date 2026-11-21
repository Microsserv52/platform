#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

if terraform -chdir="$TF_LOCALSTACK" output -json >/dev/null 2>&1; then
  terraform -chdir="$TF_LOCALSTACK" destroy -auto-approve
fi

docker compose -f "$ROOT_DIR/compose.localstack.yml" down -v
echo "LocalStack rehearsal destroyed"

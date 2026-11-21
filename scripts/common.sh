#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TF_LOCALSTACK="$ROOT_DIR/terraform/environments/localstack"
export TF_AWS="$ROOT_DIR/terraform/environments/aws"
NAMESPACE="${NAMESPACE:-platform}"

load_env_file() {
  local file="${1:-$ROOT_DIR/.env}"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command '$1' is not installed" >&2
    exit 1
  }
}

require_terraform() {
  require_cmd terraform
  require_cmd kubectl
}

tf_out() {
  terraform -chdir="$1" output -raw "$2"
}

tf_out_json() {
  terraform -chdir="$1" output -json "$2"
}

random_secret() {
  openssl rand -base64 "${1:-48}" | tr -d '\n'
}

ensure_namespace() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

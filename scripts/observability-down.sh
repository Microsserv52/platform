#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if [[ "${1:-}" == "--volumes" ]]; then
  docker compose -f "$ROOT_DIR/compose.yml" -f "$ROOT_DIR/compose.observability.yml" \
    --profile observability down -v
  echo "observability stack and local volumes removed"
else
  docker compose -f "$ROOT_DIR/compose.yml" -f "$ROOT_DIR/compose.observability.yml" \
    --profile observability down
  echo "observability stack stopped; volumes retained"
fi

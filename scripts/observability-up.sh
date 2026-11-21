#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

require_cmd docker
require_cmd curl

OBS_COMPOSE=(-f "$ROOT_DIR/compose.yml" -f "$ROOT_DIR/compose.observability.yml")
PROFILE=(--profile observability)

"$ROOT_DIR/scripts/fetch-otel-agent.sh"

docker compose "${OBS_COMPOSE[@]}" "${PROFILE[@]}" up -d

wait_for() {
  local name="$1" url="$2"
  for _ in $(seq 1 90); do
    if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      echo "ready: $name"
      return 0
    fi
    sleep 2
  done
  echo "error: $name did not become ready at $url" >&2
  return 1
}

wait_for prometheus http://127.0.0.1:9090/-/ready
wait_for mimir http://127.0.0.1:9009/ready
wait_for loki http://127.0.0.1:3100/ready
wait_for tempo http://127.0.0.1:3200/ready
wait_for pyroscope http://127.0.0.1:4040/ready
wait_for grafana http://127.0.0.1:3000/api/health
wait_for alloy http://127.0.0.1:12345/-/ready

cat <<EOF
Observability stack is up (localhost only)

  Grafana      http://localhost:3000   (${GRAFANA_ADMIN_USER:-admin})
  Prometheus   http://localhost:9090
  Mimir        http://localhost:9009
  Loki         http://localhost:3100
  Tempo        http://localhost:3200
  Pyroscope    http://localhost:4040
  Alloy        http://localhost:12345
  Faro ingest  http://localhost:12347/collect

Enable browser telemetry for the local frontends:
  NEXT_PUBLIC_ENABLE_TELEMETRY=true
  NEXT_PUBLIC_FARO_URL=http://localhost:12347/collect
then rebuild landing/store/admin.

Stop without deleting data:
  docker compose -f compose.yml -f compose.observability.yml --profile observability down
EOF

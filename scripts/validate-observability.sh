#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd docker

ROOT="$ROOT_DIR"
PROM_IMAGE="${PROM_IMAGE:-prom/prometheus:v3.16.0}"
BLACKBOX_IMAGE="${BLACKBOX_IMAGE:-prom/blackbox-exporter:v0.29.1}"

echo "checking Prometheus configuration"
docker run --rm --entrypoint promtool \
  -v "$ROOT/observability/prometheus:/etc/prometheus:ro" \
  "$PROM_IMAGE" \
  check config /etc/prometheus/prometheus.yml

echo "checking Prometheus rules"
docker run --rm --entrypoint promtool \
  -v "$ROOT/observability/prometheus/rules:/etc/prometheus/rules:ro" \
  "$PROM_IMAGE" \
  check rules /etc/prometheus/rules/sli.yml

echo "checking blackbox configuration"
docker run --rm \
  -v "$ROOT/observability/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml:ro" \
  "$BLACKBOX_IMAGE" \
  --config.check --config.file=/etc/blackbox_exporter/config.yml

echo "checking Alloy configuration"
docker run --rm \
  -v "$ROOT/observability/alloy:/etc/alloy:ro" \
  grafana/alloy:v1.22.0 validate /etc/alloy/config.alloy
docker run --rm \
  -v "$ROOT/observability/alloy:/etc/alloy:ro" \
  grafana/alloy:v1.22.0 validate /etc/alloy/config.cloud.alloy

echo "checking dashboard JSON"
python3 - <<'PY'
import json
import pathlib
import sys

root = pathlib.Path("observability/grafana/dashboards")
errors = []
for path in sorted(root.glob("*.json")):
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        errors.append(f"{path}: {error}")
        continue
    for key in ("uid", "title", "panels"):
        if key not in data:
            errors.append(f"{path}: missing {key}")
    uids = [panel.get("id") for panel in data.get("panels", [])]
    if len(uids) != len(set(uids)):
        errors.append(f"{path}: duplicate panel ids")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"validated {len(list(root.glob('*.json')))} dashboards")
PY

if find "$ROOT/observability/grafana/provisioning" -name '*.example*' | grep -q .; then
  echo "error: example files must live outside provisioning/" >&2
  exit 1
fi

echo "checking provisioning YAML"
python3 - <<'PY'
import pathlib
import sys
import yaml

root = pathlib.Path("observability/grafana/provisioning")
errors = []
for path in sorted(root.rglob("*.yml")):
    if path.name.endswith(".example.yml"):
        continue
    try:
        data = yaml.safe_load(path.read_text())
    except yaml.YAMLError as error:
        errors.append(f"{path}: {error}")
        continue
    if not isinstance(data, dict):
        errors.append(f"{path}: expected a mapping")
        continue
    if path.parent.name == "alerting" and "groups" in data:
        for group in data["groups"]:
            for rule in group.get("rules", []):
                for key in ("uid", "title", "condition", "data", "for"):
                    if key not in rule:
                        errors.append(f"{path}: rule {rule.get('uid')} missing {key}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("provisioning YAML is valid")
PY

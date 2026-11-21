#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd curl
require_cmd sha256sum

VERSION="${OTEL_JAVAAGENT_VERSION:-v2.34.0}"
CACHE_DIR="${OTEL_JAVAAGENT_CACHE:-$ROOT_DIR/.cache/otel}"
JAR="$CACHE_DIR/opentelemetry-javaagent.jar"
BASE="https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$VERSION"

mkdir -p "$CACHE_DIR"

if [[ -f "$JAR" && -f "$CACHE_DIR/checksums.txt" ]]; then
  expected="$(awk -v name="opentelemetry-javaagent.jar" '$2 == name {print $1}' "$CACHE_DIR/checksums.txt" | head -1)"
  if [[ -n "$expected" ]] && echo "$expected  $JAR" | sha256sum --check --status 2>/dev/null; then
    echo "OpenTelemetry Java agent already present: $JAR"
    exit 0
  fi
fi

echo "downloading OpenTelemetry Java agent $VERSION"
curl -fsSL "$BASE/checksums.txt" -o "$CACHE_DIR/checksums.txt"
curl -fsSL "$BASE/opentelemetry-javaagent.jar" -o "$JAR.tmp"

expected="$(awk -v name="opentelemetry-javaagent.jar" '$2 == name {print $1}' "$CACHE_DIR/checksums.txt" | head -1)"
if [[ -z "$expected" ]]; then
  echo "error: checksum for opentelemetry-javaagent.jar not found" >&2
  exit 1
fi
echo "$expected  $JAR.tmp" | sha256sum --check --status || {
  echo "error: OpenTelemetry Java agent checksum mismatch" >&2
  exit 1
}
mv "$JAR.tmp" "$JAR"
echo "OpenTelemetry Java agent ready: $JAR"

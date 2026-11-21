#!/bin/sh
set -eu

# Optional OpenTelemetry Java agent. The file is mounted read-only at
# /otel/opentelemetry-javaagent.jar by Compose or an init container. When the
# file is absent the service still starts without tracing.
if [ -f /otel/opentelemetry-javaagent.jar ]; then
  JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -javaagent:/otel/opentelemetry-javaagent.jar"
  export JAVA_TOOL_OPTIONS
fi

exec java "$@"

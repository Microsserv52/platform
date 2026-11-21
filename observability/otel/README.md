# OpenTelemetry for platform services

The Java services are instrumented without editing their repositories. The
agent is injected by Compose and Kubernetes configuration:

- **Compose:** `compose.observability.yml` mounts the agent and uses
  `observability/otel/run-java.sh` as the entrypoint.
- **Kubernetes:** `k8s/base/otel-instrumentation.yaml` adds an init container,
  mounts the agent into the app container, and sets `JAVA_TOOL_OPTIONS`.
- **Metrics:** stay on the existing Micrometer `/actuator/prometheus` endpoints.
- **Traces:** export OTLP gRPC to Alloy, then Tempo.
- **Logs:** stay on structured stdout and Alloy/Loki.

## Local

```bash
scripts/fetch-otel-agent.sh
scripts/observability-up.sh
```

The download is pinned and checksum-verified. The jar lives in `.cache/otel/`
and is not committed.

| Variable | Local value |
| --- | --- |
| `OTEL_SERVICE_NAME` | `gateway`, `auth`, `account`, `order`, `product` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://alloy:4317` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` |
| `OTEL_TRACES_EXPORTER` | `otlp` |
| `OTEL_METRICS_EXPORTER` | `none` |
| `OTEL_LOGS_EXPORTER` | `none` |
| `OTEL_TRACES_SAMPLER` | `parentbased_traceidratio` |
| `OTEL_TRACES_SAMPLER_ARG` | `0.2` |

## Kubernetes

The init container downloads the same agent version. The app container gets:

```text
JAVA_TOOL_OPTIONS=-javaagent:/otel/opentelemetry-javaagent.jar
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc.cluster.local:4317
```

The agent is mounted read-only from an `emptyDir`. No AWS credential, token or
service source change is required for the Java services.

## Exchange

Exchange is Python and currently exposes `/metrics` and structured logs. Adding
OTLP traces requires a change in its own repository, for example:

```text
opentelemetry-distro
opentelemetry-exporter-otlp-proto-grpc
opentelemetry-instrumentation-fastapi
```

and an entrypoint that runs `opentelemetry-instrument` with
`OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc.cluster.local:4317`.
That change is intentionally left to the service owner; this repository does not
modify `api/`.

## Verify

```bash
curl -fsS http://localhost:3200/api/search?limit=10
curl -fsS -u admin:admin 'http://localhost:3000/api/datasources'
```

Open **Grafana → Explore → Tempo** and search for a `service.name` such as
`gateway`, `order` or `product`.

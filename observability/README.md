# Observability stack

Configuration-as-code for metrics, logs, traces, profiles, synthetic checks and
alerts. The same files run on Docker Compose, LocalStack EKS and AWS EKS.

## Quick start

```bash
scripts/observability-up.sh
```

The wrapper downloads the pinned OpenTelemetry Java agent, starts Prometheus,
Mimir, Loki, Tempo, Pyroscope, Alloy, blackbox and Grafana, and waits for each
readiness endpoint.

Or:

```bash
scripts/observability-up.sh
scripts/validate-observability.sh
```

| UI | URL |
| --- | --- |
| Grafana | <http://localhost:3000> |
| Prometheus | <http://localhost:9090> |
| Mimir | <http://localhost:9009> |
| Loki | <http://localhost:3100> |
| Tempo | <http://localhost:3200> |
| Pyroscope | <http://localhost:4040> |
| Alloy | <http://localhost:12345> |
| Faro ingest | <http://localhost:8080/faro/collect> (nginx → Alloy) |

## Layout

```text
observability/
  alloy/config.alloy          # local logs, OTLP and Faro
  alloy/config.alloy          # local logs, OTLP and Faro
  alloy/config.k8s.alloy      # EKS pod logs, OTLP and Faro
  alloy/config.cloud.alloy    # optional Grafana Cloud remote write
  blackbox/blackbox.yml       # synthetic HTTP modules
  grafana/dashboards/         # five provisioned dashboards
  grafana/provisioning/       # local datasources, dashboards, alerting
  helm/values.yaml            # kube-prometheus-stack, AWS
  helm/values.localstack.yaml # local-path storage and toleration
  loki/loki.yaml
  mimir/mimir.yaml
  otel/run-java.sh            # optional Java agent entrypoint
  prometheus/prometheus.yml
  prometheus/rules/sli.yml
  pyroscope/pyroscope.yaml
  tempo/tempo.yaml
```

## AWS and LocalStack

```bash
# AWS EKS, after the prerequisites in docs/operations/grafana-aws.md
scripts/install-observability.sh

# LocalStack EKS rehearsal
scripts/install-observability.sh --localstack
```

The EKS path installs Prometheus, Mimir, Loki, Tempo, Pyroscope, Alloy,
blackbox and Grafana. Prometheus remote-writes to Mimir; Alloy handles OTLP
traces, Faro and pod logs. Grafana stays ClusterIP. Publishing it behind Cognito
requires a custom domain and ACM certificate; see
[Grafana on AWS](../docs/operations/grafana-aws.md).

## OpenTelemetry

`scripts/fetch-otel-agent.sh` downloads the Java agent and verifies the release
checksum. Compose mounts it through `observability/otel/run-java.sh`; Kubernetes
uses an init container and `JAVA_TOOL_OPTIONS`. Metrics remain on Micrometer;
the agent exports traces to Alloy/Tempo.

## Optional Grafana Cloud

`alloy/config.cloud.alloy` reads endpoints and the access token from
`GRAFANA_CLOUD_*` environment variables. `terraform/environments/grafana-cloud`
provisions the folder, dashboards, contact point, alert rules and synthetic
checks. No token is committed. The self-hosted stack does not depend on it.

See [Observability](../docs/operations/observability.md).

# Observability stack

Configuration-as-code for metrics, logs, traces, profiles, container metrics,
synthetic checks and alerts. The same files run on Docker Compose, LocalStack EKS
and AWS EKS.

This repository is checked out as the `observability` submodule of
[`Microsserv52/platform`](https://github.com/Microsserv52/platform). The platform
scripts, Compose files and Kubernetes overlays reference it at that path.

## Quick start

From the platform checkout:

```bash
scripts/observability-up.sh
scripts/validate-observability.sh
```

The wrapper downloads the pinned OpenTelemetry Java agent, starts Prometheus,
Mimir, Loki, Tempo, Pyroscope, Graphite, Telegraf, Alloy, blackbox and Grafana,
and waits for each readiness endpoint.

| UI | URL |
| --- | --- |
| Grafana | <http://localhost:3000> |
| Prometheus | <http://localhost:9090> |
| Mimir | <http://localhost:9009> |
| Loki | <http://localhost:3100> |
| Tempo | <http://localhost:3200> |
| Pyroscope | <http://localhost:4040> |
| Graphite | <http://localhost:8082> |
| Alloy | <http://localhost:12345> |
| Faro ingest | <http://localhost:8080/faro/collect> (nginx to Alloy) |

## Layout

```text
observability/
  alloy/config.alloy          # local logs, OTLP and Faro
  alloy/config.k8s.alloy      # EKS pod logs, OTLP and Faro
  alloy/config.cloud.alloy    # optional Grafana Cloud remote write
  blackbox/blackbox.yml       # synthetic HTTP modules
  grafana/dashboards/         # eight provisioned dashboards
  grafana/provisioning/       # datasources, dashboards, alerting
  helm/values.yaml            # kube-prometheus-stack, AWS
  helm/values.localstack.yaml # local-path storage and toleration
  loki/loki.yaml
  mimir/mimir.yaml
  otel/run-java.sh            # optional Java agent entrypoint
  prometheus/prometheus.yml
  prometheus/rules/sli.yml
  pyroscope/pyroscope.yaml
  telegraf/telegraf.conf      # local Docker container metrics
  telegraf/telegraf-k8s.conf  # EKS kubelet pod metrics
  tempo/tempo.yaml
```

## Dashboards

Grafana provisions eight dashboards in the **Platform** folder:

- Platform overview
- Service RED
- SLO and error budget
- Synthetic health
- Dependencies
- Pod resources (Graphite)
- Frontend and Faro
- Trace service graph

Tempo service-graph and span-metric processors remote-write to Prometheus, which
feeds the cross-service trace dashboard. Telegraf writes container and pod
resource metrics to Graphite.

## AWS, staging and LocalStack

```bash
# AWS EKS, after the prerequisites in the platform Grafana-on-AWS guide
scripts/install-observability.sh

# Staging EKS
scripts/install-observability.sh --staging

# LocalStack EKS rehearsal
scripts/install-observability.sh --localstack
```

The installer applies `k8s/observability`, `k8s/overlays/staging/observability`
or `k8s/overlays/localstack/observability` from the platform repository. It
installs Prometheus, Mimir, Loki, Tempo, Pyroscope, Graphite, Telegraf, Alloy,
blackbox and Grafana. Prometheus remote-writes to Mimir; Alloy handles OTLP
traces, Faro and pod logs. Grafana stays ClusterIP.

## OpenTelemetry

`scripts/fetch-otel-agent.sh` downloads the Java agent and verifies the release
checksum. Compose mounts it through `observability/otel/run-java.sh`; Kubernetes
uses an init container and `JAVA_TOOL_OPTIONS`. Metrics remain on Micrometer;
the agent exports traces to Alloy/Tempo.

## Optional Grafana Cloud

`alloy/config.cloud.alloy` reads endpoints and the access token from
`GRAFANA_CLOUD_*` environment variables. The platform Terraform environment
`grafana-cloud` provisions the folder, dashboards, contact point, alert rules
and synthetic checks. No token is committed. The self-hosted stack does not
depend on it.

## Documentation

- [Observability](https://github.com/Microsserv52/platform/blob/main/docs/operations/observability.md)
- [Grafana on AWS](https://github.com/Microsserv52/platform/blob/main/docs/operations/grafana-aws.md)
- [Staging](https://github.com/Microsserv52/platform/blob/main/docs/infrastructure/staging.md)
- [AWS observability assessment](https://github.com/Microsserv52/platform/blob/main/docs/infrastructure/aws-observability-assessment.md)

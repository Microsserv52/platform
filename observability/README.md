# Observability stack

Configuration-as-code for metrics, logs, traces, profiles, synthetic checks and
alerts. The same files run on Docker Compose, LocalStack EKS and AWS EKS.

## Quick start

```bash
docker compose -f compose.yml -f compose.observability.yml \
  --profile observability up -d
```

Or:

```bash
scripts/observability-up.sh
scripts/validate-observability.sh
```

| UI | URL |
| --- | --- |
| Grafana | <http://localhost:3000> |
| Prometheus | <http://localhost:9090> |
| Loki | <http://localhost:3100> |
| Tempo | <http://localhost:3200> |
| Pyroscope | <http://localhost:4040> |
| Alloy | <http://localhost:12345> |

## Layout

```text
observability/
  alloy/config.alloy          # local logs, OTLP and Faro
  alloy/config.cloud.alloy    # Grafana Cloud remote write
  blackbox/blackbox.yml       # synthetic HTTP modules
  grafana/dashboards/         # five provisioned dashboards
  grafana/aws/                # Prometheus-only datasource for EKS
  grafana/provisioning/       # local datasources, dashboards, alerting
  helm/values.yaml            # kube-prometheus-stack, AWS
  helm/values.localstack.yaml # emptyDir and control-plane toleration
  loki/loki.yaml
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

Grafana stays ClusterIP. Publishing it behind Cognito or Cloudflare Access is
documented in [Grafana on AWS](../docs/operations/grafana-aws.md).

## Grafana Cloud

`alloy/config.cloud.alloy` reads endpoints and the access token from
`GRAFANA_CLOUD_*` environment variables. `terraform/environments/grafana-cloud`
provisions the folder, dashboards, contact point, alert rules and synthetic
checks. No token is committed.

See [Observability](../docs/operations/observability.md).

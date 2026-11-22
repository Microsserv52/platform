#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

require_cmd kubectl
require_cmd helm

LOCALSTACK=false
STAGING=false
for arg in "$@"; do
  case "$arg" in
    --localstack) LOCALSTACK=true ;;
    --staging) STAGING=true ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION
CLUSTER_NAME="${EKS_CLUSTER_NAME:-${TF_VAR_cluster_name:-}}"
TF_ENV="$TF_AWS"
if [[ "$STAGING" == "true" ]]; then
  CLUSTER_NAME="${CLUSTER_NAME:-platform-staging}"
  TF_ENV="$TF_STAGING"
fi
if [[ -z "$CLUSTER_NAME" ]] && terraform -chdir="$TF_ENV" output -raw eks_cluster_name >/dev/null 2>&1; then
  CLUSTER_NAME="$(tf_out "$TF_ENV" eks_cluster_name)"
fi
if [[ "$LOCALSTACK" == "false" && -z "$CLUSTER_NAME" ]]; then
  echo "error: set EKS_CLUSTER_NAME or initialize the AWS Terraform state" >&2
  exit 1
fi
if [[ "$LOCALSTACK" == "false" ]] && command -v aws >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
fi

ensure_namespace
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n observability get secret grafana-admin >/dev/null 2>&1; then
  if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
    cat >&2 <<'EOF'
error: the grafana-admin secret does not exist.
Create it from AWS Secrets Manager with External Secrets, or set
GRAFANA_ADMIN_PASSWORD and re-run. The password is never printed.
EOF
    exit 1
  fi
  kubectl -n observability create secret generic grafana-admin \
    --from-literal="admin-user=${GRAFANA_ADMIN_USER:-admin}" \
    --from-literal="admin-password=${GRAFANA_ADMIN_PASSWORD}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

if ! kubectl -n observability get secret grafana-alerting >/dev/null 2>&1; then
  kubectl -n observability create secret generic grafana-alerting \
    --from-literal="email-to=${ALERT_EMAIL_TO:-ops@example.invalid}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "creating Grafana ConfigMaps"
DATASOURCE_FILE="$ROOT_DIR/observability/grafana/provisioning/datasources/datasources.yml"
kubectl -n observability create configmap grafana-datasources \
  --from-file=datasources.yml="$DATASOURCE_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap grafana-dashboard-provider \
  --from-file=dashboards.yml="$ROOT_DIR/observability/grafana/provisioning/dashboards/dashboards.yml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap grafana-alerting \
  --from-file=contact-points.yml="$ROOT_DIR/observability/grafana/provisioning/alerting/contact-points.yml" \
  --from-file=rules.yml="$ROOT_DIR/observability/grafana/provisioning/alerting/rules.yml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap grafana-dashboards \
  --from-file="$ROOT_DIR/observability/grafana/dashboards" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap blackbox-config \
  --from-file=config.yml="$ROOT_DIR/observability/blackbox/blackbox.yml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap mimir-config \
  --from-file=config.yml="$ROOT_DIR/observability/mimir/mimir.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap loki-config \
  --from-file=config.yml="$ROOT_DIR/observability/loki/loki.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap tempo-config \
  --from-file=config.yml="$ROOT_DIR/observability/tempo/tempo.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap pyroscope-config \
  --from-file=config.yml="$ROOT_DIR/observability/pyroscope/pyroscope.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap alloy-config \
  --from-file=config.alloy="$ROOT_DIR/observability/alloy/config.k8s.alloy" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n observability create configmap telegraf-config \
  --from-file=telegraf.conf="$ROOT_DIR/observability/telegraf/telegraf-k8s.conf" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "creating PrometheusRule from the recording rules"
python3 - "$ROOT_DIR/observability/prometheus/rules/sli.yml" <<'PY' | kubectl apply -f -
import sys, yaml
with open(sys.argv[1]) as handle:
    rules = yaml.safe_load(handle)
print(yaml.safe_dump({
    "apiVersion": "monitoring.coreos.com/v1",
    "kind": "PrometheusRule",
    "metadata": {
        "name": "platform-sli",
        "namespace": "observability",
        "labels": {"app.kubernetes.io/part-of": "platform-observability"},
    },
    "spec": {"groups": rules["groups"]},
}, sort_keys=False))
PY

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null

HELM_VALUES=(-f "$ROOT_DIR/observability/helm/values.yaml")
KUSTOMIZE_PATH="$ROOT_DIR/k8s/observability"
if [[ "$LOCALSTACK" == "true" ]]; then
  HELM_VALUES+=(-f "$ROOT_DIR/observability/helm/values.localstack.yaml")
  KUSTOMIZE_PATH="$ROOT_DIR/k8s/overlays/localstack/observability"
fi
if [[ "$STAGING" == "true" ]]; then
  KUSTOMIZE_PATH="$ROOT_DIR/k8s/overlays/staging/observability"
fi

helm upgrade --install observability prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  "${HELM_VALUES[@]}" \
  --wait --timeout 10m

kubectl apply -k "$KUSTOMIZE_PATH"

for deployment in graphite mimir loki tempo pyroscope alloy grafana blackbox-exporter; do
  kubectl -n observability rollout status "deployment/$deployment" --timeout=300s
done

cat <<'EOF'
Observability is deployed.

  kubectl -n observability port-forward svc/grafana 3000:3000
  open http://localhost:3000

Grafana is ClusterIP only. To publish it behind an AWS account, apply
k8s/observability/grafana-ingress-cognito.example.yaml after setting the real
domain, ACM certificate and Cognito values. Without a domain, use kubectl port-forward.
EOF

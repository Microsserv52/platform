#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env_file

: "${EKS_CLUSTER_NAME:?EKS_CLUSTER_NAME is required}"
: "${CLUSTER_AUTOSCALER_ROLE_ARN:?CLUSTER_AUTOSCALER_ROLE_ARN is required}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION

require_cmd helm
require_cmd kubectl

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/metrics-server-values.yaml" <<'EOF'
args:
  - --kubelet-insecure-tls
EOF

echo "installing metrics-server"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update >/dev/null
helm repo add autoscaler https://kubernetes.github.io/autoscaler --force-update >/dev/null
helm repo update >/dev/null

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --values "$tmpdir/metrics-server-values.yaml" \
  --wait --timeout 5m

kubectl -n kube-system create serviceaccount cluster-autoscaler \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system annotate serviceaccount cluster-autoscaler \
  "eks.amazonaws.com/role-arn=$CLUSTER_AUTOSCALER_ROLE_ARN" --overwrite

echo "installing cluster-autoscaler"
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set cloudProvider=aws \
  --set awsRegion="$AWS_REGION" \
  --set autoDiscovery.clusterName="$EKS_CLUSTER_NAME" \
  --set rbac.create=true \
  --set rbac.serviceAccount.create=false \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.expander=least-waste \
  --wait --timeout 5m

echo "metrics-server and cluster-autoscaler installed"

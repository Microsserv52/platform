#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd aws
require_cmd jq

AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION

read_secret() {
  local prompt="$1" value
  printf "%s" "$prompt" >&2
  IFS= read -rs value
  printf "\n" >&2
  printf "%s" "$value"
}

GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
  GRAFANA_ADMIN_PASSWORD="$(read_secret 'Grafana admin password: ')"
fi
if [[ -z "${ALERT_EMAIL_TO:-}" ]]; then
  ALERT_EMAIL_TO="$(read_secret 'Alert recipient email: ')"
fi

admin_json="$(jq -nc --arg u "$GRAFANA_ADMIN_USER" --arg p "$GRAFANA_ADMIN_PASSWORD" '{username:$u,password:$p}')"
alert_json="$(jq -nc --arg e "$ALERT_EMAIL_TO" '{email_to:$e}')"

aws secretsmanager put-secret-value \
  --secret-id platform/grafana/admin \
  --secret-string "$admin_json" >/dev/null

aws secretsmanager put-secret-value \
  --secret-id platform/grafana/alerting \
  --secret-string "$alert_json" >/dev/null

echo "Grafana secrets written to AWS Secrets Manager"
